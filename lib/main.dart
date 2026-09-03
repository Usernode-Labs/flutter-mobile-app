import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_api.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';
import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/dapps/sv_shell_screen.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/providers/perf_benchmark_provider.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_result_detail_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_run_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/diagnostics_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/http_debug_logs_screen.dart';
import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/staking_delegation_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_flow_screen.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/src/rust/mobile_api.dart' as native;
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';

part 'src/session_lifecycle/session_operation_kernel.dart';
part 'src/session_lifecycle/native_session_transport.dart';
part 'src/session_lifecycle/app_router_root.dart';

/// Marionette MCP mode initializes MarionetteBinding for runtime inspection
/// and screenshots by an external AI agent. It must bypass Sentry because
/// Flutter allows only one WidgetsBinding per process.
const bool _marionetteEnabled = bool.fromEnvironment('MARIONETTE');

Future<void> main() async {
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
  final boot = await AppBootstrap.initNonUi(logTag: logTag);
  final log = boot.log;
  MetricsCollectorService.instance.initialize();
  ObservabilityReportingService.instance.configureMobileContextCollector(
    MetricsCollectorService.instance,
  );

  log.info('App started');
  log.info(
    'Version check: enabled=${AppConfig.versionCheckEnabled}, host=${AppConfig.versionCheckHost}, intervalSec=${AppConfig.versionCheckIntervalSeconds}',
  );

  // The native root is the only lifecycle owner. Bootstrap completes before
  // any feature graph or trusted Social document exists, so a cold recovered
  // Ready session is the first (and only) published identity.
  await boot.rustBootstrap;
  final nativeSession = await _bootstrapNativeSessionRuntime();

  log.info('Running app UI');
  runApp(
    UncontrolledProviderScope(
      container: boot.container,
      child: _CryptoMobileApp(nativeSession: nativeSession),
    ),
  );
}

class _CryptoMobileApp extends ConsumerStatefulWidget {
  const _CryptoMobileApp({
    required _NativeSessionRuntime nativeSession,
  }) : _nativeSession = nativeSession;

  final _NativeSessionRuntime _nativeSession;

  @override
  ConsumerState<_CryptoMobileApp> createState() => _CryptoMobileAppState();
}

class _CryptoMobileAppState extends ConsumerState<_CryptoMobileApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createAppRouter(ref, widget._nativeSession);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false, // Flip to true to verify 8pt grid alignment
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _AppWrapper(
        router: _router,
        nativeSession: widget._nativeSession,
        child: child,
      ),
    );
  }
}

/// Wrapper that handles version check and hot reload invalidation
class _AppWrapper extends ConsumerStatefulWidget {
  const _AppWrapper({
    required this.child,
    required this.router,
    required _NativeSessionRuntime nativeSession,
  }) : _nativeSession = nativeSession;
  final Widget? child;
  final GoRouter router;
  final _NativeSessionRuntime _nativeSession;

