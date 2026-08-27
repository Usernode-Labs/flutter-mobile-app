import 'dart:async';
import 'dart:io' show Platform;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_binding.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';

/// Marionette MCP mode initializes MarionetteBinding for runtime inspection
/// and screenshots by an external AI agent. It must bypass Sentry because
/// Flutter allows only one WidgetsBinding per process.
const bool _marionetteEnabled = bool.fromEnvironment('MARIONETTE');

Future<void> main(List<String> args) async {
  // Desktop WebView windows host their toolbar in a small secondary Flutter
  // engine. Handle that entrypoint before initializing the full application.
  if (runWebViewTitleBarWidget(args)) return;

  if (_marionetteEnabled && kDebugMode) {
    MarionetteBinding.ensureInitialized();
    await _runAppBody(logTag: 'usernode/MarionetteBootstrap');
    return;
  }

  // NOTE: Do NOT call WidgetsFlutterBinding.ensureInitialized() here.
  // SentryFlutter.init() will initialize SentryWidgetsFlutterBinding which
  // is required for FramesTrackingIntegration to work properly.
  await SentryUtil.bootstrap(
    () => _runAppBody(logTag: 'usernode/Bootstrap'),
  );
}

Future<void> _runAppBody({required String logTag}) async {
  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Start terminated-app tap capture before the sole ProviderContainer and
  // WebView runtime are constructed. The durable pending-tap state is
  // replayed when the trusted page is ready, so native Firebase calls must not
  // delay the first frame.
  unawaited(
    SocialPushService.instance.initialize().catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint(
          '[SocialPush] Initialization failed: $error\n$stackTrace',
        );
      },
    ),
  );
  AppResetService.instance.registerLocalResetHandler(
    SocialPushService.instance.closeForTerminalReset,
  );

  final boot = await AppBootstrap.initNonUi(logTag: logTag);
  final log = boot.log;

  log.info('App started');
  log.info(
    'Version check: enabled=${AppConfig.versionCheckEnabled}, host=${AppConfig.versionCheckHost}, intervalSec=${AppConfig.versionCheckIntervalSeconds}',
  );

  // Render UI immediately; perform heavy bootstrap asynchronously.
  log.info('Running app UI');
  runApp(AppRuntimeRoot(
    initialContainer: boot.container,
  ));
}

/// Headless entrypoint for background Flutter engine
/// This is used when the app runs without UI (e.g., background services)
///
/// This function is called from native code via DartExecutor.DartEntrypoint
/// with entrypoint name "headlessMain"
@pragma('vm:entry-point')
Future<void> headlessMain() async {
  // Initialize Flutter binding manually (no Sentry in headless mode)
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppSleepStateStore.load();
    final alarmServiceReady = await PlatformAlarmService.instance.initialize();
    if (!alarmServiceReady) return;
    final nativeWakelockHeld =
        await PlatformAlarmService.instance.isWakelockHeld();
    final watchdogDeliveryInProgress =
        await PlatformAlarmService.instance.isAlarmWatchdogDeliveryInProgress();
    if (AppSleepStateStore.isSleeping &&
        !nativeWakelockHeld &&
        !watchdogDeliveryInProgress) {
      await LoggingService.initialize();
      final log = LoggingService.instance.withTag('usernode/HeadlessBootstrap');
      log.info('Skipping headless bootstrap while app sleep is active');
      return;
    }

    final boot = await AppBootstrap.initNonUi(
      logTag: 'usernode/HeadlessBootstrap',
      registerLifecycleObserver: false,
    );
    final log = boot.log;
    final container = boot.container;
    await boot.backendBootstrap;

    log.debug('hasAnyAccounts: ${boot.hasAnyAccounts}');

    log.debug('Starting headless bootstrap');

    try {
      // Start headless services
      log.debug('Starting headless services...');
      await _startHeadlessServices(container, log);
      log.debug('Headless services started');
    } catch (e, st) {
      log.error(
        'Error during headless bootstrap: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  } catch (e, st) {
    // Try to initialize logging if it's not already initialized
    try {
      await LoggingService.initialize();
      final log = LoggingService.instance.withTag('usernode/HeadlessBootstrap');
      log.error('Fatal error in headless main()', error: e, stackTrace: st);
    } catch (_) {
      // If logging fails, at least we have the print statements
    }

    // Re-throw to let Flutter handle it
    rethrow;
  }
}

/// Start services that are normally started by providers in headless mode
Future<void> _startHeadlessServices(
  ProviderContainer container,
  TaggedLogger log,
) async {
  try {
    log.info('Starting headless services (lifecycle, etc.)');

    // Initialize backend lifecycle provider manually
    container.read(backendLifecycleProvider);

    log.info('Headless services started successfully');
  } catch (e, st) {
    log.error('Error starting headless services: $e', error: e, stackTrace: st);
    await SentryUtil.captureError(e, st, tag: 'headless_services');
  }
}

class AppRuntimeRoot extends StatefulWidget {
  const AppRuntimeRoot({
    super.key,
    required this.initialContainer,
    this.resetService,
    this.child = const CryptoMobileApp(),
  });

  final ProviderContainer initialContainer;
  final AppResetService? resetService;
  final Widget child;

  @override
  State<AppRuntimeRoot> createState() => _AppRuntimeRootState();
}

class _AppRuntimeRootState extends State<AppRuntimeRoot> {
  ProviderContainer? _container;
  bool _terminalReset = false;
  String _terminalResetReason = 'unknown';

  @override
  void initState() {
    super.initState();
    _container = widget.initialContainer;
    (widget.resetService ?? AppResetService.instance)
        .registerTerminalResetHandler(_enterTerminalReset);
  }

  @override
  void dispose() {
    (widget.resetService ?? AppResetService.instance)
        .unregisterTerminalResetHandler();
    _container?.dispose();
    super.dispose();
  }

  void _enterTerminalReset(String reason) {
    if (_terminalReset) return;
    final oldContainer = _container;
    if (!mounted) {
      oldContainer?.dispose();
      _container = null;
      _terminalReset = true;
      _terminalResetReason = reason;
      return;
    }
    setState(() {
      _container = null;
      _terminalReset = true;
      _terminalResetReason = reason;
    });
    oldContainer?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_terminalReset) return _TerminalResetApp(reason: _terminalResetReason);
    final container = _container!;
    return UncontrolledProviderScope(
      container: container,
      child: widget.child,
    );
  }
}

