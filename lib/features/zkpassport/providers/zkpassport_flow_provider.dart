import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = LoggingService.instance.withTag('usernode/ZkPassportFlow');

String _newRequestNonce() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
  ).join();
}

typedef _AccountScope = ({
  AccountCapability capability,
  AccountMeta account,
  Identity identity,
});

Future<_AccountScope?> _captureAccountScope(
  Ref ref, {
  Identity? identity,
}) async {
  final captured = identity ?? IdentitySnapshots.current;
  if (captured.phase != IdentityPhase.ready) return null;
  final repository = await ref.read(accountsProvider.future);
  if (!captured.sameScopeAs(IdentitySnapshots.current)) return null;
  try {
    final capability = repository.capabilityFor(captured);
    final account = await repository.getAuthorizedAccount(capability);
    return account == null
        ? null
        : (
            capability: capability,
            account: account,
            identity: captured,
          );
  } on StaleAuthCredentialException {
    return null;
  }
}

class _PreparedBackendCompletion {
  const _PreparedBackendCompletion({
    required this.capability,
    required this.participantId,
    required this.challengeId,
    required this.sessionId,
    required this.nullifierHex,
    required this.requestVersion,
  });

  final AccountCapability capability;
  final int participantId;
  final int challengeId;
  final String sessionId;
  final String nullifierHex;
  final ZkPassportRequestVersion requestVersion;
  String get appSessionId => capability.sessionId;
  String get walletAddress => capability.address;
}

final zkPassportBridgeBaseUrlProvider = Provider<String?>((ref) {
  final value = AppConfig.zkPassportBridgeBaseUrl.trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
});

final zkPassportSessionServerRepositoryProvider =
    Provider<ZkPassportSessionServerRepository?>((ref) {
  final baseUrl = ref.watch(zkPassportBridgeBaseUrlProvider);
  if (baseUrl == null || baseUrl.isEmpty) {
    return null;
  }
  final repo = ZkPassportSessionServerRepository(baseUrl: baseUrl);
  ref.onDispose(repo.dispose);
  return repo;
});

final zkPassportRegistrationRepositoryProvider =
    Provider<ZkPassportRegistrationRepository>((ref) {
  return ZkPassportRegistrationRepository();
});

final zkPassportSettingsRepositoryProvider =
    Provider<ZkPassportSettingsRepository>((ref) {
  return ZkPassportSettingsRepository();
});

final zkPassportRuntimeSessionRepositoryProvider =
    Provider<ZkPassportRuntimeSessionRepository>((ref) {
  return ZkPassportRuntimeSessionRepository();
});

/// The zkPassport rows are bucket-scoped. The complete session container is
/// disposed at retirement, so none of these cached values can cross into the
/// clean successor host.
final zkPassportSettingsProvider =
    FutureProvider<ZkPassportSettings>((ref) async {
  final repo = ref.watch(zkPassportSettingsRepositoryProvider);
  final scope = await _captureAccountScope(ref);
  return scope == null
      ? ZkPassportSettings.defaults
      : await repo.load(scope.capability);
});

final zkPassportIsRegisteredProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(zkPassportRegistrationRepositoryProvider);
  final scope = await _captureAccountScope(ref);
  return scope == null ? false : await repo.isRegistered(scope.capability);
});

final zkPassportRegistrationProvider =
    FutureProvider<ZkPassportLocalRegistration>((ref) async {
  final repo = ref.watch(zkPassportRegistrationRepositoryProvider);
  final scope = await _captureAccountScope(ref);
  return scope == null
      ? ZkPassportLocalRegistration.unregistered()
      : await repo.getActiveRegistration(scope.capability);
});

final zkPassportLaunchServiceProvider =
    Provider<ZkPassportLaunchService>((ref) {
  return ZkPassportLaunchService();
});

final zkPassportFlowControllerProvider =
    Provider<ZkPassportFlowController>((ref) {
  return ZkPassportFlowController(ref);
});

final zkPassportPipelineProvider = StateNotifierProvider<
    ZkPassportPipelineController, ZkPassportPipelineState>((ref) {
  return ZkPassportPipelineController(ref);
});

class ZkPassportLaunchResult {
  const ZkPassportLaunchResult({
    required this.started,
    required this.requestId,
    required this.message,
  });

  final bool started;
  final String? requestId;
  final String message;
}

class ZkPassportFlowController {
  ZkPassportFlowController(this._ref);

  final Ref _ref;

  Future<ZkPassportLaunchResult> startRegistrationNonceZero() async {
    return _startServerOwnedRegistration();
  }