  @override
  ConsumerState<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<_AppWrapper>
    with WidgetsBindingObserver {
  final Object _socialPushOwner = Object();
  bool _versionCheckShown = false;
  bool _resumeValidationPending = false;
  int _lifecycleGeneration = 0;
  StreamSubscription<void>? _socialPushTapSubscription;
  StreamSubscription<SessionFeatureAccess>? _sessionSubscription;
  String? _boundReadyRevision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionSubscription = widget._nativeSession.sessions.changes.listen(
      _bindSessionFeatures,
    );
    _socialPushTapSubscription =
        SocialPushService.instance.tapEvents.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPendingSocialNotification();
      });
    });
    AppVersionCheck.instance.startPeriodicChecks(_handleVersionCheckResult);
    // Check version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindSessionFeatures(widget._nativeSession.sessions.current);
      _checkInitialVersion();
      _openPendingSocialNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The process root changes feature admission synchronously before any
    // lifecycle consumer can enter the session runner.
    final lifecycleTransition =
        widget._nativeSession.appLifecycleStateChanged(state);
    final lifecycleGeneration = ++_lifecycleGeneration;
    MetricsCollectorService.instance.updateAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!_resumeValidationPending) {
        setState(() => _resumeValidationPending = true);
      }
      unawaited(
        _finishForegroundResume(lifecycleTransition, lifecycleGeneration),
      );
    }
    unawaited(
      ObservabilityReportingService.instance.reportLifecycleStateChanged(
        state,
      ),
    );
  }

  Future<void> _finishForegroundResume(
    Future<void> validation,
    int lifecycleGeneration,
  ) async {
    try {
      await validation;
      if (!mounted ||
          lifecycleGeneration != _lifecycleGeneration ||
          widget._nativeSession.bridge.terminallyRetired ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final access = widget._nativeSession.sessions.current;
      _bindSessionFeatures(access);
      if (access.identity.status != SessionProjectionStatus.ready) return;
      SocialPushService.instance.reconcileBestEffort();
      _openPendingSocialNotification();
      // Don't reset _versionCheckShown — the guard in _checkInitialVersion
      // prevents stacking a second dialog on top of an already-shown one.
      ref.invalidate(appVersionCheckProvider);
      _checkInitialVersion();
    } finally {
      if (mounted && lifecycleGeneration == _lifecycleGeneration) {
        setState(() => _resumeValidationPending = false);
      }
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
    unawaited(_socialPushTapSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    AppVersionCheck.instance.stopPeriodicChecks();
    super.dispose();
  }

  void _bindSessionFeatures(SessionFeatureAccess access) {
    ref.read(zkPassportPipelineProvider.notifier).bindSession(access);
    ref.invalidate(zkPassportIsRegisteredProvider);
    ref.invalidate(zkPassportRegistrationProvider);
    ref.read(perfBenchmarkProvider.notifier).bindSession(access);
    ObservabilityReportingService.instance.configureSession(access);
    if (access.identity.status == SessionProjectionStatus.ready) {
      unawaited(
        SentryUtil.setUser(
          id: access.identity.accountId ??
              access.identity.participantId?.toString(),
        ),
      );
      if (_boundReadyRevision != access.identity.nativeRevision) {
        _boundReadyRevision = access.identity.nativeRevision;
        unawaited(
          ObservabilityReportingService.instance.reportNodeInitialized(
            resetStaticContext: true,
          ),
        );
      }
      SocialPushService.instance.attachSession(
        _socialPushOwner,
        SocialPushSession(access: access),
      );
    } else {
      _boundReadyRevision = null;
      unawaited(SentryUtil.clearUser());
      unawaited(
        ObservabilityReportingService.instance
            .stopMobileContextSnapshotReporting(),
      );
      SocialPushService.instance.detachSession(
        _socialPushOwner,
        rotateProviderToken: true,
        ifAlreadyUnbound: true,
        unregisterReason: SocialPushUnregisterReason.signedOut,
      );
    }
  }

  void _openPendingSocialNotification() {
    if (!mounted || !SocialPushService.instance.hasPendingTap) return;
    widget.router.go(AppRoutes.home);
  }

  void _handleVersionCheckResult(VersionCheckResult result) {
    if (!mounted || _versionCheckShown) return;
    _versionCheckShown = true;
    showUpdateDialog(appNavigatorKey, result);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    final content = Stack(
      fit: StackFit.expand,
      children: [
        child,
        ClockDriftWarningOverlay(
          sessionAccess: widget._nativeSession.sessions,
        ),
      ],
    );
    if (!_resumeValidationPending) return content;
    // Block resumed UI dispatch until the private native snapshot/wake has
    // either kept Ready or retired it to the inert signed-out projection.
    return Stack(
      children: [
        AbsorbPointer(child: content),
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.transparent),
        ),
      ],
    );
  }
}