class _TerminalResetApp extends StatelessWidget {
  const _TerminalResetApp({required this.reason});

  /// The [AppResetService] reset reason. Unrecognized values fall back to the
  /// generic reset wording.
  final String reason;

  (String, String) _wording(AppLocalizations l10n) => switch (reason) {
        'logout' => (l10n.appResetLogoutTitle, l10n.appResetLogoutBody),
        'session_expired' => (
            l10n.appResetSessionExpiredTitle,
            l10n.appResetSessionExpiredBody,
          ),
        'session_credential_missing' => (
            l10n.appResetCredentialMissingTitle,
            l10n.appResetCredentialMissingBody,
          ),
        'different_participant_login' => (
            l10n.appResetAccountChangedTitle,
            l10n.appResetAccountChangedBody,
          ),
        'authenticated_to_guest' => (
            l10n.appResetGuestTitle,
            l10n.appResetGuestBody,
          ),
        'network_change' => (
            l10n.appResetNetworkChangeTitle,
            l10n.appResetNetworkChangeBody,
          ),
        _ => (l10n.appResetCompleteTitle, l10n.appResetCompleteBody),
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CryptoMobileApp._lightTheme,
      darkTheme: CryptoMobileApp._darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        final spacing = Theme.of(context).extension<AppSpacing>()!;
        final textTheme = Theme.of(context).textTheme;
        final l10n = AppLocalizations.of(context);
        final (title, body) = _wording(l10n);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing.space12,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      body,
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key});

  static final _lightTheme =
      ColorIsExpensiveTheme(ThemeData.light().textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          );

  static final _darkTheme =
      ColorIsExpensiveTheme(ThemeData.dark().textTheme).dark().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.dark(),
            ),
          );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize backend lifecycle manager
    ref.watch(backendLifecycleProvider);

    // Initialize zkPassport pipeline state early so session-server polling
    // and foreground recovery are active before the registration UI opens.
    ref.watch(zkPassportPipelineProvider);

    // Keep the identity driver alive for the whole app lifetime: it runs
    // the account reconcile whenever the identity enters the reconciling
    // phase and retries pending zk completions once it settles.
    ref.watch(identityDriverProvider);

    // Hand the authoritative active season to the SessionController — a
    // rollover re-enters the reconciling phase (per-season wallets), and no
    // sign-in transition fires for users who stay signed in across it.
    ref.watch(seasonRolloverSyncProvider);

    // Feed the process-lifetime push service only the current ready identity
    // and exact bearer. Disposing the app graph detaches this adapter; the
    // terminal reset fence separately closes the process-lifetime service.
    ref.watch(socialPushBindingProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false, // Flip to true to verify 8pt grid alignment
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _AppWrapper(child: child),
    );
  }
}

