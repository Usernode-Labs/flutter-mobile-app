import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/services/zkpassport_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = LoggingService.instance.withTag('usernode/ZkPassportFlow');

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
      await pipelineController.discardPendingSession(
        requestId: activeRequestId,
        reason:
            'Resetting previous zkPassport session before starting a new one.',
      );
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
  Future<void> resetChallengeData() async {
    _ref.read(zkIdentityStepControllerProvider.notifier).reset();
    await clearActiveRegistration();
    await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Reset');
    _ref.invalidate(challengesProvider);
    _ref.invalidate(breakdownProvider);
    _ref.invalidate(categorizedChallengesProvider);
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
  static const int _zkPassportOuterCount4SemanticPublicInputCount = 8;
  static const int _zkPassportOuterCount5SemanticPublicInputCount = 9;

  ZkPassportPipelineController(this._ref)
      : super(ZkPassportPipelineState.idle()) {
    _startupResetFuture = _resetRuntimeSessionOnStartup();
  }

  final Ref _ref;
  late final Future<void> _startupResetFuture;
  bool _inFlight = false;
  Timer? _serverPollingTimer;
  bool _serverPollingInFlight = false;
  bool _serverPollingAttemptInFlight = false;
  String? _serverPollingRequestId;
  int _lastServerStatusFetchAtMs = 0;
  int _serverPollingBurstUntilAtMs = 0;
  ZkPassportRuntimeSession? _runtimeSession;

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
      unawaited(_retryPendingCompletion());
    }
  }

  Future<void> markLaunchStarted({
    required String requestId,
    required bool facematchStrict,
  }) async {
    await _startupResetFuture;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final session = ZkPassportRuntimeSession(
      requestId: requestId,
      facematchStrict: facematchStrict,
      phase: ZkPassportPipelinePhase.launching,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
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

  Future<void> discardPendingSession({
    String? requestId,
    String? reason,
  }) async {
    await _startupResetFuture;
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
  }

  Future<void> _updateRuntimeSession({
    required String requestId,
    required ZkPassportPipelinePhase phase,
    int? resumeAttemptCount,
    bool resetResumeAttempts = false,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final current = _runtimeSession;
    final createdAtMs = current != null && current.requestId == requestId
        ? current.createdAtMs
        : nowMs;
    final next = ZkPassportRuntimeSession(
      requestId: requestId,
      facematchStrict: current != null && current.requestId == requestId
          ? current.facematchStrict
          : false,
      phase: phase,
      createdAtMs: createdAtMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: resetResumeAttempts
          ? 0
          : (resumeAttemptCount ??
              (current != null && current.requestId == requestId
                  ? current.resumeAttemptCount
                  : 0)),
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
      final resultWaitMs = nowMs < _serverPollingBurstUntilAtMs
          ? _serverStatusBurstPollInterval.inMilliseconds
          : _serverStatusPollInterval.inMilliseconds;
      final fetchStopwatch = Stopwatch()..start();
      try {
        result = await sessionServerRepo.tryGetSessionResult(
          sessionId: requestId,
          waitMs: resultWaitMs,
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
            serverNullifierType: readyResult.nullifierType,
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
            );

            if (!_isPollingActiveFor(requestId)) {
              return;
            }

            if (status.isTerminal) {
              final normalized = status.status.trim().toLowerCase();
              final phase = normalized == 'expired'
                  ? ZkPassportPipelinePhase.timedOut
                  : ZkPassportPipelinePhase.failed;
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
    int? serverNullifierType,
    int? fetchOuterProofMs,
  }) async {
    _inFlight = true;
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

      final rpc = RustBackendService.instance.rpc;
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

      String? normalizeServerNullifier(String? raw) {
        if (raw == null) return null;
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return null;
        final normalized = trimmed.startsWith('0x') ? trimmed : '0x$trimmed';
        return normalized.toLowerCase();
      }

      final verifierNullifierHex = _deriveNullifierHex(
        verifyOuter.publicInputsHex,
        facematchStrict: facematchStrict,
      );
      final normalizedServerNullifierHex =
          normalizeServerNullifier(serverNullifierHex);

      if (verifierNullifierHex == null || verifierNullifierHex.trim().isEmpty) {
        await _finalizeRuntimeSession(
          requestId: requestId,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message:
              'Outer proof verified, but no public inputs were returned; cannot derive nullifier.',
          fetchOuterProofMs: fetchOuterProofMs,
          verifyOuterMs: verifyOuterMs,
          outerPublicInputsHex: outerPublicInputsHex,
        );
        return;
      }

      String? nullifierMismatchWarning;
      if (normalizedServerNullifierHex != null &&
          normalizedServerNullifierHex != verifierNullifierHex) {
        _log.error(
          'Outer nullifier mismatch between session server and verifier (using verifier-derived value)',
          context: {
            'requestId': requestId,
            'serverNullifierHex': normalizedServerNullifierHex,
            'serverNullifierType': serverNullifierType,
            'verifierNullifierHex': verifierNullifierHex,
            'publicInputsLen': verifyOuter.publicInputsHex?.length,
          },
        );
        nullifierMismatchWarning =
            'Warning: bridge nullifier mismatch.\nServer: $normalizedServerNullifierHex\nVerifier: $verifierNullifierHex';
      }

      final derivedNullifierHex = verifierNullifierHex;

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

      await _ref
          .read(zkPassportFlowControllerProvider)
          .storeSuccessfulRegistration(
            nullifierHex: derivedNullifierHex,
            facematchVerified: _runtimeSession?.facematchStrict,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
          );

      // Non-blocking: notify backend of completion.
      unawaited(_attemptBackendCompletion(
        sessionId: requestId,
        nullifierHex: derivedNullifierHex,
      ));

      const baseMessage = 'zkPassport proof accepted and wrapped successfully.';
      final message = nullifierMismatchWarning != null
          ? '$baseMessage\n\n$nullifierMismatchWarning'
          : baseMessage;
      await _finalizeRuntimeSession(
        requestId: requestId,
        phase: ZkPassportPipelinePhase.success,
        status: ZkPassportPipelineStatus.success,
        message: message,
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

  String? _deriveNullifierHex(
    List<String>? publicInputsHex, {
    required bool facematchStrict,
  }) {
    // Demo: surface a stable identifier to the user after a successful run.
    //
    // zkPassport's packaged utility reports 8 semantic public inputs for
    // `outer_count_4` and 9 for `outer_count_5`, with the final two semantic fields being
    // `nullifier_type` and `scoped_nullifier`.
    //
    // `zkpassportVerifyOuter` returns the full recursive verifier public input
    // list, so recursive/default-IO fields appear after the semantic zkPassport
    // slice. Reading `inputs.last` therefore picks the wrong field; we want the
    // final element of the semantic zkPassport prefix selected by the explicit
    // request mode that produced this proof.
    final inputs = publicInputsHex;
    if (inputs == null || inputs.isEmpty) {
      return null;
    }
    final semanticInputCount = facematchStrict
        ? _zkPassportOuterCount5SemanticPublicInputCount
        : _zkPassportOuterCount4SemanticPublicInputCount;
    final scopedNullifierIndex = semanticInputCount - 1;
    if (inputs.length <= scopedNullifierIndex) {
      return null;
    }
    final raw = inputs[scopedNullifierIndex].trim();
    if (raw.isEmpty) {
      return null;
    }
    final normalized = raw.startsWith('0x') ? raw : '0x$raw';
    return normalized.toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // Backend completion
  // ---------------------------------------------------------------------------

  Future<void> _attemptBackendCompletion({
    required String sessionId,
    required String? nullifierHex,
  }) async {
    if (AppConfig.viewOnly) {
      _log.info(
        'Skipping zkPassport backend completion in view-only mode',
        context: {'sessionId': sessionId},
      );
      final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
      await repo.clearPendingCompletion();
      return;
    }

    final participantId = await _ref.read(participantIdProvider.future);
    final challengeId = _ref.read(zkIdentityChallengeIdProvider);
    if (participantId == null || challengeId == null || nullifierHex == null) {
      _log.warn('Skipping backend completion: missing data', context: {
        'participantId': participantId,
        'challengeId': challengeId,
        'nullifierHex': nullifierHex != null,
      });
      return;
    }

    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) return;

    try {
      final api = _ref.read(leaderboardApiServiceProvider);
      final ok = await api.completeZkPassport(
        participantId: participantId,
        challengeId: challengeId,
        walletAddress: active.address,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
      );

      if (ok) {
        _log.info('Backend completion succeeded');
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        await repo.clearPendingCompletion();
        // Silently refresh leaderboard so the challenge shows as completed.
        unawaited(refreshAllLeaderboardData(_ref));
      }
    } catch (e, st) {
      _log.warn('Backend completion failed, storing for retry', context: {
        'error': e.toString(),
      });
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');

      // Persist for cold-start retry using already-resolved values.
      try {
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        await repo.storePendingCompletion(
          participantId: participantId,
          challengeId: challengeId,
          walletAddress: active.address,
          sessionId: sessionId,
          nullifierHex: nullifierHex,
        );
      } catch (_) {
        // Best-effort.
      }
    }
  }

  /// Retries any stored pending completion. Called on cold start.
  Future<void> _retryPendingCompletion() async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    try {
      if (AppConfig.viewOnly) {
        await repo.clearPendingCompletion();
        _log.info('Cleared pending zkPassport completion in view-only mode');
        return;
      }

      final pending = await repo.getPendingCompletion();
      if (pending == null) return;

      // Validate types before casting — corrupt data should be cleared, not
      // retried forever.
      final participantId = pending['participant_id'];
      final challengeId = pending['challenge_id'];
      final walletAddress = pending['wallet_address'];
      final sessionId = pending['session_id'];
      final nullifierHex = pending['nullifier_hex'];
      if (participantId is! int ||
          challengeId is! int ||
          walletAddress is! String ||
          sessionId is! String ||
          nullifierHex is! String) {
        _log.warn('Clearing corrupt pending completion data');
        await repo.clearPendingCompletion();
        return;
      }

      final api = _ref.read(leaderboardApiServiceProvider);
      final ok = await api.completeZkPassport(
        participantId: participantId,
        challengeId: challengeId,
        walletAddress: walletAddress,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
      );

      if (ok) {
        _log.info('Pending completion retry succeeded');
        await repo.clearPendingCompletion();
        unawaited(refreshAllLeaderboardData(_ref));
      }
    } catch (e) {
      _log.warn('Pending completion retry failed: $e');
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
}
