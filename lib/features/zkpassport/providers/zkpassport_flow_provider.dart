import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';
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

/// Result of validating the current identity against a runtime session's
/// persisted launch identity.
enum _LaunchIdentityCheck {
  /// Same user (or a legacy session without launch info) — proceed.
  match,

  /// The current identity is unsettled (boot restore or reconcile in
  /// flight) — retry later; neither act nor discard.
  defer,

  /// A different settled identity — the session belongs to another user and
  /// must not be resumed, stored, or completed under this one.
  mismatch,
}

class _PreparedBackendCompletion {
  const _PreparedBackendCompletion({
    required this.participantId,
    required this.challengeId,
    required this.walletAddress,
    required this.sessionId,
    required this.nullifierHex,
    required this.requestVersion,
    required this.identity,
    required this.accountId,
  });

  final int participantId;
  final int challengeId;
  final String walletAddress;
  final String sessionId;
  final String nullifierHex;
  final ZkPassportRequestVersion requestVersion;
  final Identity identity;
  final String accountId;

  String get bucket => identity.bucket;
  bool get identityWasSettled => identity.isSettled;
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

final zkPassportSettingsProvider =
    FutureProvider<ZkPassportSettings>((ref) async {
  final repo = ref.watch(zkPassportSettingsRepositoryProvider);
  return repo.load();
});

final zkPassportIsRegisteredProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(zkPassportRegistrationRepositoryProvider);
  return repo.isRegistered();
});