/// Wrapper that handles version check and hot reload invalidation
class _AppWrapper extends ConsumerStatefulWidget {
  const _AppWrapper({required this.child});
  final Widget? child;

  @override
  ConsumerState<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<_AppWrapper>
    with WidgetsBindingObserver {
  bool _versionCheckShown = false;
  bool _wasSleeping = false;
  final _appSleepService = AppSleepService.instance;
  StreamSubscription<void>? _socialPushTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasSleeping = _appSleepService.isSleeping;
    _appSleepService.addListener(_handleAppSleepChanged);
    _socialPushTapSubscription =
        SocialPushService.instance.tapEvents.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPendingSocialNotification();
      });
    });
    _syncVersionChecks();
    // Check version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialVersion();
      _openPendingSocialNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SocialPushService.instance.reconcileBestEffort();
      _openPendingSocialNotification();
      unawaited(
        ref.read(identityDriverProvider).refreshNow(),
      );
      // Don't reset _versionCheckShown — the guard in _checkInitialVersion
      // prevents stacking a second dialog on top of an already-shown one.
      ref.invalidate(appVersionCheckProvider);
      _checkInitialVersion();
    }
  }

  Future<void> _checkInitialVersion() async {
    final log = LoggingService.instance.withTag('usernode/VersionCheck');
    log.info('_checkInitialVersion called');
    try {
      final result = await ref.read(appVersionCheckProvider.future);
      log.info(
        'Version check result: $result, shouldShow: ${result?.shouldShowDialog}, shown: $_versionCheckShown, mounted: $mounted',
      );
      if (result != null &&
          result.shouldShowDialog &&
          !_versionCheckShown &&
          mounted) {
        _versionCheckShown = true;
        log.info('Showing update dialog...');
        showUpdateDialog(appNavigatorKey, result);
      }
    } catch (e) {
      log.error('Error in _checkInitialVersion: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appSleepService.removeListener(_handleAppSleepChanged);
    unawaited(_socialPushTapSubscription?.cancel());
    AppVersionCheck.instance.stopPeriodicChecks();
    super.dispose();
  }

  void _openPendingSocialNotification() {
    if (!mounted || !SocialPushService.instance.hasPendingTap) return;
    ref.read(appRouterProvider).go(AppRoutes.home);
  }

  void _handleVersionCheckResult(VersionCheckResult result) {
    if (!mounted || _versionCheckShown) return;
    _versionCheckShown = true;
    showUpdateDialog(appNavigatorKey, result);
  }

  void _handleAppSleepChanged() {
    final isSleeping = _appSleepService.isSleeping;
    _syncVersionChecks();
    if (_wasSleeping && !isSleeping) {
      // Sleep only pauses the node; the UI never went away, so there is no
      // post-wake navigation reset — just refresh the node-backed data.
      unawaited(_refreshWakeData());
    }
    _wasSleeping = isSleeping;
  }

  Future<void> _refreshWakeData() async {
    final log = LoggingService.instance.withTag('usernode/AppWakeRefresh');

    if (Platform.isAndroid) {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline) &&
          !RustBackendService.instance.isRunning) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    Future<void> guardedRefresh(
      String label,
      Future<void> Function() refresh,
    ) async {
      try {
        await refresh();
      } catch (e) {
        log.warn('Wake refresh failed for $label: $e');
      }
    }

    await guardedRefresh(
      'node_status',
      () => ref.read(nodeStatusProvider.notifier).refresh(),
    );
  }

  void _syncVersionChecks() {
    if (_appSleepService.isSleeping) {
      AppVersionCheck.instance.stopPeriodicChecks();
      return;
    }

    AppVersionCheck.instance.startPeriodicChecks(_handleVersionCheckResult);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_down');
      },
      onPointerMove: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_move');
      },
      onPointerSignal: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_signal');
      },
      // App sleep only pauses the node — the UI stays live and interactive,
      // so no sleep overlay or ticker freeze here. The pointer listeners
      // above double as the wake gesture (see
      // AppSleepService.recordUserInteraction).
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child ?? const SizedBox.shrink(),
          const ClockDriftWarningOverlay(),
        ],
      ),
    );
  }
}