  Future<ZkPassportLaunchResult> _startServerOwnedRegistration() async {
    if (AppConfig.viewOnly) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'zkPassport session creation is disabled in view-only mode.',
      );
    }

    final pipeline = _ref.read(zkPassportPipelineProvider);
    final pipelineController = _ref.read(zkPassportPipelineProvider.notifier);
    if (pipelineController.isProofProcessing) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'A zkPassport proof is still being processed. Please wait.',
      );
    }
    final activeRequestId = pipeline.requestId?.trim();
    if (pipeline.status == ZkPassportPipelineStatus.processing &&
        activeRequestId != null &&
        activeRequestId.isNotEmpty) {
      _log.warn(
        'Discarding pending zkPassport session before fresh start',
        context: {
          'requestId': activeRequestId,
          'phase': pipeline.phase.name,
        },
      );
      final discarded = await pipelineController.discardPendingSession(
        requestId: activeRequestId,
        reason:
            'Resetting previous zkPassport session before starting a new one.',
      );
      if (!discarded) {
        return const ZkPassportLaunchResult(
          started: false,
          requestId: null,
          message: 'A zkPassport proof is still being processed. Please wait.',
        );
      }
    }

    // WHO is launching, captured before the first await. Everything below
    // reads this identity's wallet and binds a server session to its public
    // key, but the calls in between (session start, launch) are unbounded
    // network time — a sign-out plus a new login inside that window would
    // otherwise have `markLaunchStarted` stamp the SUCCESSOR's identity onto
    // A's server session, and every later scope check would then accept the
    // wrong owner.
    final launchIdentity = IdentitySnapshots.current;
    if (!launchIdentity.allowsSigning) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'No signed-in account available.',
      );
    }

    final accountScope = await _captureAccountScope(
      _ref,
      identity: launchIdentity,
    );
    final active = accountScope?.account;
    if (active == null) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'No active account available.',
      );
    }
    final userPublicKey = active.publicKey;

    const chainId = ZkPassportRequestPolicy.boundChainId;
    final settingsRepo = _ref.read(zkPassportSettingsRepositoryProvider);
    final settings = await settingsRepo.load(accountScope!.capability);
    final facematchStrict = settings.facematchStrict;

    final sessionServerRepo =
        _ref.read(zkPassportSessionServerRepositoryProvider);
    if (sessionServerRepo == null) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'Session server is not configured.',
      );
    }

    final previousRequestId = activeRequestId;
    late final String requestId;
    late final Uri launchUri;
    try {
      var started = await sessionServerRepo.startSession(
        walletAddress: active.address,
        chainId: chainId,
        nonce: 0,
        facematchStrict: facematchStrict,
        userPublicKey: userPublicKey,
      );
      final nextRequestId = started.sessionId.trim();
      if (previousRequestId != null &&
          previousRequestId.isNotEmpty &&
          nextRequestId == previousRequestId) {
        _log.warn(
          'Session server returned same request id as previous run; forcing new session id',
          context: {
            'requestId': nextRequestId,
          },
        );
        started = await sessionServerRepo.startSession(
          walletAddress: active.address,
          chainId: chainId,
          nonce: 0,
          facematchStrict: facematchStrict,
          userPublicKey: userPublicKey,
        );
      }
      final normalizedRequestId = started.sessionId.trim();
      if (previousRequestId != null &&
          previousRequestId.isNotEmpty &&
          normalizedRequestId == previousRequestId) {
        throw StateError('session_server_reused_request_id');
      }
      requestId = normalizedRequestId;
      launchUri = Uri.parse(started.launchUrl);
    } catch (e, st) {
      _log.error(
        'Failed to start server-owned zkPassport session',
        error: e,
        stackTrace: st,
      );
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'Unable to start zkPassport session on server.',
      );
    }

    await pipelineController.markLaunchStarted(
      requestId: requestId,
      facematchStrict: facematchStrict,
      userPublicKey: userPublicKey,
      launchIdentity: launchIdentity,
      launchCapability: accountScope.capability,
    );

    final launchService = _ref.read(zkPassportLaunchServiceProvider);
    final launched = await launchService.launchOrOpenStore(launchUri);
    if (!launched) {
      await pipelineController.markLaunchFailed(
        requestId: requestId,
        message: 'Unable to open zkPassport or app store listing.',
      );
      return ZkPassportLaunchResult(
        started: false,
        requestId: requestId,
        message: 'Unable to open zkPassport or app store listing.',
      );
    }

    await pipelineController.markLaunchDispatched(
      requestId: requestId,
    );
    pipelineController.startServerResultPolling(
      requestId: requestId,
      immediate: true,
    );

    return ZkPassportLaunchResult(
      started: true,
      requestId: requestId,
      message: 'zkPassport launch requested.',
    );
  }

  Future<void> storeSuccessfulRegistrationForAccount({
    required AccountCapability capability,
    required String? nullifierHex,
    required ZkPassportRequestVersion requestVersion,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeRegistrationForAccount(
      capability: capability,
      registered: true,
      nullifierHex: nullifierHex,
      facematchVerified: facematchVerified,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      requestVersion: requestVersion,
    );
    _ref.invalidate(zkPassportIsRegisteredProvider);
    _ref.invalidate(zkPassportRegistrationProvider);
  }

  Future<void> clearActiveRegistration() async {
    final scope = await _captureAccountScope(_ref);
    if (scope == null) return;
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.clearActiveRegistration(scope.capability);
    _ref.invalidate(zkPassportIsRegisteredProvider);
    _ref.invalidate(zkPassportRegistrationProvider);
  }

  /// Resets all challenge-related state: ZK identity flow, pipeline session,
  /// registration, and cached challenge data. Called from settings.
  Future<bool> resetChallengeData() async {
    final discarded = await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Reset');
    if (!discarded) return false;

    _ref.read(zkIdentityStepControllerProvider.notifier).reset();
    await clearActiveRegistration();
    _ref.invalidate(challengesProvider);
    _ref.invalidate(breakdownProvider);
    _ref.invalidate(categorizedChallengesProvider);
    return true;
  }

  Future<void> setFacematchStrict(bool value) async {
    final scope = await _captureAccountScope(_ref);
    if (scope == null) return;
    final repo = _ref.read(zkPassportSettingsRepositoryProvider);
    await repo.setFacematchStrict(scope.capability, value);
    _ref.invalidate(zkPassportSettingsProvider);
  }
}