final zkPassportRegistrationProvider =
    FutureProvider<ZkPassportLocalRegistration>((ref) async {
  final repo = ref.watch(zkPassportRegistrationRepositoryProvider);
  return repo.getActiveRegistration();
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
  final controller = ZkPassportPipelineController(ref);
  // A cold-start outbox retry can run before the async challenges list has
  // resolved. Retry again when the authoritative ZK challenge becomes
  // available; the controller coalesces duplicate triggers.
  ref.listen<int?>(
    zkIdentityChallengeIdProvider,
    (previous, next) {
      if (next == null || next == previous) return;
      unawaited(controller.retryPendingCompletion());
    },
    fireImmediately: true,
  );
  return controller;
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

    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
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
    final settings = await settingsRepo.load();
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

  Future<void> setRegistered(bool value) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeActiveRegistration(
      registered: value,
      nullifierHex: null,
    );
    _ref.invalidate(zkPassportIsRegisteredProvider);
    _ref.invalidate(zkPassportRegistrationProvider);
  }

  Future<void> storeSuccessfulRegistration({
    required String? nullifierHex,
    required ZkPassportRequestVersion requestVersion,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeActiveRegistration(
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

  Future<void> storeSuccessfulRegistrationForAccount({
    required String accountId,
    required String bucket,
    required String? nullifierHex,
    required ZkPassportRequestVersion requestVersion,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeRegistrationForAccount(
      accountId: accountId,
      bucket: bucket,
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
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.clearActiveRegistration();
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
    final repo = _ref.read(zkPassportSettingsRepositoryProvider);
    await repo.setFacematchStrict(value);
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
  Identity? _pendingCompletionRetryIdentity;
  int? _pendingCompletionRetryChallengeId;
  bool _inFlight = false;
  Timer? _serverPollingTimer;
  bool _serverPollingInFlight = false;
  bool _serverPollingAttemptInFlight = false;
  String? _serverPollingRequestId;
  int _lastServerStatusFetchAtMs = 0;
  int _serverPollingBurstUntilAtMs = 0;
  ZkPassportRuntimeSession? _runtimeSession;

  bool get isProofProcessing => _inFlight;

  /// How the CURRENT identity relates to the identity that launched
  /// [runtime] (see [ZkPassportRuntimeSession.launchBucket]).
  ///
  /// The launching USER is identified by bucket + participant id — durable
  /// across process restarts, unlike the epoch, which is process-local and
  /// restarts from small values on every boot (so raw epoch equality across
  /// a restart would be meaningless). Sessions persisted by older app
  /// versions carry no launch identity and fail open as [match].
  _LaunchIdentityCheck _checkLaunchIdentity(ZkPassportRuntimeSession runtime) {
    final launchBucket = runtime.launchBucket;
    if (launchBucket == null) {
      return _LaunchIdentityCheck.match; // legacy session — fail open
    }
    final current = IdentitySnapshots.current;
    if (!current.isSettled) {
      // Boot restore / reconcile still in progress: WHO the app is hasn't
      // been established, so neither acting nor discarding is safe yet.
      return _LaunchIdentityCheck.defer;
    }
    final sameUser = current.bucket == launchBucket &&
        current.participantId == runtime.launchParticipantId;
    return sameUser
        ? _LaunchIdentityCheck.match
        : _LaunchIdentityCheck.mismatch;
  }

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
      final persisted = await _runtimeRepo.load();
      if (persisted == null) {
        _stopServerPollingWorker();
        _runtimeSession = null;
        state = ZkPassportPipelineState.idle();
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
        await _runtimeRepo.clear();
        state = ZkPassportPipelineState.idle();
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
        state = ZkPassportPipelineState(
          status: ZkPassportPipelineStatus.processing,
          phase: ZkPassportPipelinePhase.resuming,
          message: 'Recovering zkPassport session...',
          requestId: persisted.requestId,
          resumeAttemptCount: persisted.resumeAttemptCount,
          updatedAtMs: nowMs,
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
      await _runtimeRepo.clear();
      state = ZkPassportPipelineState.idle();
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
      unawaited(_retryPendingCompletionGuarded());
    }
  }

  /// Retries a stored pending backend completion outside cold start.
  ///
  /// Called when the identity settles into the ready phase (see
  /// `identityDriverProvider`) so a proof preserved across a 401 is
  /// submitted as soon as a fresh session exists, instead of only on the
  /// next process restart. Waits for the startup reset so it cannot race
  /// cold-start recovery; concurrent invocations coalesce onto one run.
  Future<void> retryPendingCompletion() async {
    await _startupResetFuture;
    await _retryPendingCompletionGuarded();
  }

  /// Coalesces retries only when both the exact identity scope and challenge
  /// readiness are unchanged. A ready identity must not join a reconciling
  /// run from the same epoch, and a newly-loaded challenge id must queue a
  /// fresh run behind one that already deferred on a null id.
  Future<void> _retryPendingCompletionGuarded() {
    final identity = IdentitySnapshots.current;
    final challengeId = _ref.read(zkIdentityChallengeIdProvider);
    final inFlight = _pendingCompletionRetryInFlight;
    if (inFlight != null &&
        _pendingCompletionRetryIdentity?.sameScopeAs(identity) == true &&
        _pendingCompletionRetryChallengeId == challengeId) {
      return inFlight;
    }

    late Future<void> run;
    run = _retryAfter(inFlight, identity).whenComplete(() {
      if (identical(_pendingCompletionRetryInFlight, run)) {
        _pendingCompletionRetryInFlight = null;
        _pendingCompletionRetryIdentity = null;
        _pendingCompletionRetryChallengeId = null;
      }
    });
    _pendingCompletionRetryInFlight = run;
    _pendingCompletionRetryIdentity = identity;
    _pendingCompletionRetryChallengeId = challengeId;
    return run;
  }

  Future<void> _retryAfter(Future<void>? previous, Identity identity) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // The stale run's failure was surfaced to its own caller.
      }
    }
    if (!identity.sameScopeAs(IdentitySnapshots.current)) {
      return; // superseded while waiting
    }
    await _retryPendingCompletion();
  }

  Future<void> markLaunchStarted({
    required String requestId,
    required bool facematchStrict,
    required String? userPublicKey,
  }) async {
    await _startupResetFuture;
    if (_inFlight) {
      throw StateError('cannot replace an in-flight zkPassport proof');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final requestNonce = _newRequestNonce();
    // Persist WHO launched this session. Every later stage (foreground
    // resume, polling, the proof pipeline) validates the current identity
    // against these before acting, so a session launched by user A is never
    // resumed, stored, or completed under user B — including across an app
    // restart, which the durable bucket + participant id survive.
    final launchIdentity = IdentitySnapshots.current;
    final session = ZkPassportRuntimeSession(
      requestId: requestId,
      facematchStrict: facematchStrict,
      phase: ZkPassportPipelinePhase.launching,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: requestNonce,
      userPublicKey: userPublicKey,
      launchEpoch: launchIdentity.epoch,
      launchBucket: launchIdentity.bucket,
      launchParticipantId: launchIdentity.participantId,
    );
    _runtimeSession = session;
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
    await _runtimeRepo.clear();
    _runtimeSession = null;
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
    final sameSession = current != null && current.requestId == requestId;
    final createdAtMs = sameSession ? current.createdAtMs : nowMs;
    final requestNonce =
        sameSession ? current.requestNonce : _newRequestNonce();
    final next = ZkPassportRuntimeSession(
      requestId: requestId,
      facematchStrict: sameSession ? current.facematchStrict : false,
      phase: phase,
      createdAtMs: createdAtMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: resetResumeAttempts
          ? 0
          : (resumeAttemptCount ??
              (sameSession ? current.resumeAttemptCount : 0)),
      requestNonce: requestNonce,
      userPublicKey: sameSession ? current.userPublicKey : null,
      // The launch identity is fixed for the session's lifetime.
      launchEpoch: sameSession ? current.launchEpoch : null,
      launchBucket: sameSession ? current.launchBucket : null,
      launchParticipantId: sameSession ? current.launchParticipantId : null,
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
    await _runtimeRepo.clear();
    _runtimeSession = null;
  }

  Future<void> recoverPendingSessionOnForeground() async {
    await _startupResetFuture;
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
    // A preserved session launched by a DIFFERENT user (sign-out + sign-in
    // while the app was backgrounded or killed) must not resume under the
    // current identity — its proof would be stored and completed as the
    // wrong user. Deferred (unsettled identity) is fine here: the polling
    // attempts re-validate on every tick.
    if (_checkLaunchIdentity(runtime) == _LaunchIdentityCheck.mismatch) {
      _log.warn(
        'Discarding zkPassport session launched by another identity',
        context: {'requestId': requestId},
      );
      await _finalizeRuntimeSession(
        requestId: requestId,
        phase: ZkPassportPipelinePhase.failed,
        status: ZkPassportPipelineStatus.failure,
        message: 'The zkPassport session belongs to a different signed-in '
            'account. Start a new verification.',
      );
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

      // Every polling tick re-validates the launch identity: a login /
      // logout / season rollover mid-poll must stop this session before a
      // ready result is fetched and fed to the pipeline as the new user.
      switch (_checkLaunchIdentity(runtime)) {
        case _LaunchIdentityCheck.match:
          break;
        case _LaunchIdentityCheck.defer:
          // Identity not settled yet (boot restore / reconcile): check
          // again on the next tick instead of acting or discarding.
          _scheduleServerPollingAttempt(requestId: requestId);
          return;
        case _LaunchIdentityCheck.mismatch:
          _log.warn(
            'Stopping zkPassport polling: session launched by another '
            'identity',
            context: {'requestId': requestId},
          );
          await _finalizeRuntimeSession(
            requestId: requestId,
            phase: ZkPassportPipelinePhase.failed,
            status: ZkPassportPipelineStatus.failure,
            message: 'The zkPassport session belongs to a different '
                'signed-in account. Start a new verification.',
          );
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
    // Bind this run to the identity that LAUNCHED the session (validated
    // here against the current one), not to whoever happens to be current
    // at result arrival: registration storage and backend completion below
    // are refused if a login / logout / season reconcile switched the
    // identity while proving was in flight — A's proof must never be stored
    // or submitted under B's account.
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
    if (_checkLaunchIdentity(runtimeAtStart) != _LaunchIdentityCheck.match) {
      try {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The signed-in identity changed while the proof was being '
              'produced. Please retry the verification.',
        );
      } finally {
        _inFlight = false;
      }
      return;
    }
    final pipelineIdentity = IdentitySnapshots.current;
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

      if (!pipelineIdentity.sameScopeAs(IdentitySnapshots.current)) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The signed-in identity changed while the proof was being '
              'verified. Please retry the verification.',
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
        await flowController.storeSuccessfulRegistration(
          nullifierHex: derivedNullifierHex,
          requestVersion: requestVersion,
          facematchVerified: _runtimeSession?.facematchStrict,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          verifyWrappedMs: verifyWrappedMs,
        );
      } else {
        completion = await _prepareBackendCompletion(
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
            participantId: completion!.participantId,
            challengeId: completion.challengeId,
            walletAddress: completion.walletAddress,
            sessionId: completion.sessionId,
            nullifierHex: completion.nullifierHex,
            requestVersion: completion.requestVersion,
            accountId: completion.accountId,
            facematchVerified: runtimeAtStart.facematchStrict,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
            bucket: completion.bucket,
          ),
          persistRegistration: () {
            if (!completion!.identity.sameScopeAs(IdentitySnapshots.current)) {
              throw const StaleAuthCredentialException();
            }
            return flowController.storeSuccessfulRegistrationForAccount(
              accountId: completion.accountId,
              bucket: completion.bucket,
              nullifierHex: derivedNullifierHex,
              requestVersion: requestVersion,
              facematchVerified: runtimeAtStart.facematchStrict,
              verifyOuterMs: verifyOuterMs,
              wrapOuterMs: wrapOuterMs,
              verifyWrappedMs: verifyWrappedMs,
            );
          },
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
    final started = await NodeLifecycleCoordinator.instance.startNode(
      reason: 'zkpassport_pipeline',
    );
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
    required String sessionId,
    required String nullifierHex,
    required ZkPassportRequestVersion requestVersion,
  }) async {
    final identity = IdentitySnapshots.current;
    try {
      final accountId = identity.accountId;
      final walletAddress = identity.address;
      if (!identity.isAuthenticated ||
          !identity.isSettled ||
          accountId == null ||
          walletAddress == null) {
        _log.warn('Skipping backend completion: identity has no confirmed '
            'account scope');
        return null;
      }
      final participantId = identity.participantId ??
          await _ref.read(participantIdProvider.future);
      final challengeId = _ref.read(zkIdentityChallengeIdProvider);

      if (participantId == null || challengeId == null) {
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

      if (!identity.sameScopeAs(IdentitySnapshots.current)) {
        _log.warn('Skipping backend completion: identity changed while '
            'preparing the durable outbox');
        return null;
      }

      return _PreparedBackendCompletion(
        participantId: participantId,
        challengeId: challengeId,
        walletAddress: walletAddress,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
        requestVersion: requestVersion,
        identity: identity,
        accountId: accountId,
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
    bool identityStillCurrent() =>
        completion.identity.sameScopeAs(IdentitySnapshots.current);
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    try {
      // An unsettled identity (reconciling) must not submit: the token and
      // account pairing is unknown. The row is durable — the identity driver
      // retries it as soon as the identity settles.
      if (!completion.identityWasSettled) {
        _log.info('Deferring backend completion until identity settles');
        return;
      }

      final api = _ref.read(leaderboardApiServiceProvider);
      const delays = <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ];
      Object? lastError;
      StackTrace? lastStack;

      for (var attempt = 0; attempt < 3; attempt++) {
        // Revalidate immediately before EVERY POST, not just at entry: the
        // retry delays below are exactly where a login can complete and
        // swap the token, and a request sent after that submits this proof
        // under the new identity's credentials.
        if (!identityStillCurrent()) {
          _log.warn('Deferring backend completion: identity changed before '
              'delivery (outbox row kept for its own identity)');
          return;
        }
        try {
          final ok = await api.completeZkPassport(
            challengeId: completion.challengeId,
            walletAddress: completion.walletAddress,
            sessionId: completion.sessionId,
            nullifierHex: completion.nullifierHex,
          );
          if (ok) {
            _log.info('Backend completion succeeded');
            await repo.recordRequestOutcome(
              version: completion.requestVersion,
              outcome: ZkPassportRequestOutcome.delivered,
              bucket: completion.bucket,
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
      // Roll back instead of leaving a retry row that would loop forever —
      // but only when the response answers THIS identity's submission; a
      // stale rejection says nothing about the current identity's records.
      if (isTerminalZkCompletionRejection(lastError)) {
        if (!identityStillCurrent()) {
          _log.warn('Ignoring terminal rejection from a superseded identity');
          return;
        }
        await _handleTerminalCompletionRejection(
          lastError!,
          lastStack,
          bucket: completion.bucket,
          requireIdentity: completion.identity,
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

  /// The backend permanently rejected this completion (e.g. 409 duplicate
  /// nullifier, 422 closed challenge). Clear the pending record so cold
  /// starts stop retrying it, and roll back the optimistic local
  /// registration so the challenge stops rendering as earned and the retry
  /// CTA returns.
  ///
  /// Versioned rows are rolled back by one append-only outcome write.
  /// [bucket] pins that event to the owning identity and [requireIdentity]
  /// rejects a stale response before it can publish an outcome.
  Future<void> _handleTerminalCompletionRejection(
    Object error,
    StackTrace? stack, {
    String? bucket,
    required Identity requireIdentity,
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

    if (!requireIdentity.sameScopeAs(IdentitySnapshots.current)) {
      _log.warn('Skipping completion rollback: identity changed during '
          'rejection handling');
      return;
    }

    if (requestVersion != null) {
      try {
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        // This append-only marker retires the exact outbox row and rolls back
        // the exact optimistic registration. Cleanup is intentionally not a
        // correctness boundary.
        await repo.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
          bucket: bucket,
        );
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      } catch (e, st) {
        await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
      }
      return;
    }

    // Legacy rows do not carry a request generation and cannot participate in
    // exact outcome matching. Preserve their pre-versioning cleanup behavior.
    try {
      final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
      // [bucket] pins the clear to the bucket the rejected record was read
      // from (retry path); null falls back to the active bucket (live
      // completion path, where the flow runs entirely within one identity).
      await repo.clearPendingCompletion(bucket: bucket);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
    }

    try {
      await _ref
          .read(zkPassportFlowControllerProvider)
          .clearActiveRegistration();
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
    }

    unawaited(refreshAllLeaderboardData(_ref));
  }

  /// Retries any stored pending completion (the identity-keyed outbox row).
  /// Reached (via [_retryPendingCompletionGuarded]) from cold start and from
  /// [retryPendingCompletion] when the identity driver observes a settled
  /// identity (sign-in reconcile completed, boot restore to ready).
  ///
  /// The run is bound to the identity snapshot it captures at the start:
  /// - it does not run at all while the identity is unsettled
  ///   ([Identity.isSettled] false) — the active bucket/token pairing is
  ///   unknown (an interrupted A→B switch can expose A's bucket with B's
  ///   token, and submitting A's proof as B would 422-terminally erase A's
  ///   valid record);
  /// - the storage bucket comes from the captured snapshot and every
  ///   read/clear is pinned to it, so a mid-flight bucket switch can't
  ///   redirect the clear;
  /// - the exact snapshot is re-checked before every clear/rollback — if
  ///   the identity changed (including a season-rollover account switch,
  ///   which bumps the epoch), the record is left in place for the new
  ///   identity's own run.
  Future<void> _retryPendingCompletion() async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    final identity = IdentitySnapshots.current;
    final bucket = identity.bucket;
    bool identityStillCurrent() =>
        identity.sameScopeAs(IdentitySnapshots.current);
    ZkPassportRequestVersion? pendingRequestVersion;
    try {
      if (!identity.isAuthenticated || !identity.isSettled) {
        _log.info('Skipping pending-completion retry: identity is '
            '${identity.phase.name} (not ready for authenticated delivery)');
        return;
      }

      final pending = await repo.getPendingCompletion(bucket: bucket);
      if (pending == null) return;

      final requestVersion = ZkPassportRequestVersion.fromJson(pending);
      pendingRequestVersion = requestVersion;
      final hasVersionFields = pending.containsKey('request_id') ||
          pending.containsKey('request_created_at_ms') ||
          pending.containsKey('request_nonce');

      if (AppConfig.viewOnly) {
        if (requestVersion == null) {
          await repo.clearPendingCompletion(bucket: bucket);
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.delivered,
            bucket: bucket,
          );
          _ref.invalidate(zkPassportIsRegisteredProvider);
          _ref.invalidate(zkPassportRegistrationProvider);
        }
        _log.info('Retired pending zkPassport completion in view-only mode');
        return;
      }

      // Validate types before casting — corrupt data should be cleared, not
      // retried forever.
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
          (hasVersionFields &&
              (requestVersion == null ||
                  requestVersion.requestId != sessionId ||
                  accountId is! String))) {
        _log.warn('Clearing corrupt pending completion data');
        await repo.clearPendingCompletion(bucket: bucket);
        return;
      }

      // Abandon the retry if the stored challenge_id no longer matches the
      // active ZK Identity row (e.g. a new season's row supersedes a stale one).
      // Retrying against a closed/replaced row would loop forever on 422.
      final currentChallengeId = _ref.read(zkIdentityChallengeIdProvider);
      if (currentChallengeId == null) {
        _log.info('Deferring pending completion until the active zkPassport '
            'challenge has loaded');
        return;
      }
      if (currentChallengeId != challengeId) {
        _log.warn(
          'Clearing pending completion targeting stale challenge_id=$challengeId '
          '(active row is $currentChallengeId)',
        );
        if (requestVersion == null) {
          await repo.clearPendingCompletion(bucket: bucket);
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.discarded,
            bucket: bucket,
          );
          _ref.invalidate(zkPassportIsRegisteredProvider);
          _ref.invalidate(zkPassportRegistrationProvider);
        }
        return;
      }

      // A crash after the outbox write but before the optimistic-registration
      // write leaves a recoverable outbox-only state. Recreate the exact local
      // marker before delivery; a terminal outcome will hide it atomically if
      // the backend rejects the completion.
      if (requestVersion != null) {
        if (identity.accountId != accountId ||
            identity.address != walletAddress ||
            identity.participantId != participantId) {
          _log.warn('Deferring pending completion: stored account scope no '
              'longer matches the current identity');
          return;
        }
        await _ref
            .read(zkPassportFlowControllerProvider)
            .storeSuccessfulRegistrationForAccount(
              accountId: accountId as String,
              bucket: bucket,
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
        if (!identityStillCurrent()) {
          _log.warn('Deferring pending completion: identity changed while '
              'repairing its optimistic registration');
          return;
        }
      }

      final api = _ref.read(leaderboardApiServiceProvider);
      // Last revalidation before the POST: the reads above are suspension
      // points where a transition can swap the token this request would be
      // sent with.
      if (!identityStillCurrent()) {
        _log.warn('Skipping pending-completion retry: identity changed '
            'before delivery');
        return;
      }
      final ok = await api.completeZkPassport(
        challengeId: challengeId,
        walletAddress: walletAddress,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
      );

      if (!identityStillCurrent()) {
        _log.warn('Session changed during pending-completion retry - '
            'leaving stored record untouched');
        return;
      }
      if (ok) {
        _log.info('Pending completion retry succeeded');
        if (requestVersion == null) {
          await repo.clearPendingCompletion(bucket: bucket);
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.delivered,
            bucket: bucket,
          );
        }
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      }
    } on LeaderboardApiException catch (e, st) {
      if (isTerminalZkCompletionRejection(e)) {
        if (!identityStillCurrent()) {
          // The rejection answered a submission made under a session that no
          // longer exists — it says nothing about the CURRENT identity's
          // record. Erasing the proof/registration here is how an interrupted
          // account switch destroys the previous user's valid pending proof.
          _log.warn('Ignoring terminal rejection from a superseded session');
          return;
        }
        await _handleTerminalCompletionRejection(
          e,
          st,
          bucket: bucket,
          requireIdentity: identity,
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
      final accounts = await AccountsRepository.create();
      final active = await accounts.getActive();
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
