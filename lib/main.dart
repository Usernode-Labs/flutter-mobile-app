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
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';
import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/dapps/sv_shell_screen.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_screen.dart';
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

  // The native root is the only lifecycle owner. The future completes before
  // any feature graph or trusted Social document is constructed, while a
  // Flutter-owned loading surface can render independently of slow native
  // recovery and producer-policy work.
  final nativeSessionFuture = () async {
    await boot.rustBootstrap;
    return _bootstrapNativeSessionRuntime();
  }();

  log.info('Running app bootstrap UI');
  runApp(
    UncontrolledProviderScope(
      container: boot.container,
      child: _NativeSessionBootstrapApp(nativeSessionFuture),
    ),
  );
}

class _NativeSessionBootstrapApp extends ConsumerStatefulWidget {
  const _NativeSessionBootstrapApp(this.nativeSessionFuture);

  final Future<_NativeSessionRuntime> nativeSessionFuture;

  @override
  ConsumerState<_NativeSessionBootstrapApp> createState() =>
      _NativeSessionBootstrapAppState();
}

class _NativeSessionBootstrapAppState
    extends ConsumerState<_NativeSessionBootstrapApp> {
  _NativeSessionRuntime? _nativeSession;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    widget.nativeSessionFuture.then(
      _publishNativeSession,
      onError: _publishFailure,
    );
  }

  void _publishNativeSession(_NativeSessionRuntime nativeSession) {
    if (!mounted) return;
    setState(() => _nativeSession = nativeSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_nativeSession, nativeSession)) return;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState == null) return;
      unawaited(
        nativeSession.appLifecycleStateChanged(lifecycleState).onError(
          (error, stackTrace) {
            LoggingService.instance.error(
              'Initial lifecycle reconciliation failed',
              tag: 'usernode/Bootstrap',
              error: error,
              stackTrace: stackTrace,
            );
          },
        ),
      );
    });
  }

  void _publishFailure(Object error, StackTrace stackTrace) {
    LoggingService.instance.error(
      'Native session startup failed',
      tag: 'usernode/Bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
    if (mounted) setState(() => _failure = error);
  }

  @override
  Widget build(BuildContext context) {
    final nativeSession = _nativeSession;
    if (nativeSession != null) {
      return _CryptoMobileApp(nativeSession: nativeSession);
    }

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      theme: _CryptoMobileAppState.lightTheme,
      darkTheme: _CryptoMobileAppState.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _failure == null
          ? const SplashScreen()
          : const _NativeSessionStartupFailureScreen(),
    );
  }
}

class _NativeSessionStartupFailureScreen extends StatelessWidget {
  const _NativeSessionStartupFailureScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'The node could not be initialized. Close and reopen the app to retry.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
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

  static final lightTheme =
      ColorIsExpensiveTheme(ThemeData.light().textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          );

  static final darkTheme =
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
      theme: lightTheme,
      darkTheme: darkTheme,
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
  int _lifecycleGeneration = 0;
  StreamSubscription<void>? _socialPushTapSubscription;
  StreamSubscription<SessionFeatureAccess>? _sessionSubscription;
  String? _boundReadyRevision;
  _NodePermissionGateBinding? _nodePermissionGate;
  int _nodePermissionGateGeneration = 0;

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
    await validation;
    if (!mounted ||
        lifecycleGeneration != _lifecycleGeneration ||
        widget._nativeSession.bridge.terminallyRetired ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final access = widget._nativeSession.sessions.current;
    _bindSessionFeatures(access, forcePermissionGateCheck: true);
    if (access.identity.status != SessionProjectionStatus.ready) return;
    SocialPushService.instance.reconcileBestEffort();
    _openPendingSocialNotification();
    // Don't reset _versionCheckShown — the guard in _checkInitialVersion
    // prevents stacking a second dialog on top of an already-shown one.
    ref.invalidate(appVersionCheckProvider);
    _checkInitialVersion();
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

  void _bindSessionFeatures(
    SessionFeatureAccess access, {
    bool forcePermissionGateCheck = false,
  }) {
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
      _scheduleNodePermissionGateCheck(
        access,
        force: forcePermissionGateCheck,
      );
    } else {
      _boundReadyRevision = null;
      _clearNodePermissionGate();
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

  void _scheduleNodePermissionGateCheck(
    SessionFeatureAccess access, {
    bool force = false,
  }) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _clearNodePermissionGate();
      return;
    }
    if (!force &&
        _nodePermissionGate?.nativeRevision == access.identity.nativeRevision) {
      return;
    }
    final generation = ++_nodePermissionGateGeneration;
    unawaited(_reconcileNodePermissionGate(access, generation));
  }

  Future<void> _reconcileNodePermissionGate(
    SessionFeatureAccess access,
    int generation,
  ) async {
    NodePermissionGateState state;
    try {
      state = await readNodePermissionGateState(access);
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Could not evaluate the permission gate',
        tag: 'usernode/PermissionGate',
        error: error,
        stackTrace: stackTrace,
      );
      state = NodePermissionGateState.conservative(
        hasWallet: access.identity.hasWallet,
      );
    }
    if (!mounted ||
        generation != _nodePermissionGateGeneration ||
        widget._nativeSession.sessions.current.identity.nativeRevision !=
            access.identity.nativeRevision ||
        widget._nativeSession.sessions.current.identity.status !=
            SessionProjectionStatus.ready) {
      return;
    }

    LoggingService.instance.info(
      'Permission gate evaluated '
      '(required=${!state.isSatisfied}, '
      'notifications=${state.notificationsGranted}, '
      'delegated=${state.delegated}, '
      'exactAlarms=${state.exactAlarmsGranted}, '
      'unrestrictedBackground=${state.unrestrictedBackgroundGranted})',
      tag: 'usernode/PermissionGate',
    );
    setState(() {
      _nodePermissionGate = state.isSatisfied
          ? null
          : _NodePermissionGateBinding(
              nativeRevision: access.identity.nativeRevision,
              session: access,
              initialState: state,
            );
    });
  }

  void _clearNodePermissionGate() {
    ++_nodePermissionGateGeneration;
    if (_nodePermissionGate == null || !mounted) return;
    setState(() => _nodePermissionGate = null);
  }

  void _completeNodePermissionGate(String nativeRevision) {
    if (_nodePermissionGate?.nativeRevision != nativeRevision) return;
    ++_nodePermissionGateGeneration;
    LoggingService.instance.info(
      'Permission gate requirements satisfied',
      tag: 'usernode/PermissionGate',
    );
    setState(() => _nodePermissionGate = null);
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
        if (_nodePermissionGate case final gate?)
          NodePermissionsGateScreen(
            key: ValueKey('node-permissions-${gate.nativeRevision}'),
            session: gate.session,
            initialState: gate.initialState,
            onSatisfied: () => _completeNodePermissionGate(gate.nativeRevision),
          ),
      ],
    );
    // Session operations remain admission-gated during foreground validation;
    // navigation and the WebView must remain responsive while a producer
    // policy request is in flight.
    return content;
  }
}

final class _NodePermissionGateBinding {
  const _NodePermissionGateBinding({
    required this.nativeRevision,
    required this.session,
    required this.initialState,
  });

  final String nativeRevision;
  final SessionFeatureAccess session;
  final NodePermissionGateState initialState;
}