class ZkPassportPipelineController
    extends StateNotifier<ZkPassportPipelineState> {
  static const Duration _serverStatusPollInterval = Duration(milliseconds: 300);
  static const Duration _serverStatusRefreshInterval =
      Duration(milliseconds: 1500);
  static const Duration _serverStatusBurstPollInterval =
      Duration(milliseconds: 100);
  static const Duration _serverStatusBurstWindow = Duration(seconds: 2);

  ZkPassportPipelineController(this._ref)
      : super(ZkPassportPipelineState.idle()) {
    _startupResetFuture = _resetRuntimeSessionOnStartup();
  }

  final Ref _ref;
  late final Future<void> _startupResetFuture;
  Future<void>? _pendingCompletionRetryInFlight;
  bool _inFlight = false;
  Timer? _serverPollingTimer;
  bool _serverPollingInFlight = false;
  bool _serverPollingAttemptInFlight = false;
  String? _serverPollingRequestId;
  int _lastServerStatusFetchAtMs = 0;
  int _serverPollingBurstUntilAtMs = 0;
  ZkPassportRuntimeSession? _runtimeSession;
  AccountCapability? _runtimeCapability;

  bool get isProofProcessing => _inFlight;

  bool _isPollingActiveFor(String requestId) {
    if (!_serverPollingInFlight) {
      return false;
    }
    if (_serverPollingRequestId != requestId) {
      return false;
    }
    final runtime = _runtimeSession;
    if (runtime == null ||
        runtime.requestId != requestId ||
        runtime.isTerminal) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _serverPollingTimer?.cancel();
    super.dispose();
  }

  ZkPassportRuntimeSessionRepository get _runtimeRepo =>
      _ref.read(zkPassportRuntimeSessionRepositoryProvider);

  int _runtimeSessionTimeoutSeconds() {
    return ZkPassportRequestPolicy.clientSessionTimeoutSeconds;
  }

  Future<void> _resetRuntimeSessionOnStartup() async {
    try {
      final scope = await _captureAccountScope(_ref);
      final persisted = scope == null
          ? null
          : await _runtimeRepo.loadForSession(
              appSessionId: scope.capability.sessionId,
              network: scope.capability.network,
              bucket: scope.capability.bucket,
            );
      // The container can be rebuilt (or torn down) while this startup read is
      // in flight — an identity boundary invalidates this provider.
      if (!mounted) return;
      if (persisted == null) {
        _stopServerPollingWorker();
        _runtimeSession = null;
        _runtimeCapability = null;
        _setState(
          status: ZkPassportPipelineStatus.idle,
          phase: ZkPassportPipelinePhase.idle,
          message: '',
        );
        return;
      }

      // If the session already reached a terminal state, discard it.
      if (persisted.isTerminal) {
        _log.info(
          'Clearing terminal zkPassport session on startup',
          context: {
            'requestId': persisted.requestId,
            'phase': persisted.phase.name,
          },
        );
        _stopServerPollingWorker();
        _runtimeSession = null;
        _runtimeCapability = null;
        await _runtimeRepo.clear(persisted);
        _setState(
          status: ZkPassportPipelineStatus.idle,
          phase: ZkPassportPipelinePhase.idle,
          message: '',
        );
        return;
      }

      // If the session is still within the timeout window, preserve it so that
      // foreground resume (or deep link) can pick it up and resume polling.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final timeoutAtMs =
          persisted.createdAtMs + (_runtimeSessionTimeoutSeconds() * 1000);
      if (nowMs < timeoutAtMs) {
        _log.info(
          'Preserving non-terminal zkPassport session on cold start',
          context: {
            'requestId': persisted.requestId,
            'phase': persisted.phase.name,
            'remainingSec': ((timeoutAtMs - nowMs) / 1000).round(),
          },
        );
        _runtimeSession = persisted;
        _runtimeCapability = scope!.capability;
        _setState(
          status: ZkPassportPipelineStatus.processing,
          phase: ZkPassportPipelinePhase.resuming,
          message: 'Recovering zkPassport session...',
          requestId: persisted.requestId,
          resumeAttemptCount: persisted.resumeAttemptCount,
        );
        return;
      }

      // Session expired while app was killed — discard.
      _log.warn(
        'Discarding expired zkPassport session on cold start',
        context: {
          'requestId': persisted.requestId,
          'phase': persisted.phase.name,
        },
      );
      _stopServerPollingWorker();
      _runtimeSession = null;
      _runtimeCapability = null;
      await _runtimeRepo.clear(persisted);
      _setState(
        status: ZkPassportPipelineStatus.idle,
        phase: ZkPassportPipelinePhase.idle,
        message: '',
      );
    } catch (e, st) {
      _log.warn(
        'Failed to reset zkPassport runtime session on app startup',
        context: {
          'error': e.toString(),
          'stackTrace': _truncateMessage(st.toString(), maxChars: 1200),
        },
      );
    } finally {
      // Retry any pending backend completion from a previous session.
      // Must run unconditionally — even when a non-expired session is preserved.
      if (mounted) unawaited(_retryPendingCompletionGuarded());
    }
  }

  /// Retries a stored pending backend completion outside cold start.
  ///
  /// Called after restore or reconciliation reaches Ready. Recovery sees only
  /// rows owned by that exact application session; retired-session rows stay
  /// inert. Concurrent triggers inside this host coalesce.
  Future<void> retryPendingCompletion() async {
    await _startupResetFuture;
    if (!mounted) return;
    await _retryPendingCompletionGuarded();
  }

  /// Coalesces duplicate triggers inside this disposable session host.
  Future<void> _retryPendingCompletionGuarded() {
    final inFlight = _pendingCompletionRetryInFlight;
    if (inFlight != null) return inFlight;

    late Future<void> run;
    run = _retryPendingCompletion().whenComplete(() {
      if (identical(_pendingCompletionRetryInFlight, run)) {
        _pendingCompletionRetryInFlight = null;
      }
    });
    _pendingCompletionRetryInFlight = run;
    return run;
  }

  /// [launchCapability] is captured with the wallet before the server await.
  /// A late continuation therefore keeps A's owner even if B is now current.
  Future<void> markLaunchStarted({
    required String requestId,
    required bool facematchStrict,
    required String? userPublicKey,
    required Identity launchIdentity,
    required AccountCapability launchCapability,
  }) async {
    await _startupResetFuture;
    if (_inFlight) {
      throw StateError('cannot replace an in-flight zkPassport proof');
    }
    final appSessionId = launchIdentity.sessionId?.trim();
    if (appSessionId == null ||
        appSessionId.isEmpty ||
        appSessionId != launchCapability.sessionId) {
      throw StateError('zkPassport launch has no exact application session');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final requestNonce = _newRequestNonce();
    // Every later write uses this immutable owner; cold recovery scans only
    // the current Ready session's prefix.
    final session = ZkPassportRuntimeSession(
      appSessionId: appSessionId,
      requestId: requestId,
      facematchStrict: facematchStrict,
      phase: ZkPassportPipelinePhase.launching,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: requestNonce,
      userPublicKey: userPublicKey,
      launchEpoch: launchIdentity.epoch,
      launchNetwork: launchCapability.network,
      launchBucket: launchCapability.bucket,
      launchParticipantId: launchIdentity.participantId,
    );
    _runtimeSession = session;
    _runtimeCapability = launchCapability;
    await _runtimeRepo.save(session);
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.launching,
      message: 'Preparing zkPassport launch request...',
      requestId: requestId,
      resumeAttemptCount: 0,
    );
  }

  Future<void> markLaunchFailed({
    required String requestId,
    required String message,
  }) async {
    await _startupResetFuture;
    await _finalizeRuntimeSession(
      requestId: requestId,
      phase: ZkPassportPipelinePhase.failed,
      status: ZkPassportPipelineStatus.failure,
      message: message,
    );
  }

  Future<void> reportImmediateFailure({required String message}) async {
    await _startupResetFuture;
    await _finalizeRuntimeSession(
      requestId: null,
      phase: ZkPassportPipelinePhase.failed,
      status: ZkPassportPipelineStatus.failure,
      message: message,
    );
  }

  Future<void> markLaunchDispatched({
    required String requestId,
  }) async {
    await _startupResetFuture;
    await _updateRuntimeSession(
      requestId: requestId,
      phase: ZkPassportPipelinePhase.waiting,
      resetResumeAttempts: true,
    );
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.waiting,
      message: 'zkPassport launch requested.',
      requestId: requestId,
      resumeAttemptCount: 0,
    );
  }

  void startServerResultPolling({
    required String requestId,
    bool immediate = false,
  }) {
    if (requestId.trim().isEmpty) {
      return;
    }
    _serverPollingRequestId = requestId;
    _serverPollingInFlight = true;
    if (immediate) {
      _serverPollingBurstUntilAtMs = DateTime.now().millisecondsSinceEpoch +
          _serverStatusBurstWindow.inMilliseconds;
    }
    _scheduleServerPollingAttempt(
      requestId: requestId,
      immediate: immediate,
    );
  }

  /// Returns false when proof verification has reached its non-cancellable
  /// in-flight section. Callers must leave their UI/state intact in that case.
  Future<bool> discardPendingSession({
    String? requestId,
    String? reason,
  }) async {
    await _startupResetFuture;
    if (_inFlight) {
      _log.warn('Refusing to discard a zkPassport session while its proof '
          'pipeline is still running');
      return false;
    }
    _stopServerPollingWorker();
    final runtime = _runtimeSession;
    if (runtime != null) {
      await _runtimeRepo.clear(runtime);
    }
    _runtimeSession = null;
    _runtimeCapability = null;
    _setState(
      status: ZkPassportPipelineStatus.idle,
      phase: ZkPassportPipelinePhase.idle,
      message: reason ?? '',
      requestId: requestId,
      resumeAttemptCount: 0,
    );
    return true;
  }

  Future<void> _updateRuntimeSession({
    required String requestId,
    required ZkPassportPipelinePhase phase,
    int? resumeAttemptCount,
    bool resetResumeAttempts = false,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final current = _runtimeSession;
    if (current == null || current.requestId != requestId) {
      _log.warn('Dropping a zkPassport runtime write without its exact '
          'owned operation');
      return;
    }
    final next = ZkPassportRuntimeSession(
      appSessionId: current.appSessionId,
      requestId: requestId,
      facematchStrict: current.facematchStrict,
      phase: phase,
      createdAtMs: current.createdAtMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: resetResumeAttempts
          ? 0
          : (resumeAttemptCount ?? current.resumeAttemptCount),
      requestNonce: current.requestNonce,
      userPublicKey: current.userPublicKey,
      // The launch identity is fixed for the session's lifetime.
      launchEpoch: current.launchEpoch,
      launchNetwork: current.launchNetwork,
      launchBucket: current.launchBucket,
      launchParticipantId: current.launchParticipantId,
    );
    _runtimeSession = next;
    await _runtimeRepo.save(next);
  }

  Future<void> _finalizeRuntimeSession({
    required String? requestId,
    required ZkPassportPipelinePhase phase,
    required ZkPassportPipelineStatus status,
    required String message,
    int? fetchOuterProofMs,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    List<String>? outerPublicInputsHex,
  }) async {
    final normalizedRequestId = requestId?.trim();
    final current = _runtimeSession;
    if (normalizedRequestId != null &&
        normalizedRequestId.isNotEmpty &&
        current != null &&
        current.requestId != normalizedRequestId) {
      _log.warn('Ignoring stale zkPassport finalization for '
          '$normalizedRequestId; current request is ${current.requestId}');
      return;
    }
    if (normalizedRequestId != null && normalizedRequestId.isNotEmpty) {
      await _updateRuntimeSession(
        requestId: normalizedRequestId,
        phase: phase,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
    }
    _stopServerPollingWorker();
    _setState(
      status: status,
      phase: phase,
      message: message,
      requestId: normalizedRequestId,
      fetchOuterProofMs: fetchOuterProofMs,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      outerPublicInputsHex: outerPublicInputsHex,
      resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
    );
    final runtime = _runtimeSession;
    if (runtime != null) {
      await _runtimeRepo.clear(runtime);
    }
    _runtimeSession = null;
    _runtimeCapability = null;
  }

  Future<void> recoverPendingSessionOnForeground() async {
    await _startupResetFuture;
    if (!mounted) return;
    if (_inFlight) {
      return;
    }
    final runtime = _runtimeSession;
    if (runtime == null || runtime.isTerminal) {
      return;
    }
    final requestId = runtime.requestId.trim();
    if (requestId.isEmpty) {
      return;
    }
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.resuming,
      message: 'Checking zkPassport session status after foreground...',
      requestId: requestId,
      resumeAttemptCount: runtime.resumeAttemptCount,
    );
    startServerResultPolling(
      requestId: requestId,
      immediate: true,
    );
  }

  void _scheduleServerPollingAttempt({
    required String requestId,
    bool immediate = false,
  }) {
    if (!_serverPollingInFlight || _serverPollingRequestId != requestId) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final delay = immediate
        ? Duration.zero
        : (nowMs < _serverPollingBurstUntilAtMs
            ? _serverStatusBurstPollInterval
            : _serverStatusPollInterval);
    _serverPollingTimer?.cancel();
    _serverPollingTimer = Timer(delay, () {
      unawaited(
        _runServerPollingAttempt(
          requestId: requestId,
        ),
      );
    });
  }

  Future<void> _runServerPollingAttempt({
    required String requestId,
  }) async {
    if (!_serverPollingInFlight ||
        _serverPollingRequestId != requestId ||
        _inFlight ||
        _serverPollingAttemptInFlight) {
      return;
    }

    _serverPollingAttemptInFlight = true;
    try {
      final runtime = _runtimeSession;
      if (runtime == null ||
          runtime.requestId != requestId ||
          runtime.isTerminal) {
        _stopServerPollingWorker();
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final timeoutAtMs =
          runtime.createdAtMs + (_runtimeSessionTimeoutSeconds() * 1000);
      if (nowMs >= timeoutAtMs) {
        if (!_isPollingActiveFor(requestId)) {
          return;
        }
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.timedOut,
          status: ZkPassportPipelineStatus.failure,
          message:
              'zkPassport session timed out before proof became available.',
        );
        return;
      }

      final sessionServerRepo =
          _ref.read(zkPassportSessionServerRepositoryProvider);
      if (sessionServerRepo == null) {
        if (!_isPollingActiveFor(requestId)) {
          return;
        }
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Session server is not configured.',
        );
        return;
      }

      ZkPassportSessionResultResponse? result;
      var resultFetchFailed = false;
      final userPublicKey = await _userPublicKeyForRuntime(runtime);
      final resultWaitMs = nowMs < _serverPollingBurstUntilAtMs
          ? _serverStatusBurstPollInterval.inMilliseconds
          : _serverStatusPollInterval.inMilliseconds;
      final fetchStopwatch = Stopwatch()..start();
      try {
        result = await sessionServerRepo.tryGetSessionResult(
          sessionId: requestId,
          waitMs: resultWaitMs,
          userPublicKey: userPublicKey,
        );
      } catch (e, st) {
        resultFetchFailed = true;
        if (e is ZkPassportSessionServerException) {
          if (e.statusCode == 404) {
            if (!_isPollingActiveFor(requestId)) {
              return;
            }
            await _finalizeRuntimeSession(
              requestId: requestId,
              phase: ZkPassportPipelinePhase.failed,
              status: ZkPassportPipelineStatus.failure,
              message:
                  'zkPassport session was not found on server. Start a new request.',
            );
            return;
          }
          if (e.statusCode == 410) {
            if (!_isPollingActiveFor(requestId)) {
              return;
            }
            await _finalizeRuntimeSession(
              requestId: requestId,
              phase: ZkPassportPipelinePhase.failed,
              status: ZkPassportPipelineStatus.failure,
              message:
                  'zkPassport session result was already consumed on server. Start a new request.',
            );
            return;
          }
        }
        _log.warn(
          'Session server result fetch failed',
          context: {
            'requestId': requestId,
            'error': e.toString(),
            'stackTrace': _truncateMessage(st.toString(), maxChars: 800),
          },
        );
      } finally {
        fetchStopwatch.stop();
      }

      if (!_isPollingActiveFor(requestId)) {
        return;
      }

      var scheduleImmediateRetry = false;

      final readyResult = result;
      if (readyResult != null) {
        final outerProof = readyResult.outerProofB64Url;
        if (!readyResult.success || outerProof == null) {
          _log.warn(
            'zkPassport result envelope rejected',
            context: {
              'requestId': requestId,
              'serverStatus': readyResult.status,
              'errorFromBridge': readyResult.error,
              'outerProofPresent': outerProof != null,
              'nullifierPresent': readyResult.nullifierHex != null,
            },
          );
          await _finalizeRuntimeSession(
            requestId: requestId,
            phase: ZkPassportPipelinePhase.failed,
            status: ZkPassportPipelineStatus.failure,
            message: readyResult.error ??
                'zkPassport session completed without a proof.',
            fetchOuterProofMs: fetchStopwatch.elapsedMilliseconds,
          );
          return;
        }

        _stopServerPollingWorker();
        unawaited(
          _runPipeline(
            requestId,
            outerProof,
            serverNullifierHex: readyResult.nullifierHex,
            fetchOuterProofMs: fetchStopwatch.elapsedMilliseconds,
          ),
        );
        return;
      }

      if (!resultFetchFailed) {
        // If the server waited before returning "not ready", we can immediately
        // start the next attempt (long-poll style). If the server returns 409
        // instantly (older server), fall back to interval-based polling.
        if (fetchStopwatch.elapsedMilliseconds >= 50 && resultWaitMs > 0) {
          scheduleImmediateRetry = true;
        }

        // result_not_ready: keep polling. We occasionally refresh status so we can
        // fail fast if the server has already terminated the session.
        final shouldRefreshStatus = nowMs - _lastServerStatusFetchAtMs >=
            _serverStatusRefreshInterval.inMilliseconds;
        if (shouldRefreshStatus) {
          try {
            _lastServerStatusFetchAtMs = nowMs;
            final status = await sessionServerRepo.getSessionStatus(
              sessionId: requestId,
              userPublicKey: userPublicKey,
            );

            if (!_isPollingActiveFor(requestId)) {
              return;
            }

            // FIXME(follow-up): Treat result_ok/finalAvailable as proof-ready
            // and refetch /result; only result_error and expired should fail.
            if (status.isTerminal) {
              final normalized = status.status.trim().toLowerCase();
              final phase = normalized == 'expired'
                  ? ZkPassportPipelinePhase.timedOut
                  : ZkPassportPipelinePhase.failed;
              _log.warn(
                'zkPassport polling reached terminal non-success state',
                context: {
                  'requestId': requestId,
                  'serverStatus': status.status,
                  'normalizedStatus': normalized,
                  'finalAvailable': status.finalAvailable,
                  'updatedAtMs': status.updatedAtMs,
                },
              );
              await _finalizeRuntimeSession(
                requestId: requestId,
                phase: phase,
                status: ZkPassportPipelineStatus.failure,
                message: normalized == 'expired'
                    ? 'zkPassport session expired before completion.'
                    : 'zkPassport session completed without a proof.',
              );
              return;
            }
          } catch (statusError, statusSt) {
            if (statusError is ZkPassportSessionServerException &&
                statusError.statusCode == 404) {
              if (!_isPollingActiveFor(requestId)) {
                return;
              }
              await _finalizeRuntimeSession(
                requestId: requestId,
                phase: ZkPassportPipelinePhase.failed,
                status: ZkPassportPipelineStatus.failure,
                message:
                    'zkPassport session was not found on server. Start a new request.',
              );
              return;
            }
            _log.warn(
              'Session server status refresh failed',
              context: {
                'requestId': requestId,
                'error': statusError.toString(),
                'stackTrace':
                    _truncateMessage(statusSt.toString(), maxChars: 800),
              },
            );
          }
        }
      }

      _scheduleServerPollingAttempt(
        requestId: requestId,
        immediate: scheduleImmediateRetry,
      );
    } finally {
      _serverPollingAttemptInFlight = false;
    }
  }

  void _stopServerPollingWorker() {
    _serverPollingTimer?.cancel();
    _serverPollingTimer = null;
    _serverPollingInFlight = false;
    _serverPollingRequestId = null;
    _serverPollingBurstUntilAtMs = 0;
  }

  Future<void> _runPipeline(
    String requestId,
    String outerProofB64Url, {
    String? serverNullifierHex,
    int? fetchOuterProofMs,
  }) async {
    _inFlight = true;
    final runtimeAtStart = _runtimeSession;
    if (runtimeAtStart == null || runtimeAtStart.requestId != requestId) {
      try {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The zkPassport request generation could not be verified. '
              'Please retry the verification.',
        );
      } finally {
        _inFlight = false;
      }
      return;
    }
    final requestVersion = runtimeAtStart.requestVersion;
    if (requestVersion == null) {
      try {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message:
              'This zkPassport request predates exact completion tracking. '
              'Please retry the verification.',
        );
      } finally {
        _inFlight = false;
      }
      return;
    }
    final capability = _runtimeCapability;
    final participantId = runtimeAtStart.launchParticipantId;
    if (capability == null ||
        capability.sessionId != runtimeAtStart.appSessionId ||
        participantId == null) {
      try {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The zkPassport request owner could not be verified. '
              'Please retry the verification.',
        );
      } finally {
        _inFlight = false;
      }
      return;
    }
    List<String>? outerPublicInputsHex;
    try {
      _log.warn(
        'Starting zkPassport pipeline from session server result',
        context: {
          'requestId': requestId,
          'outerProofLen': outerProofB64Url.length,
        },
      );
      final outerProof = outerProofB64Url.trim();
      if (outerProof.isEmpty) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Session server returned an empty outer proof payload.',
          fetchOuterProofMs: fetchOuterProofMs,
        );
        return;
      }

      final rpc = await _ensureNodeRpcReadyForPipeline();
      if (rpc == null) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Node RPC is unavailable; start the node and retry.',
          fetchOuterProofMs: fetchOuterProofMs,
        );
        return;
      }

      final outerProofPrefixedBytes =
          _ensurePrefixedBbHonkProofBlobBytes(outerProof);
      final facematchStrict = _runtimeSession?.facematchStrict ?? false;

      if (requestId.isNotEmpty) {
        await _updateRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.verifyingOuter,
          resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
        );
      }
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.verifyingOuter,
        message: 'Verifying outer proof...',
        requestId: requestId,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final verifyOuter = await rpc.zkpassportVerifyOuter(
        outerProof: outerProofPrefixedBytes,
        facematchStrict: facematchStrict,
      );
      if (verifyOuter == null) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Outer proof verification returned no response.',
          fetchOuterProofMs: fetchOuterProofMs,
        );
        return;
      }
      final verifyOuterMs = verifyOuter.elapsedMs.toInt();
      if (!verifyOuter.verified) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: verifyOuter.error ?? 'Outer proof verification failed.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
        );
        return;
      }
      outerPublicInputsHex = verifyOuter.publicInputsHex;

      final outerInputValidation = ZkPassportOuterProofValidation.validate(
        publicInputsHex: verifyOuter.publicInputsHex,
        facematchStrict: facematchStrict,
        bridgeNullifierHex: serverNullifierHex,
      );
      if (!outerInputValidation.isValid) {
        _log.error(
          'Outer proof public input validation failed',
          context: {
            'requestId': requestId,
            'error': outerInputValidation.errorMessage,
            'serverNullifierHex':
                outerInputValidation.normalizedBridgeNullifierHex,
            'publicInputsLen': verifyOuter.publicInputsHex?.length,
          },
        );
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: outerInputValidation.errorMessage ??
              'Outer proof verified, but SDK 0.14 public inputs were invalid.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }

      final derivedNullifierHex =
          outerInputValidation.publicInputs!.scopedNullifierHex;

      if (requestId.isNotEmpty) {
        await _updateRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.wrapping,
          resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
        );
      }
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.wrapping,
        message: 'Wrapping proof into mega-compatible shape...',
        requestId: requestId,
        verifyOuterMs: verifyOuterMs,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final wrapOuter = await rpc.zkpassportWrapOuter(
        outerProof: outerProofPrefixedBytes,
        facematchStrict: facematchStrict,
      );
      if (wrapOuter == null) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Proof wrapping returned no response.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }
      final wrapOuterMs = wrapOuter.elapsedMs.toInt();
      final wrappedProof = wrapOuter.wrappedProofB64Url;
      if (!wrapOuter.wrapped || wrappedProof == null || wrappedProof.isEmpty) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: wrapOuter.error ?? 'Proof wrapping failed.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }

      if (requestId.isNotEmpty) {
        await _updateRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.verifyingWrapped,
          resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
        );
      }
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.verifyingWrapped,
        message: 'Verifying wrapped mega proof...',
        requestId: requestId,
        verifyOuterMs: verifyOuterMs,
        wrapOuterMs: wrapOuterMs,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final verifyWrapped = await rpc.zkpassportVerifyWrapped(
        wrappedProof: _decodeB64UrlToBytes(wrappedProof),
        facematchStrict: facematchStrict,
      );
      if (verifyWrapped == null) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Wrapped proof verification returned no response.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }
      final verifyWrappedMs = verifyWrapped.elapsedMs.toInt();
      if (!verifyWrapped.verified) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: verifyWrapped.error ?? 'Wrapped proof verification failed.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          verifyWrappedMs: verifyWrappedMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }

      final flowController = _ref.read(zkPassportFlowControllerProvider);
      _PreparedBackendCompletion? completion;
      if (AppConfig.viewOnly) {
        await flowController.storeSuccessfulRegistrationForAccount(
          capability: capability,
          nullifierHex: derivedNullifierHex,
          requestVersion: requestVersion,
          facematchVerified: _runtimeSession?.facematchStrict,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          verifyWrappedMs: verifyWrappedMs,
        );
      } else {
        completion = await _prepareBackendCompletion(
          capability: capability,
          participantId: participantId,
          sessionId: requestId,
          nullifierHex: derivedNullifierHex,
          requestVersion: requestVersion,
        );
        if (completion == null) {
          await _finalizeRuntimeSession(
            requestId: requestId,
            phase: ZkPassportPipelinePhase.failed,
            status: ZkPassportPipelineStatus.failure,
            message: 'The verified proof could not be queued for delivery. '
                'Please retry the verification.',
            fetchOuterProofMs: fetchOuterProofMs,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
            outerPublicInputsHex: outerPublicInputsHex,
          );
          return;
        }
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        await persistZkCompletionInOrder(
          persistOutbox: () => repo.storePendingCompletion(
            capability: completion!.capability,
            participantId: completion.participantId,
            challengeId: completion.challengeId,
            sessionId: completion.sessionId,
            nullifierHex: completion.nullifierHex,
            requestVersion: completion.requestVersion,
            facematchVerified: runtimeAtStart.facematchStrict,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
          ),
          persistRegistration: () =>
              flowController.storeSuccessfulRegistrationForAccount(
            capability: completion!.capability,
            nullifierHex: derivedNullifierHex,
            requestVersion: requestVersion,
            facematchVerified: runtimeAtStart.facematchStrict,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
          ),
        );
      }

      if (completion != null) {
        unawaited(_deliverBackendCompletion(completion));
      }

      await _finalizeRuntimeSession(
        requestId: requestId,
        phase: ZkPassportPipelinePhase.success,
        status: ZkPassportPipelineStatus.success,
        message: 'zkPassport proof accepted and wrapped successfully.',
        fetchOuterProofMs: fetchOuterProofMs,
        verifyOuterMs: verifyOuterMs,
        wrapOuterMs: wrapOuterMs,
        verifyWrappedMs: verifyWrappedMs,
        outerPublicInputsHex: outerPublicInputsHex,
      );
    } catch (e) {
      await _finalizeRuntimeSession(
        requestId: requestId,
        phase: ZkPassportPipelinePhase.failed,
        status: ZkPassportPipelineStatus.failure,
        message: 'zkPassport pipeline failed: $e',
        fetchOuterProofMs: fetchOuterProofMs,
        outerPublicInputsHex: outerPublicInputsHex,
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<NodeRpcClient?> _ensureNodeRpcReadyForPipeline() async {
    final backend = RustBackendService.instance;
    final existingRpc = backend.rpc;
    if (existingRpc != null) {
      await backend.resumeNode();
      return existingRpc;
    }

    _log.info('Starting node for zkPassport proof verification');
    final started = await backend.startNode();
    if (!started) {
      return null;
    }
    await backend.resumeNode();
    return backend.rpc;
  }

  Uint8List _decodeB64UrlToBytes(String payloadB64Url) {
    final normalized = base64Url.normalize(payloadB64Url);
    return Uint8List.fromList(base64Url.decode(normalized));
  }

  Uint8List _ensurePrefixedBbHonkProofBlobBytes(String proofB64Url) {
    // Barretenberg honk proof blobs are encoded as:
    // - 4-byte big-endian u32 field count (n)
    // - followed by n * 32 bytes of field elements
    //
    // zkPassport session server returns a flat concatenation of 32-byte fields (no prefix),
    // so we add the prefix here and keep the node RPC strict (prefixed-only).
    const prefixBytes = 4;
    const frBytes = 32;

    final raw = _decodeB64UrlToBytes(proofB64Url);

    if (raw.length >= prefixBytes &&
        (raw.length - prefixBytes) % frBytes == 0) {
      final nFields = (raw[0] << 24) | (raw[1] << 16) | (raw[2] << 8) | raw[3];
      final expectedLen = prefixBytes + (nFields * frBytes);
      if (expectedLen == raw.length) {
        return raw;
      }
    }

    if (raw.isEmpty || raw.length % frBytes != 0) {
      throw FormatException(
        'Invalid zkPassport proof payload length ${raw.length}; expected 32*n bytes',
      );
    }
    final nFields = raw.length ~/ frBytes;
    if (nFields > 0xFFFFFFFF) {
      throw const FormatException('zkPassport proof has too many fields');
    }

    final out = Uint8List(prefixBytes + raw.length);
    out[0] = (nFields >> 24) & 0xFF;
    out[1] = (nFields >> 16) & 0xFF;
    out[2] = (nFields >> 8) & 0xFF;
    out[3] = nFields & 0xFF;
    out.setRange(prefixBytes, out.length, raw);
    return out;
  }

  // ---------------------------------------------------------------------------
  // Backend completion
  // ---------------------------------------------------------------------------

  Future<_PreparedBackendCompletion?> _prepareBackendCompletion({
    required AccountCapability capability,
    required int participantId,
    required String sessionId,
    required String nullifierHex,
    required ZkPassportRequestVersion requestVersion,
  }) async {
    try {
      final challengeId = _ref.read(zkIdentityChallengeIdProvider);

      if (challengeId == null) {
        _log.warn('Skipping backend completion: missing data', context: {
          'participantId': participantId,
          'challengeId': challengeId,
        });
        await SentryUtil.captureMessageWithData(
          'zkPassport backend completion skipped: missing data',
          {
            'participant_id': participantId,
            'challenge_id': challengeId,
            'session_id': sessionId,
          },
          level: SentryLevel.warning,
        );
        return null;
      }

      return _PreparedBackendCompletion(
        capability: capability,
        participantId: participantId,
        challengeId: challengeId,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
        requestVersion: requestVersion,
      );
    } catch (e, st) {
      _log.warn('Failed to prepare zkPassport backend completion', context: {
        'error': e.toString(),
      });
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
      return null;
    }
  }

  /// Delivers an already-durable completion. The outbox was written before
  /// the optimistic registration, so this method never owns that ordering.
  Future<void> _deliverBackendCompletion(
    _PreparedBackendCompletion completion,
  ) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    try {
      final api = _ref.read(leaderboardApiServiceProvider);
      const delays = <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ];
      Object? lastError;
      StackTrace? lastStack;

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final ok = await api.completeZkPassport(
            appSessionId: completion.appSessionId,
            challengeId: completion.challengeId,
            walletAddress: completion.walletAddress,
            sessionId: completion.sessionId,
            nullifierHex: completion.nullifierHex,
          );
          if (ok) {
            _log.info('Backend completion succeeded');
            await repo.recordRequestOutcome(
              capability: completion.capability,
              version: completion.requestVersion,
              outcome: ZkPassportRequestOutcome.delivered,
            );
            _ref.invalidate(zkPassportIsRegisteredProvider);
            _ref.invalidate(zkPassportRegistrationProvider);
            unawaited(refreshAllLeaderboardData(_ref));
            return;
          }
          // Defensive: the contract returns true or throws.
          lastError = StateError('completeZkPassport returned false');
          lastStack = StackTrace.current;
          break;
        } on LeaderboardApiException catch (e, st) {
          lastError = e;
          lastStack = st;
          final retryable =
              e.statusCode >= 500 || e.statusCode == 408 || e.statusCode == 429;
          if (!retryable || attempt == delays.length - 1) break;
          await Future<void>.delayed(delays[attempt]);
        } catch (e, st) {
          lastError = e;
          lastStack = st;
          if (attempt == delays.length - 1) break;
          await Future<void>.delayed(delays[attempt]);
        }
      }

      // Terminal client rejection (4xx other than 408/429): the backend has
      // permanently refused this completion — retrying can never succeed.
      // Roll back its exact owner instead of leaving a row that loops forever.
      if (isTerminalZkCompletionRejection(lastError)) {
        await _handleTerminalCompletionRejection(
          lastError!,
          lastStack,
          capability: completion.capability,
          requestVersion: completion.requestVersion,
        );
        return;
      }

      // Retryable failure: the outbox row persisted above carries the retry.
      _log.warn('Backend completion failed, stored for retry', context: {
        'error': lastError?.toString(),
      });
      await SentryUtil.captureError(
        lastError ?? StateError('zkpassport completion failed'),
        lastStack ?? StackTrace.current,
        tag: 'zkpassport_completion',
      );
    } catch (e, st) {
      _log.warn('Backend completion delivery failed unexpectedly', context: {
        'error': e.toString(),
      });
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
    }
  }

  /// Records one outcome under the rejected operation's immutable owner. The
  /// outbox and optimistic registration views both consume that marker.
  Future<void> _handleTerminalCompletionRejection(
    Object error,
    StackTrace? stack, {
    required AccountCapability capability,
    ZkPassportRequestVersion? requestVersion,
  }) async {
    _log.warn('Backend permanently rejected zkPassport completion', context: {
      'error': error.toString(),
    });
    await SentryUtil.captureError(
      error,
      stack ?? StackTrace.current,
      tag: 'zkpassport_completion_rejected',
    );

    if (requestVersion != null) {
      try {
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        // This append-only marker retires the exact outbox row and rolls back
        // the exact optimistic registration. Cleanup is intentionally not a
        // correctness boundary.
        await repo.recordRequestOutcome(
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
        );
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      } catch (e, st) {
        await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
      }
    }
  }

  /// Retries the newest outbox row owned by this exact session host.
  Future<void> _retryPendingCompletion() async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    final scope = await _captureAccountScope(_ref);
    if (scope == null) return;
    final capability = scope.capability;
    ZkPassportRequestVersion? pendingRequestVersion;
    try {
      final pending = await repo.getPendingCompletion(capability);
      if (pending == null) return;

      final requestVersion = ZkPassportRequestVersion.fromJson(pending);
      if (requestVersion == null) return;
      pendingRequestVersion = requestVersion;
      final participantId = pending['participant_id'];
      final challengeId = pending['challenge_id'];
      final walletAddress = pending['wallet_address'];
      final sessionId = pending['session_id'];
      final nullifierHex = pending['nullifier_hex'];
      final accountId = pending['account_id'];
      if (participantId is! int ||
          challengeId is! int ||
          walletAddress is! String ||
          sessionId is! String ||
          nullifierHex is! String ||
          accountId is! String ||
          pending['app_session_id'] != capability.sessionId ||
          requestVersion.requestId != sessionId ||
          participantId != scope.identity.participantId ||
          walletAddress != capability.address ||
          accountId != capability.accountId) {
        _log.warn('Ignoring malformed zkPassport completion owner');
        return;
      }

      if (AppConfig.viewOnly) {
        await repo.recordRequestOutcome(
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.delivered,
        );
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        _log.info('Retired pending zkPassport completion in view-only mode');
        return;
      }

      // A crash after the outbox write but before the optimistic-registration
      // write leaves a recoverable outbox-only state. Recreate the exact local
      // marker before delivery; a terminal outcome will hide it atomically if
      // the backend rejects the completion.
      await _ref
          .read(zkPassportFlowControllerProvider)
          .storeSuccessfulRegistrationForAccount(
            capability: capability,
            nullifierHex: nullifierHex,
            requestVersion: requestVersion,
            facematchVerified: pending['facematch_verified'] is bool
                ? pending['facematch_verified'] as bool
                : null,
            verifyOuterMs: pending['verify_outer_ms'] is int
                ? pending['verify_outer_ms'] as int
                : null,
            wrapOuterMs: pending['wrap_outer_ms'] is int
                ? pending['wrap_outer_ms'] as int
                : null,
            verifyWrappedMs: pending['verify_wrapped_ms'] is int
                ? pending['verify_wrapped_ms'] as int
                : null,
          );

      final api = _ref.read(leaderboardApiServiceProvider);
      final ok = await api.completeZkPassport(
        appSessionId: capability.sessionId,
        challengeId: challengeId,
        walletAddress: walletAddress,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
      );

      if (ok) {
        _log.info('Pending completion retry succeeded');
        await repo.recordRequestOutcome(
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.delivered,
        );
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      }
    } on LeaderboardApiException catch (e, st) {
      if (isTerminalZkCompletionRejection(e) && pendingRequestVersion != null) {
        await _handleTerminalCompletionRejection(
          e,
          st,
          capability: capability,
          requestVersion: pendingRequestVersion,
        );
        return;
      }
      // Retryable (5xx/408/429): keep the pending record for the next
      // cold start.
      _log.warn('Pending completion retry failed: $e');
      await SentryUtil.captureError(
        e,
        st,
        tag: 'zkpassport_completion_retry',
      );
    } catch (e, st) {
      _log.warn('Pending completion retry failed: $e');
      await SentryUtil.captureError(
        e,
        st,
        tag: 'zkpassport_completion_retry',
      );
    }
  }

  void _setState({
    required ZkPassportPipelineStatus status,
    required ZkPassportPipelinePhase phase,
    required String message,
    String? requestId,
    int? fetchOuterProofMs,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    int? resumeAttemptCount,
    List<String>? outerPublicInputsHex,
  }) {
    if (!mounted) return;
    if (status == ZkPassportPipelineStatus.failure) {
      _log.warn(
        'zkPassport pipeline failure',
        context: {
          'requestId': requestId,
          'message': message,
          'verifyOuterMs': verifyOuterMs,
          'wrapOuterMs': wrapOuterMs,
          'verifyWrappedMs': verifyWrappedMs,
        },
      );
    }
    state = ZkPassportPipelineState(
      status: status,
      phase: phase,
      message: message,
      requestId: requestId,
      fetchOuterProofMs: fetchOuterProofMs,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      resumeAttemptCount: resumeAttemptCount,
      outerPublicInputsHex: outerPublicInputsHex,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _truncateMessage(String value, {required int maxChars}) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars - 3)}...';
  }

  Future<String?> _userPublicKeyForRuntime(
    ZkPassportRuntimeSession runtime,
  ) async {
    final persisted = runtime.userPublicKey?.trim();
    if (persisted != null && persisted.isNotEmpty) {
      return persisted;
    }

    try {
      final capability = _runtimeCapability;
      if (capability == null || capability.sessionId != runtime.appSessionId) {
        return null;
      }
      final accounts = await _ref.read(accountsProvider.future);
      final active = await accounts.getAuthorizedAccount(capability);
      if (active == null) {
        return null;
      }
      final activePublicKey = active.publicKey.trim();
      return activePublicKey.isEmpty ? null : activePublicKey;
    } catch (e) {
      _log.debug('Unable to resolve zkPassport user public key: $e');
      return null;
    }
  }
}
