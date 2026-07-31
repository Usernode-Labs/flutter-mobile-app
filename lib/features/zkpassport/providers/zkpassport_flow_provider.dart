import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/categorized_challenges_provider.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
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
  /// The exact network, account, participant, and challenge still own it.
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
    required this.scope,
    required this.sessionId,
    required this.nullifierHex,
    required this.requestVersion,
    required this.authority,
  });

  final ZkIdentityScope scope;
  final String sessionId;
  final String nullifierHex;
  final ZkPassportRequestVersion requestVersion;
  final AuthenticatedUserLease authority;

  int get challengeId => scope.challengeId;
  String get walletAddress => scope.address;
}

ZkIdentityScope? _captureCurrentZkIdentityScope(Ref ref) {
  final identity = IdentitySnapshots.current;
  final participantId = identity.participantId;
  final accountId = identity.accountId;
  final address = identity.address;
  final challengeId = ref.read(zkIdentityChallengeIdProvider);
  if (identity.phase != IdentityPhase.ready ||
      participantId == null ||
      accountId == null ||
      accountId.trim().isEmpty ||
      address == null ||
      address.trim().isEmpty ||
      challengeId == null) {
    return null;
  }
  return ZkIdentityScope(
    network: NetworkPrefs.currentNetwork,
    bucket: identity.bucket,
    participantId: participantId,
    accountId: accountId,
    address: address,
    challengeId: challengeId,
  );
}

AccountStorageScope _accountScopeFor(ZkIdentityScope scope) =>
    AccountStorageScope(
      network: scope.network,
      bucket: scope.bucket,
      accountId: scope.accountId,
      address: scope.address,
    );

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
  final identity = ref.watch(identityProvider);
  final scope = IdentityLease.capture(identity).accountScope;
  if (scope == null) return ZkPassportSettings.defaults;
  return repo.load(scope: scope);
});

final zkPassportIsRegisteredProvider = FutureProvider<bool>((ref) async {
  return (await ref.watch(zkPassportRegistrationProvider.future)).registered;
});

final zkPassportRegistrationProvider =
    FutureProvider<ZkPassportLocalRegistration>((ref) async {
  final repo = ref.watch(zkPassportRegistrationRepositoryProvider);
  final identity = ref.watch(zkPassportCurrentIdentityProvider);
  final scope = identity.allowsSigning
      ? IdentityLease.capture(identity).accountScope
      : null;
  if (scope == null) return ZkPassportLocalRegistration.unregistered();
  return repo.getRegistrationForAccount(scope: scope);
});

final zkPassportLaunchServiceProvider =
    Provider<ZkPassportLaunchService>((ref) {
  return ZkPassportLaunchService();
});

final zkPassportFlowControllerProvider =
    Provider<ZkPassportFlowController>((ref) {
  return ZkPassportFlowController(ref);
});

/// Reactive identity seam for detaching runtime state as soon as ownership
/// changes. Tests can override this without constructing a SessionController.
final zkPassportCurrentIdentityProvider = Provider<Identity>((ref) {
  return ref.watch(identityProvider);
});

final zkPassportPipelineProvider = StateNotifierProvider<
    ZkPassportPipelineController, ZkPassportPipelineState>((ref) {
  final controller = ZkPassportPipelineController(ref);
  ref.listen<Identity>(zkPassportCurrentIdentityProvider, (previous, next) {
    if (previous?.sameScopeAs(next) == true) return;
    unawaited(controller.onScopeMayBeReady());
  });
  // A cold-start outbox retry can run before the async challenges list has
  // resolved. Retry again when the authoritative ZK challenge becomes
  // available; the controller coalesces duplicate triggers.
  ref.listen<int?>(
    zkIdentityChallengeIdProvider,
    (previous, next) {
      if (next == null || next == previous) return;
      unawaited(controller.onScopeMayBeReady());
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
  Future<ZkPassportLaunchResult>? _launchInFlight;

  Future<ZkPassportLaunchResult> startRegistrationNonceZero() {
    final inFlight = _launchInFlight;
    if (inFlight != null) return inFlight;

    late final Future<ZkPassportLaunchResult> launch;
    launch = _startServerOwnedRegistration().whenComplete(() {
      if (identical(_launchInFlight, launch)) _launchInFlight = null;
    });
    // Reserve the launch before its first suspension point. Two rapid taps
    // therefore share one server session instead of both observing `idle`.
    _launchInFlight = launch;
    return launch;
  }

  Future<ZkPassportLaunchResult> _startServerOwnedRegistration() async {
    if (AppConfig.viewOnly) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'zkPassport session creation is disabled in view-only mode.',
      );
    }

    final pipelineController = _ref.read(zkPassportPipelineProvider.notifier);
    // Cold restoration is asynchronous while the provider's initial state is
    // synchronously `idle`. Never inspect or replace that state until the
    // durable runtime row has been loaded.
    await pipelineController.prepareForLaunch();
    final pipeline = _ref.read(zkPassportPipelineProvider);
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
        requestKey: pipelineController.activeRequestKey,
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

    final launchIdentity = IdentitySnapshots.current;
    final launchScope = _captureCurrentZkIdentityScope(_ref);
    if (launchScope == null) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'Your account or zkPassport challenge is still loading.',
      );
    }
    final launchAuthority = IdentityLease.capture(
      launchIdentity,
      network: launchScope.network,
    );

    bool launchAuthorityIsCurrent() =>
        launchAuthority.isCurrent &&
        _captureCurrentZkIdentityScope(_ref) == launchScope;

    final pendingCompletion = await _ref
        .read(zkPassportRegistrationRepositoryProvider)
        .getPendingCompletion(scope: launchScope);
    if (!launchAuthorityIsCurrent()) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'The active account changed. Please start again.',
      );
    }
    if (pendingCompletion != null) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'A previous zkPassport verification is still being '
            'submitted. Please wait and try again.',
      );
    }

    final accounts =
        await AccountsRepository.create(network: launchScope.network);
    final active = await accounts.getActive();
    if (!launchAuthorityIsCurrent()) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'The active account changed. Please start again.',
      );
    }
    if (active == null ||
        active.id != launchScope.accountId ||
        active.address != launchScope.address) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'The active account is not ready.',
      );
    }
    final userPublicKey = active.publicKey;

    const chainId = ZkPassportRequestPolicy.boundChainId;
    final settingsRepo = _ref.read(zkPassportSettingsRepositoryProvider);
    final settings = await settingsRepo.load(
      scope: _accountScopeFor(launchScope),
    );
    if (!launchAuthorityIsCurrent()) {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'The active account changed. Please start again.',
      );
    }
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
        walletAddress: launchScope.address,
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
        if (!launchAuthorityIsCurrent()) {
          return const ZkPassportLaunchResult(
            started: false,
            requestId: null,
            message: 'The active account changed. Please start again.',
          );
        }
        started = await sessionServerRepo.startSession(
          walletAddress: launchScope.address,
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
      if (!launchAuthorityIsCurrent()) {
        return const ZkPassportLaunchResult(
          started: false,
          requestId: null,
          message: 'The active account changed. Please start again.',
        );
      }
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

    late final ZkRequestKey requestKey;
    try {
      requestKey = await pipelineController.markLaunchStarted(
        requestId: requestId,
        facematchStrict: facematchStrict,
        userPublicKey: userPublicKey,
        launchScope: launchScope,
        launchAuthority: launchAuthority,
      );
    } on StaleIdentityLeaseException {
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'The active account changed. Please start again.',
      );
    } catch (e, st) {
      _log.error(
        'Failed to persist zkPassport launch state',
        error: e,
        stackTrace: st,
      );
      return const ZkPassportLaunchResult(
        started: false,
        requestId: null,
        message: 'Unable to save zkPassport session state. Please retry.',
      );
    }

    final launchService = _ref.read(zkPassportLaunchServiceProvider);
    if (!launchAuthorityIsCurrent()) {
      return ZkPassportLaunchResult(
        started: false,
        requestId: requestId,
        message: 'The active account changed. Please start again.',
      );
    }
    final launched = await launchService.launchOrOpenStore(launchUri);
    if (!launched) {
      await pipelineController.markLaunchFailed(
        requestKey: requestKey,
        message: 'Unable to open zkPassport or app store listing.',
      );
      return ZkPassportLaunchResult(
        started: false,
        requestId: requestId,
        message: 'Unable to open zkPassport or app store listing.',
      );
    }

    final launchStillOwned = await pipelineController.markLaunchDispatched(
      requestKey: requestKey,
    );
    if (!launchStillOwned) {
      return ZkPassportLaunchResult(
        started: false,
        requestId: requestId,
        message: 'The active account changed. Please start again.',
      );
    }
    pipelineController.startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );

    return ZkPassportLaunchResult(
      started: true,
      requestId: requestId,
      message: 'zkPassport launch requested.',
    );
  }

  Future<void> setRegistered(bool value) async {
    final identity = IdentitySnapshots.current;
    final scope = identity.allowsSigning
        ? IdentityLease.capture(identity).accountScope
        : null;
    if (scope == null) return;
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeRegistrationForAccount(
      scope: scope,
      registered: value,
      nullifierHex: null,
    );
    _ref.invalidate(zkPassportIsRegisteredProvider);
    _ref.invalidate(zkPassportRegistrationProvider);
  }

  Future<void> storeSuccessfulRegistrationForScope({
    required ZkIdentityScope scope,
    required String? nullifierHex,
    required ZkPassportRequestVersion requestVersion,
    bool? facematchVerified,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
  }) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.storeRegistrationForAccount(
      scope: _accountScopeFor(scope),
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
    final identity = IdentitySnapshots.current;
    final scope = identity.allowsSigning
        ? IdentityLease.capture(identity).accountScope
        : null;
    if (scope == null) return;
    await _clearRegistration(scope);
  }

  Future<void> _clearRegistration(AccountStorageScope scope) async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    await repo.clearRegistrationForAccount(scope: scope);
    _ref.invalidate(zkPassportIsRegisteredProvider);
    _ref.invalidate(zkPassportRegistrationProvider);
  }

  /// Resets all challenge-related state: ZK identity flow, pipeline session,
  /// registration, and cached challenge data. Called from settings.
  Future<bool> resetChallengeData() async {
    final identity = IdentitySnapshots.current;
    final scope = identity.allowsSigning
        ? IdentityLease.capture(identity).accountScope
        : null;
    if (scope == null) return false;
    final discarded = await _ref
        .read(zkPassportPipelineProvider.notifier)
        .discardPendingSession(reason: 'Reset');
    if (!discarded) return false;

    _ref.read(zkIdentityStepControllerProvider.notifier).reset();
    await _clearRegistration(scope);
    _ref.invalidate(challengesProvider);
    _ref.invalidate(breakdownProvider);
    _ref.invalidate(categorizedChallengesProvider);
    return true;
  }

  Future<void> setFacematchStrict(bool value) async {
    final identity = IdentitySnapshots.current;
    final lease = IdentityLease.capture(identity);
    final scope = lease.accountScope;
    if (scope == null) return;
    final repo = _ref.read(zkPassportSettingsRepositoryProvider);
    await repo.setFacematchStrict(scope: scope, value: value);
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
  IdentityLease? _pendingCompletionRetryAuthority;
  int? _pendingCompletionRetryChallengeId;
  ZkRequestKey? _proofInFlightKey;
  Timer? _serverPollingTimer;
  bool _serverPollingInFlight = false;
  final Set<ZkRequestKey> _serverPollingAttemptKeys = {};
  final Set<ZkRequestKey> _consumedResultResumeKeys = {};
  ZkRequestKey? _serverPollingKey;
  int _lastServerStatusFetchAtMs = 0;
  int _serverPollingBurstUntilAtMs = 0;
  ZkPassportRuntimeSession? _runtimeSession;

  bool get _inFlight => _proofInFlightKey != null;
  bool get isProofProcessing => _inFlight;
  ZkRequestKey? get activeRequestKey => _runtimeSession?.requestVersion?.key;

  Future<void> prepareForLaunch() async {
    await _startupResetFuture;
    await _restoreRuntimeSessionForCurrentScope();
  }

  /// How the CURRENT identity relates to the identity that launched
  /// [runtime] (see [ZkPassportRuntimeSession.launchScope]).
  ///
  /// The complete durable scope is compared across process restarts. Epoch is
  /// intentionally not compared here because it is process-local. Sessions
  /// persisted by older app versions without a complete scope fail closed.
  _LaunchIdentityCheck _checkLaunchIdentity(ZkPassportRuntimeSession runtime) {
    final launchScope = runtime.launchScope;
    if (launchScope == null) return _LaunchIdentityCheck.mismatch;
    final current = IdentitySnapshots.current;
    if (current.phase == IdentityPhase.unknown ||
        current.phase == IdentityPhase.transitioning ||
        current.phase == IdentityPhase.reconciling) {
      // Boot restore / reconcile still in progress: WHO the app is hasn't
      // been established, so neither acting nor discarding is safe yet.
      return _LaunchIdentityCheck.defer;
    }
    if (current.phase != IdentityPhase.ready ||
        NetworkPrefs.currentNetwork != launchScope.network ||
        current.bucket != launchScope.bucket ||
        current.participantId != launchScope.participantId ||
        current.accountId != launchScope.accountId ||
        current.address != launchScope.address) {
      return _LaunchIdentityCheck.mismatch;
    }
    final challengeId = _ref.read(zkIdentityChallengeIdProvider);
    if (challengeId == null) return _LaunchIdentityCheck.defer;
    return challengeId == launchScope.challengeId
        ? _LaunchIdentityCheck.match
        : _LaunchIdentityCheck.mismatch;
  }

  bool _isRequestOwnedAndCurrent(ZkRequestKey requestKey) {
    final runtime = _runtimeSession;
    return runtime != null &&
        runtime.requestVersion?.key == requestKey &&
        _checkLaunchIdentity(runtime) == _LaunchIdentityCheck.match;
  }

  void _detachRequestIfForeign(ZkRequestKey requestKey) {
    final runtime = _runtimeSession;
    if (runtime?.requestVersion?.key != requestKey ||
        runtime == null ||
        _checkLaunchIdentity(runtime) == _LaunchIdentityCheck.match) {
      return;
    }
    if (_serverPollingKey == requestKey) _stopServerPollingWorker();
    _runtimeSession = null;
    state = ZkPassportPipelineState.idle();
  }

  bool _isPollingActiveFor(ZkRequestKey requestKey) {
    if (!_serverPollingInFlight) {
      return false;
    }
    if (_serverPollingKey != requestKey) {
      return false;
    }
    final runtime = _runtimeSession;
    if (runtime == null ||
        runtime.requestVersion?.key != requestKey ||
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
      await _restoreRuntimeSessionForCurrentScope();
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

  Future<void> _restoreRuntimeSessionForCurrentScope() async {
    final scope = _captureCurrentZkIdentityScope(_ref);
    if (scope == null) {
      if (_runtimeSession != null) {
        _stopServerPollingWorker();
        _runtimeSession = null;
        state = ZkPassportPipelineState.idle();
      }
      return;
    }
    final active = _runtimeSession;
    if (active?.launchScope == scope) {
      if (!active!.isTerminal && active.consumedResult != null && !_inFlight) {
        unawaited(_resumeConsumedResult(active));
      }
      return;
    }

    _stopServerPollingWorker();
    _runtimeSession = null;
    state = ZkPassportPipelineState.idle();
    final persisted = await _runtimeRepo.load(scope: scope);
    if (_captureCurrentZkIdentityScope(_ref) != scope || persisted == null) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timeoutAtMs =
        persisted.createdAtMs + (_runtimeSessionTimeoutSeconds() * 1000);
    if (persisted.isTerminal ||
        (persisted.consumedResult == null && nowMs >= timeoutAtMs)) {
      final persistedKey = persisted.requestVersion?.key;
      if (persistedKey == null) {
        await _runtimeRepo.clear(scope: scope);
      } else {
        await _runtimeRepo.clearIfCurrent(
          scope: persisted.launchScope ?? scope,
          requestKey: persistedKey,
        );
      }
      return;
    }
    if (persisted.launchScope != scope) {
      final persistedKey = persisted.requestVersion?.key;
      if (persistedKey != null && persisted.launchScope != null) {
        await _runtimeRepo.clearIfCurrent(
          scope: persisted.launchScope!,
          requestKey: persistedKey,
        );
      }
      return;
    }
    _runtimeSession = persisted;
    final requestKey = persisted.requestVersion?.key;
    if (requestKey == null) {
      await _runtimeRepo.clear(scope: scope);
      _runtimeSession = null;
      return;
    }
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.resuming,
      message: 'Recovering zkPassport session...',
      requestKey: requestKey,
      resumeAttemptCount: persisted.resumeAttemptCount,
    );
    if (persisted.consumedResult != null) {
      unawaited(_resumeConsumedResult(persisted));
      return;
    }
    startServerResultPolling(requestKey: requestKey, immediate: true);
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
    await _restoreRuntimeSessionForCurrentScope();
    await _retryPendingCompletionGuarded();
  }

  Future<void> onScopeMayBeReady() => retryPendingCompletion();

  /// Coalesces retries only when both the exact identity scope and challenge
  /// readiness are unchanged. A ready identity must not join a reconciling
  /// run from the same epoch, and a newly-loaded challenge id must queue a
  /// fresh run behind one that already deferred on a null id.
  Future<void> _retryPendingCompletionGuarded() {
    final identity = IdentitySnapshots.current;
    final authority = IdentityLease.capture(identity);
    final challengeId = _ref.read(zkIdentityChallengeIdProvider);
    final inFlight = _pendingCompletionRetryInFlight;
    if (inFlight != null &&
        _pendingCompletionRetryAuthority?.matches(
              identity,
              currentNetwork: NetworkPrefs.currentNetwork,
            ) ==
            true &&
        _pendingCompletionRetryChallengeId == challengeId) {
      return inFlight;
    }

    late Future<void> run;
    run = _retryAfter(inFlight, authority).whenComplete(() {
      if (identical(_pendingCompletionRetryInFlight, run)) {
        _pendingCompletionRetryInFlight = null;
        _pendingCompletionRetryAuthority = null;
        _pendingCompletionRetryChallengeId = null;
      }
    });
    _pendingCompletionRetryInFlight = run;
    _pendingCompletionRetryAuthority = authority;
    _pendingCompletionRetryChallengeId = challengeId;
    return run;
  }

  Future<void> _retryAfter(
    Future<void>? previous,
    IdentityLease authority,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // The stale run's failure was surfaced to its own caller.
      }
    }
    if (!authority.isCurrent) {
      return; // superseded while waiting
    }
    await _retryPendingCompletion();
  }

  Future<ZkRequestKey> markLaunchStarted({
    required String requestId,
    required bool facematchStrict,
    required String? userPublicKey,
    required ZkIdentityScope launchScope,
    required IdentityLease launchAuthority,
  }) async {
    await _startupResetFuture;
    if (_inFlight) {
      throw StateError('cannot replace an in-flight zkPassport proof');
    }
    final existing = _runtimeSession;
    if (existing != null && !existing.isTerminal) {
      throw StateError(
        'cannot replace an undiscarded zkPassport request generation',
      );
    }
    if (!launchAuthority.isCurrent ||
        _captureCurrentZkIdentityScope(_ref) != launchScope) {
      throw const StaleIdentityLeaseException();
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final requestNonce = _newRequestNonce();
    final session = ZkPassportRuntimeSession(
      requestId: requestId,
      facematchStrict: facematchStrict,
      phase: ZkPassportPipelinePhase.launching,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: requestNonce,
      userPublicKey: userPublicKey,
      launchScope: launchScope,
    );
    final requestKey = session.requestVersion!.key;
    _runtimeSession = session;
    try {
      await _runtimeRepo.save(session);
    } catch (_) {
      // The in-memory assignment reserves this generation while persistence
      // is outstanding. Roll it back on failure so a retry is not wedged by a
      // launch that was never durably established.
      if (_runtimeSession?.requestVersion?.key == requestKey) {
        _runtimeSession = null;
      }
      rethrow;
    }
    if (!_isRequestOwnedAndCurrent(requestKey)) {
      _detachRequestIfForeign(requestKey);
      throw const StaleIdentityLeaseException();
    }
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.launching,
      message: 'Preparing zkPassport launch request...',
      requestKey: requestKey,
      resumeAttemptCount: 0,
    );
    return requestKey;
  }

  Future<void> markLaunchFailed({
    required ZkRequestKey requestKey,
    required String message,
  }) async {
    await _startupResetFuture;
    await _finalizeRuntimeSession(
      requestKey: requestKey,
      phase: ZkPassportPipelinePhase.failed,
      status: ZkPassportPipelineStatus.failure,
      message: message,
    );
  }

  Future<void> reportImmediateFailure({required String message}) async {
    await _startupResetFuture;
    await _finalizeRuntimeSession(
      requestKey: null,
      phase: ZkPassportPipelinePhase.failed,
      status: ZkPassportPipelineStatus.failure,
      message: message,
    );
  }

  Future<bool> markLaunchDispatched({
    required ZkRequestKey requestKey,
  }) async {
    await _startupResetFuture;
    final updated = await _updateRuntimeSession(
      requestKey: requestKey,
      phase: ZkPassportPipelinePhase.waiting,
      resetResumeAttempts: true,
    );
    if (!updated || !_isRequestOwnedAndCurrent(requestKey)) {
      _detachRequestIfForeign(requestKey);
      return false;
    }
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.waiting,
      message: 'zkPassport launch requested.',
      requestKey: requestKey,
      resumeAttemptCount: 0,
    );
    return true;
  }

  void startServerResultPolling({
    required ZkRequestKey requestKey,
    bool immediate = false,
  }) {
    final runtime = _runtimeSession;
    if (requestKey.sessionId.trim().isEmpty ||
        !_isRequestOwnedAndCurrent(requestKey) ||
        runtime?.requestVersion?.key != requestKey) {
      return;
    }
    if (runtime!.consumedResult != null) {
      _stopServerPollingWorker();
      unawaited(_resumeConsumedResult(runtime));
      return;
    }
    _serverPollingKey = requestKey;
    _serverPollingInFlight = true;
    if (immediate) {
      _serverPollingBurstUntilAtMs = DateTime.now().millisecondsSinceEpoch +
          _serverStatusBurstWindow.inMilliseconds;
    }
    _scheduleServerPollingAttempt(
      requestKey: requestKey,
      immediate: immediate,
    );
  }

  /// Returns false when proof verification has reached its non-cancellable
  /// in-flight section. Callers must leave their UI/state intact in that case.
  Future<bool> discardPendingSession({
    ZkRequestKey? requestKey,
    String? requestId,
    String? reason,
  }) async {
    await _startupResetFuture;
    if (_inFlight) {
      _log.warn('Refusing to discard a zkPassport session while its proof '
          'pipeline is still running');
      return false;
    }
    final runtime = _runtimeSession;
    if (requestKey != null && runtime?.requestVersion?.key != requestKey) {
      _log.warn(
        'Refusing to discard a replacement zkPassport request generation',
        context: {
          'expectedRequestId': requestKey.sessionId,
          'activeRequestId': runtime?.requestId,
        },
      );
      return false;
    }
    final expectedRequestId = requestId?.trim();
    if (expectedRequestId != null &&
        expectedRequestId.isNotEmpty &&
        runtime?.requestId.trim() != expectedRequestId) {
      _log.warn(
        'Refusing to discard a different zkPassport request',
        context: {
          'expectedRequestId': expectedRequestId,
          'activeRequestId': runtime?.requestId,
        },
      );
      return false;
    }
    _stopServerPollingWorker();
    final scope = runtime?.launchScope;
    var clearedCurrentGeneration = true;
    if (scope != null &&
        _checkLaunchIdentity(runtime!) == _LaunchIdentityCheck.match) {
      final runtimeKey = runtime.requestVersion?.key;
      if (runtimeKey == null) {
        await _runtimeRepo.clear(scope: scope);
      } else {
        clearedCurrentGeneration = await _runtimeRepo.clearIfCurrent(
          scope: scope,
          requestKey: runtimeKey,
        );
      }
    }
    _runtimeSession = null;
    _setState(
      status: ZkPassportPipelineStatus.idle,
      phase: ZkPassportPipelinePhase.idle,
      message: reason ?? '',
      requestKey: null,
      resumeAttemptCount: 0,
    );
    return clearedCurrentGeneration;
  }

  Future<bool> _updateRuntimeSession({
    required ZkRequestKey requestKey,
    required ZkPassportPipelinePhase phase,
    int? resumeAttemptCount,
    bool resetResumeAttempts = false,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final current = _runtimeSession;
    if (current == null || current.requestVersion?.key != requestKey) {
      return false;
    }
    if (_checkLaunchIdentity(current) != _LaunchIdentityCheck.match) {
      _detachRequestIfForeign(requestKey);
      return false;
    }
    final next = ZkPassportRuntimeSession(
      requestId: current.requestId,
      facematchStrict: current.facematchStrict,
      phase: phase,
      createdAtMs: current.createdAtMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: resetResumeAttempts
          ? 0
          : (resumeAttemptCount ?? current.resumeAttemptCount),
      requestNonce: current.requestNonce,
      userPublicKey: current.userPublicKey,
      launchScope: current.launchScope,
      consumedResult: current.consumedResult,
    );
    _runtimeSession = next;
    final saved = await _runtimeRepo.saveIfCurrent(next);
    if (!saved) {
      if (_runtimeSession?.requestVersion?.key == requestKey) {
        _runtimeSession = null;
        state = ZkPassportPipelineState.idle();
      }
      return false;
    }
    if (!_isRequestOwnedAndCurrent(requestKey)) {
      _detachRequestIfForeign(requestKey);
      return false;
    }
    return true;
  }

  Future<void> _finalizeRuntimeSession({
    required ZkRequestKey? requestKey,
    required ZkPassportPipelinePhase phase,
    required ZkPassportPipelineStatus status,
    required String message,
    int? fetchOuterProofMs,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    List<String>? outerPublicInputsHex,
  }) async {
    final normalizedRequestId = requestKey?.sessionId.trim();
    final current = _runtimeSession;
    if (requestKey != null && current?.requestVersion?.key != requestKey) {
      _log.warn('Ignoring stale zkPassport finalization for '
          '${requestKey.sessionId}');
      return;
    }
    final scope = current?.launchScope;
    if (requestKey != null &&
        current != null &&
        _checkLaunchIdentity(current) != _LaunchIdentityCheck.match) {
      _stopServerPollingWorker();
      _runtimeSession = null;
      state = ZkPassportPipelineState.idle();
      return;
    }
    if (requestKey != null && normalizedRequestId!.isNotEmpty) {
      final updated = await _updateRuntimeSession(
        requestKey: requestKey,
        phase: phase,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      if (!updated) return;
    }
    _stopServerPollingWorker();
    _setState(
      status: status,
      phase: phase,
      message: message,
      requestKey: requestKey,
      fetchOuterProofMs: fetchOuterProofMs,
      verifyOuterMs: verifyOuterMs,
      wrapOuterMs: wrapOuterMs,
      verifyWrappedMs: verifyWrappedMs,
      outerPublicInputsHex: outerPublicInputsHex,
      resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
    );
    if (scope != null) {
      if (requestKey == null) {
        await _runtimeRepo.clear(scope: scope);
      } else {
        await _runtimeRepo.clearIfCurrent(
          scope: scope,
          requestKey: requestKey,
        );
      }
    }
    if (requestKey == null ||
        _runtimeSession?.requestVersion?.key == requestKey) {
      _runtimeSession = null;
    }
  }

  Future<void> recoverPendingSessionOnForeground() async {
    await _startupResetFuture;
    await _restoreRuntimeSessionForCurrentScope();
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
      _stopServerPollingWorker();
      _runtimeSession = null;
      state = ZkPassportPipelineState.idle();
      return;
    }
    final requestKey = runtime.requestVersion?.key;
    if (requestKey == null) return;
    _setState(
      status: ZkPassportPipelineStatus.processing,
      phase: ZkPassportPipelinePhase.resuming,
      message: 'Checking zkPassport session status after foreground...',
      requestKey: requestKey,
      resumeAttemptCount: runtime.resumeAttemptCount,
    );
    if (runtime.consumedResult != null) {
      _stopServerPollingWorker();
      unawaited(_resumeConsumedResult(runtime));
      return;
    }
    startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );
  }

  void _scheduleServerPollingAttempt({
    required ZkRequestKey requestKey,
    bool immediate = false,
  }) {
    if (!_serverPollingInFlight || _serverPollingKey != requestKey) {
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
          requestKey: requestKey,
        ),
      );
    });
  }

  Future<void> _runServerPollingAttempt({
    required ZkRequestKey requestKey,
  }) async {
    if (!_serverPollingInFlight || _serverPollingKey != requestKey) {
      return;
    }
    if (_inFlight) {
      // A replacement request can become current while another generation is
      // still finishing proof work. Keep its worker alive instead of letting
      // the one immediate timer fire and disappear permanently.
      _scheduleServerPollingAttempt(requestKey: requestKey);
      return;
    }
    if (!_serverPollingAttemptKeys.add(requestKey)) {
      return;
    }

    try {
      final runtime = _runtimeSession;
      if (runtime == null ||
          runtime.requestVersion?.key != requestKey ||
          runtime.isTerminal) {
        _stopServerPollingWorker();
        return;
      }
      if (runtime.consumedResult != null) {
        _stopServerPollingWorker();
        unawaited(_resumeConsumedResult(runtime));
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
          _scheduleServerPollingAttempt(requestKey: requestKey);
          return;
        case _LaunchIdentityCheck.mismatch:
          _log.warn(
            'Stopping zkPassport polling: session launched by another '
            'identity',
            context: {'requestId': requestKey.sessionId},
          );
          _stopServerPollingWorker();
          _runtimeSession = null;
          state = ZkPassportPipelineState.idle();
          return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final timeoutAtMs =
          runtime.createdAtMs + (_runtimeSessionTimeoutSeconds() * 1000);
      if (nowMs >= timeoutAtMs) {
        if (!_isPollingActiveFor(requestKey)) {
          return;
        }
        await _finalizeRuntimeSession(
          requestKey: requestKey,
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
        if (!_isPollingActiveFor(requestKey)) {
          return;
        }
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Session server is not configured.',
        );
        return;
      }

      ZkPassportSessionResultResponse? result;
      var resultFetchFailed = false;
      final userPublicKey = await _userPublicKeyForRuntime(runtime);
      if (!_isPollingActiveFor(requestKey) ||
          !_isRequestOwnedAndCurrent(requestKey)) {
        return;
      }
      final resultWaitMs = nowMs < _serverPollingBurstUntilAtMs
          ? _serverStatusBurstPollInterval.inMilliseconds
          : _serverStatusPollInterval.inMilliseconds;
      final fetchStopwatch = Stopwatch()..start();
      try {
        result = await sessionServerRepo.tryGetSessionResult(
          sessionId: requestKey.sessionId,
          waitMs: resultWaitMs,
          userPublicKey: userPublicKey,
        );
      } catch (e, st) {
        resultFetchFailed = true;
        if (e is ZkPassportSessionServerException) {
          if (e.statusCode == 404) {
            if (!_isPollingActiveFor(requestKey)) {
              return;
            }
            await _finalizeRuntimeSession(
              requestKey: requestKey,
              phase: ZkPassportPipelinePhase.failed,
              status: ZkPassportPipelineStatus.failure,
              message:
                  'zkPassport session was not found on server. Start a new request.',
            );
            return;
          }
          if (e.statusCode == 410) {
            if (!_isPollingActiveFor(requestKey)) {
              return;
            }
            await _finalizeRuntimeSession(
              requestKey: requestKey,
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
            'requestId': requestKey.sessionId,
            'error': e.toString(),
            'stackTrace': _truncateMessage(st.toString(), maxChars: 800),
          },
        );
      } finally {
        fetchStopwatch.stop();
      }

      final readyResult = result;
      if (readyResult != null) {
        // `/result` is consumptive: the next read may be 410. Persist the
        // complete response against the stable request generation before any
        // post-response identity/UI check can discard it.
        // Never fetch this consumptive endpoint again once a payload exists,
        // even if the critical local persistence write itself fails.
        if (_serverPollingKey == requestKey) _stopServerPollingWorker();
        final consumedRuntime = await _persistConsumedResult(
          runtime: runtime,
          requestKey: requestKey,
          result: ZkPassportConsumedResult(
            success: readyResult.success,
            outerProofB64Url: readyResult.outerProofB64Url,
            nullifierHex: readyResult.nullifierHex,
            error: readyResult.error,
            fetchOuterProofMs: fetchStopwatch.elapsedMilliseconds,
          ),
        );
        if (consumedRuntime == null) return;
        if (!_isRequestOwnedAndCurrent(requestKey)) return;
        unawaited(_resumeConsumedResult(consumedRuntime));
        return;
      }

      if (!_isPollingActiveFor(requestKey) ||
          !_isRequestOwnedAndCurrent(requestKey)) {
        return;
      }

      var scheduleImmediateRetry = false;

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
              sessionId: requestKey.sessionId,
              userPublicKey: userPublicKey,
            );

            if (!_isPollingActiveFor(requestKey) ||
                !_isRequestOwnedAndCurrent(requestKey)) {
              return;
            }

            final disposition = status.disposition;
            switch (disposition) {
              case ZkPassportSessionDisposition.pending:
                break;
              case ZkPassportSessionDisposition.proofReady:
                // `/status` can observe the final result just after `/result`
                // returned not-ready. Fetch `/result` again immediately.
                scheduleImmediateRetry = true;
                break;
              case ZkPassportSessionDisposition.failed:
                _log.warn(
                  'zkPassport polling reached terminal non-success state',
                  context: {
                    'requestId': requestKey.sessionId,
                    'serverStatus': status.status,
                    'disposition': disposition.name,
                    'finalAvailable': status.finalAvailable,
                    'updatedAtMs': status.updatedAtMs,
                  },
                );
                await _finalizeRuntimeSession(
                  requestKey: requestKey,
                  phase: ZkPassportPipelinePhase.failed,
                  status: ZkPassportPipelineStatus.failure,
                  message: 'zkPassport session completed without a proof.',
                );
                return;
              case ZkPassportSessionDisposition.expired:
                _log.warn(
                  'zkPassport polling reached expired state',
                  context: {
                    'requestId': requestKey.sessionId,
                    'serverStatus': status.status,
                    'disposition': disposition.name,
                    'finalAvailable': status.finalAvailable,
                    'updatedAtMs': status.updatedAtMs,
                  },
                );
                await _finalizeRuntimeSession(
                  requestKey: requestKey,
                  phase: ZkPassportPipelinePhase.timedOut,
                  status: ZkPassportPipelineStatus.failure,
                  message: 'zkPassport session expired before completion.',
                );
                return;
            }
          } catch (statusError, statusSt) {
            if (statusError is ZkPassportSessionServerException &&
                statusError.statusCode == 404) {
              if (!_isPollingActiveFor(requestKey)) {
                return;
              }
              await _finalizeRuntimeSession(
                requestKey: requestKey,
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
                'requestId': requestKey.sessionId,
                'error': statusError.toString(),
                'stackTrace':
                    _truncateMessage(statusSt.toString(), maxChars: 800),
              },
            );
          }
        }
      }

      _scheduleServerPollingAttempt(
        requestKey: requestKey,
        immediate: scheduleImmediateRetry,
      );
    } finally {
      _serverPollingAttemptKeys.remove(requestKey);
    }
  }

  Future<ZkPassportRuntimeSession?> _persistConsumedResult({
    required ZkPassportRuntimeSession runtime,
    required ZkRequestKey requestKey,
    required ZkPassportConsumedResult result,
  }) async {
    if (runtime.requestVersion?.key != requestKey) return null;
    final next = runtime.copyWith(
      phase: ZkPassportPipelinePhase.resuming,
      lastProgressAtMs: DateTime.now().millisecondsSinceEpoch,
      consumedResult: result,
    );
    if (_runtimeSession?.requestVersion?.key == requestKey) {
      // Retain the only copy in memory before touching fallible storage.
      _runtimeSession = next;
    }
    bool saved;
    try {
      saved = await _runtimeRepo.saveIfCurrent(next);
    } catch (firstError, firstStackTrace) {
      _log.warn(
        'Failed to persist consumed zkPassport result; retrying the same '
        'payload without refetching',
        context: {
          'requestId': requestKey.sessionId,
          'error': firstError.toString(),
          'stackTrace':
              _truncateMessage(firstStackTrace.toString(), maxChars: 800),
        },
      );
      try {
        saved = await _runtimeRepo.saveIfCurrent(next);
      } catch (retryError, retryStackTrace) {
        // Keep processing the retained in-memory payload. Later phase/outbox
        // writes get another chance to make it durable; most importantly, the
        // worker never stalls or calls the already-consumed endpoint again.
        _log.error(
          'Consumed zkPassport result remains in memory after persistence '
          'retry failed',
          error: retryError,
          stackTrace: retryStackTrace,
        );
        return next;
      }
    }
    if (!saved) {
      _log.warn(
        'Consumed zkPassport result belongs to a replaced request generation',
        context: {'requestId': requestKey.sessionId},
      );
      return null;
    }
    return next;
  }

  Future<void> _resumeConsumedResult(
    ZkPassportRuntimeSession runtime,
  ) async {
    final requestKey = runtime.requestVersion?.key;
    final consumed = runtime.consumedResult;
    if (requestKey == null ||
        consumed == null ||
        _inFlight ||
        !_consumedResultResumeKeys.add(requestKey)) {
      return;
    }
    try {
      if (_runtimeSession?.requestVersion?.key != requestKey ||
          _checkLaunchIdentity(runtime) != _LaunchIdentityCheck.match) {
        return;
      }

      if (!consumed.hasUsableProof) {
        _log.warn(
          'zkPassport result envelope rejected',
          context: {
            'requestId': requestKey.sessionId,
            'outerProofPresent': consumed.outerProofB64Url != null,
            'nullifierPresent': consumed.nullifierHex != null,
          },
        );
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message:
              consumed.error ?? 'zkPassport session completed without a proof.',
          fetchOuterProofMs: consumed.fetchOuterProofMs,
        );
        return;
      }

      await _runPipeline(
        requestKey,
        consumed.outerProofB64Url!,
        serverNullifierHex: consumed.nullifierHex,
        fetchOuterProofMs: consumed.fetchOuterProofMs,
      );
    } finally {
      _consumedResultResumeKeys.remove(requestKey);
    }
  }

  void _stopServerPollingWorker() {
    _serverPollingTimer?.cancel();
    _serverPollingTimer = null;
    _serverPollingInFlight = false;
    _serverPollingKey = null;
    _serverPollingBurstUntilAtMs = 0;
  }

  void _releaseProofPipeline(ZkRequestKey requestKey) {
    if (_proofInFlightKey != requestKey) return;
    _proofInFlightKey = null;

    final active = _runtimeSession;
    final activeKey = active?.requestVersion?.key;
    if (active != null &&
        activeKey != null &&
        activeKey != requestKey &&
        active.consumedResult != null &&
        _checkLaunchIdentity(active) == _LaunchIdentityCheck.match) {
      unawaited(_resumeConsumedResult(active));
      return;
    }
    if (_serverPollingInFlight && _serverPollingKey != null) {
      _scheduleServerPollingAttempt(
        requestKey: _serverPollingKey!,
        immediate: true,
      );
    }
  }

  Future<void> _runPipeline(
    ZkRequestKey requestKey,
    String outerProofB64Url, {
    String? serverNullifierHex,
    int? fetchOuterProofMs,
  }) async {
    if (_proofInFlightKey != null) return;
    _proofInFlightKey = requestKey;
    final requestId = requestKey.sessionId;
    // Bind this run to the identity that LAUNCHED the session (validated
    // here against the current one), not to whoever happens to be current
    // at result arrival: registration storage and backend completion below
    // are refused if a login / logout / season reconcile switched the
    // identity while proving was in flight — A's proof must never be stored
    // or submitted under B's account.
    final runtimeAtStart = _runtimeSession;
    if (runtimeAtStart == null ||
        runtimeAtStart.requestVersion?.key != requestKey) {
      try {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The zkPassport request generation could not be verified. '
              'Please retry the verification.',
        );
      } finally {
        _releaseProofPipeline(requestKey);
      }
      return;
    }
    final requestVersion = runtimeAtStart.requestVersion;
    if (requestVersion == null) {
      try {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message:
              'This zkPassport request predates exact completion tracking. '
              'Please retry the verification.',
        );
      } finally {
        _releaseProofPipeline(requestKey);
      }
      return;
    }
    if (_checkLaunchIdentity(runtimeAtStart) != _LaunchIdentityCheck.match) {
      try {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'The signed-in identity changed while the proof was being '
              'produced. Please retry the verification.',
        );
      } finally {
        _releaseProofPipeline(requestKey);
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
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Session server returned an empty outer proof payload.',
          fetchOuterProofMs: fetchOuterProofMs,
        );
        return;
      }

      final rpc = await _ensureNodeRpcReadyForPipeline();
      if (!_isRequestOwnedAndCurrent(requestKey)) return;
      if (rpc == null) {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
          phase: ZkPassportPipelinePhase.failed,
          status: ZkPassportPipelineStatus.failure,
          message: 'Node RPC is unavailable; start the node and retry.',
          fetchOuterProofMs: fetchOuterProofMs,
        );
        return;
      }

      final outerProofPrefixedBytes =
          _ensurePrefixedBbHonkProofBlobBytes(outerProof);
      final facematchStrict = runtimeAtStart.facematchStrict;

      final beganOuterVerification = await _updateRuntimeSession(
        requestKey: requestKey,
        phase: ZkPassportPipelinePhase.verifyingOuter,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      if (!beganOuterVerification || !_isRequestOwnedAndCurrent(requestKey)) {
        return;
      }
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.verifyingOuter,
        message: 'Verifying outer proof...',
        requestKey: requestKey,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final verifyOuter = await rpc.zkpassportVerifyOuter(
        outerProof: outerProofPrefixedBytes,
        facematchStrict: facematchStrict,
      );
      if (!_isRequestOwnedAndCurrent(requestKey)) return;
      if (verifyOuter == null) {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
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
          requestKey: requestKey,
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
          requestKey: requestKey,
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

      final beganWrapping = await _updateRuntimeSession(
        requestKey: requestKey,
        phase: ZkPassportPipelinePhase.wrapping,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      if (!beganWrapping || !_isRequestOwnedAndCurrent(requestKey)) return;
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.wrapping,
        message: 'Wrapping proof into mega-compatible shape...',
        requestKey: requestKey,
        verifyOuterMs: verifyOuterMs,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final wrapOuter = await rpc.zkpassportWrapOuter(
        outerProof: outerProofPrefixedBytes,
        facematchStrict: facematchStrict,
      );
      if (!_isRequestOwnedAndCurrent(requestKey)) return;
      if (wrapOuter == null) {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
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
          requestKey: requestKey,
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

      final beganWrappedVerification = await _updateRuntimeSession(
        requestKey: requestKey,
        phase: ZkPassportPipelinePhase.verifyingWrapped,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      if (!beganWrappedVerification || !_isRequestOwnedAndCurrent(requestKey)) {
        return;
      }
      _setState(
        status: ZkPassportPipelineStatus.processing,
        phase: ZkPassportPipelinePhase.verifyingWrapped,
        message: 'Verifying wrapped mega proof...',
        requestKey: requestKey,
        verifyOuterMs: verifyOuterMs,
        wrapOuterMs: wrapOuterMs,
        resumeAttemptCount: _runtimeSession?.resumeAttemptCount,
      );
      final verifyWrapped = await rpc.zkpassportVerifyWrapped(
        wrappedProof: _decodeB64UrlToBytes(wrappedProof),
        facematchStrict: facematchStrict,
      );
      if (!_isRequestOwnedAndCurrent(requestKey)) return;
      if (verifyWrapped == null) {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
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
          requestKey: requestKey,
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

      if (!_isRequestOwnedAndCurrent(requestKey)) {
        await _finalizeRuntimeSession(
          requestKey: requestKey,
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
        await flowController.storeSuccessfulRegistrationForScope(
          scope: runtimeAtStart.launchScope!,
          nullifierHex: derivedNullifierHex,
          requestVersion: requestVersion,
          facematchVerified: _runtimeSession?.facematchStrict,
          verifyOuterMs: verifyOuterMs,
          wrapOuterMs: wrapOuterMs,
          verifyWrappedMs: verifyWrappedMs,
        );
      } else {
        completion = await _prepareBackendCompletion(
          scope: runtimeAtStart.launchScope!,
          sessionId: requestId,
          nullifierHex: derivedNullifierHex,
          requestVersion: requestVersion,
        );
        if (completion == null) {
          await _finalizeRuntimeSession(
            requestKey: requestKey,
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
        final preparedCompletion = completion;
        final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
        await persistZkCompletionInOrder(
          persistOutbox: () => repo.storePendingCompletion(
            scope: preparedCompletion.scope,
            sessionId: preparedCompletion.sessionId,
            nullifierHex: preparedCompletion.nullifierHex,
            requestVersion: preparedCompletion.requestVersion,
            facematchVerified: runtimeAtStart.facematchStrict,
            verifyOuterMs: verifyOuterMs,
            wrapOuterMs: wrapOuterMs,
            verifyWrappedMs: verifyWrappedMs,
          ),
          persistRegistration: () =>
              flowController.storeSuccessfulRegistrationForScope(
            scope: preparedCompletion.scope,
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
        requestKey: requestKey,
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
        requestKey: requestKey,
        phase: ZkPassportPipelinePhase.failed,
        status: ZkPassportPipelineStatus.failure,
        message: 'zkPassport pipeline failed: $e',
        fetchOuterProofMs: fetchOuterProofMs,
        outerPublicInputsHex: outerPublicInputsHex,
      );
    } finally {
      _releaseProofPipeline(requestKey);
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
    required ZkIdentityScope scope,
    required String sessionId,
    required String nullifierHex,
    required ZkPassportRequestVersion requestVersion,
  }) async {
    final identity = IdentitySnapshots.current;
    try {
      final authority = AuthenticatedUserLease.capture(identity);
      if (authority == null ||
          !authority.isCurrent ||
          _captureCurrentZkIdentityScope(_ref) != scope ||
          authority.scope.participantId != scope.participantId) {
        _log.warn('Skipping backend completion: identity has no confirmed '
            'account scope');
        return null;
      }

      return _PreparedBackendCompletion(
        scope: scope,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
        requestVersion: requestVersion,
        authority: authority,
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
        completion.authority.isCurrent &&
        _captureCurrentZkIdentityScope(_ref) == completion.scope;
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    try {
      // An unsettled identity (reconciling) must not submit: the token and
      // account pairing is unknown. The row is durable — the identity driver
      // retries it as soon as the identity settles.
      if (!identityStillCurrent()) {
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
            authority: completion.authority,
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
              scope: completion.scope,
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

      // A terminal response belongs to the request and stable scope that were
      // authorized immediately before its POST. An identity switch after the
      // transport began must not make that outcome disappear.
      if (isTerminalZkCompletionRejection(lastError)) {
        await _handleTerminalCompletionRejection(
          lastError!,
          lastStack,
          scope: completion.scope,
          sessionId: completion.sessionId,
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
  /// [scope] pins that event to the owning identity. Authority was checked at
  /// the POST boundary; the resulting stable write remains valid if the UI
  /// identity changes while the request is in flight.
  Future<void> _handleTerminalCompletionRejection(
    Object error,
    StackTrace? stack, {
    required ZkIdentityScope scope,
    required String sessionId,
    ZkPassportRequestVersion? requestVersion,
  }) async {
    _log.warn('Backend permanently rejected zkPassport completion', context: {
      'error': error.toString(),
    });
    void reportRejection() {
      unawaited(
        SentryUtil.captureError(
          error,
          stack ?? StackTrace.current,
          tag: 'zkpassport_completion_rejected',
        ),
      );
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
          scope: scope,
        );
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      } catch (e, st) {
        await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
      }
      reportRejection();
      return;
    }

    // Legacy rows do not carry a request generation and cannot participate in
    // exact outcome matching. Preserve their pre-versioning cleanup behavior.
    var clearedLegacyOutbox = false;
    try {
      final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
      clearedLegacyOutbox = await repo.clearPendingCompletionIfCurrent(
        scope: scope,
        sessionId: sessionId,
      );
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
    }
    if (!clearedLegacyOutbox) {
      _log.warn('Skipping legacy registration rollback because the outbox '
          'slot now contains another request');
      reportRejection();
      return;
    }

    try {
      final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
      await repo.clearRegistrationForAccount(scope: _accountScopeFor(scope));
      _ref.invalidate(zkPassportIsRegisteredProvider);
      _ref.invalidate(zkPassportRegistrationProvider);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'zkpassport_completion');
    }

    unawaited(refreshAllLeaderboardData(_ref));
    reportRejection();
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
  /// - exact authority is checked immediately before the authenticated POST;
  ///   its response is then recorded in the original stable scope even if the
  ///   UI identity changes while the request is in flight.
  Future<void> _retryPendingCompletion() async {
    final repo = _ref.read(zkPassportRegistrationRepositoryProvider);
    final identity = IdentitySnapshots.current;
    final authority = AuthenticatedUserLease.capture(identity);
    final scope = _captureCurrentZkIdentityScope(_ref);
    if (authority == null ||
        scope == null ||
        authority.scope.participantId != scope.participantId) {
      _log.info('Skipping pending-completion retry: identity is not ready');
      return;
    }
    bool identityStillCurrent() =>
        authority.isCurrent && _captureCurrentZkIdentityScope(_ref) == scope;
    ZkPassportRequestVersion? pendingRequestVersion;
    ZkIdentityScope pendingScope = scope;
    String? pendingSessionId;
    try {
      final pending = await repo.getPendingCompletion(scope: scope);
      if (pending == null) return;
      if (!identityStillCurrent()) return;

      final requestVersion = ZkPassportRequestVersion.fromJson(pending);
      pendingRequestVersion = requestVersion;
      final hasVersionFields = pending.containsKey('request_id') ||
          pending.containsKey('request_created_at_ms') ||
          pending.containsKey('request_nonce');

      // Validate types before casting — corrupt data should be cleared, not
      // retried forever.
      final storedScope = ZkIdentityScope.fromJson(pending['scope']);
      final participantId =
          storedScope?.participantId ?? pending['participant_id'];
      final challengeId = storedScope?.challengeId ?? pending['challenge_id'];
      final walletAddress = storedScope?.address ?? pending['wallet_address'];
      final sessionId = pending['session_id'];
      final nullifierHex = pending['nullifier_hex'];
      final accountId = storedScope?.accountId ?? pending['account_id'];
      if (participantId is! int ||
          challengeId is! int ||
          walletAddress is! String ||
          sessionId is! String ||
          nullifierHex is! String ||
          accountId is! String ||
          (hasVersionFields &&
              (requestVersion == null ||
                  requestVersion.requestId != sessionId))) {
        _log.warn('Clearing corrupt pending completion data');
        if (identityStillCurrent() && sessionId is String) {
          await repo.clearPendingCompletionIfCurrent(
            scope: storedScope ?? scope,
            sessionId: sessionId,
          );
        }
        return;
      }
      pendingSessionId = sessionId;

      pendingScope = storedScope ??
          ZkIdentityScope(
            network: scope.network,
            bucket: scope.bucket,
            participantId: participantId,
            accountId: accountId,
            address: walletAddress,
            challengeId: challengeId,
          );
      final payloadNetwork = pending['network'];
      final payloadBucket = pending['bucket'];
      if ((payloadNetwork is String &&
              pendingScope.network != payloadNetwork) ||
          (payloadBucket is String && pendingScope.bucket != payloadBucket) ||
          pendingScope.participantId != participantId ||
          pendingScope.accountId != accountId ||
          pendingScope.address != walletAddress ||
          pendingScope.challengeId != challengeId) {
        _log.warn('Clearing pending completion with inconsistent scope');
        if (identityStillCurrent()) {
          await repo.clearPendingCompletionIfCurrent(
            scope: pendingScope,
            sessionId: sessionId,
          );
        }
        return;
      }

      final sameOwner = pendingScope.network == scope.network &&
          pendingScope.bucket == scope.bucket &&
          pendingScope.participantId == scope.participantId &&
          pendingScope.accountId == scope.accountId &&
          pendingScope.address == scope.address;
      if (!sameOwner) {
        _log.warn('Deferring pending completion owned by another identity');
        return;
      }

      if (AppConfig.viewOnly) {
        if (requestVersion == null) {
          await repo.clearPendingCompletionIfCurrent(
            scope: pendingScope,
            sessionId: sessionId,
          );
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.delivered,
            scope: pendingScope,
          );
          _ref.invalidate(zkPassportIsRegisteredProvider);
          _ref.invalidate(zkPassportRegistrationProvider);
        }
        _log.info('Retired pending zkPassport completion in view-only mode');
        return;
      }

      if (pendingScope.challengeId != scope.challengeId) {
        _log.warn(
          'Clearing pending completion targeting stale challenge_id=$challengeId '
          '(active row is ${scope.challengeId})',
        );
        if (requestVersion == null) {
          await repo.clearPendingCompletionIfCurrent(
            scope: pendingScope,
            sessionId: sessionId,
          );
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.discarded,
            scope: pendingScope,
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
        if (!identityStillCurrent()) return;
        await _ref
            .read(zkPassportFlowControllerProvider)
            .storeSuccessfulRegistrationForScope(
              scope: pendingScope,
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
        authority: authority,
        challengeId: challengeId,
        walletAddress: walletAddress,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
      );

      if (ok) {
        _log.info('Pending completion retry succeeded');
        if (requestVersion == null) {
          await repo.clearPendingCompletionIfCurrent(
            scope: pendingScope,
            sessionId: sessionId,
          );
        } else {
          await repo.recordRequestOutcome(
            version: requestVersion,
            outcome: ZkPassportRequestOutcome.delivered,
            scope: pendingScope,
          );
        }
        _ref.invalidate(zkPassportIsRegisteredProvider);
        _ref.invalidate(zkPassportRegistrationProvider);
        unawaited(refreshAllLeaderboardData(_ref));
      }
    } on LeaderboardApiException catch (e, st) {
      if (isTerminalZkCompletionRejection(e)) {
        await _handleTerminalCompletionRejection(
          e,
          st,
          scope: pendingScope,
          sessionId: pendingSessionId ?? pendingRequestVersion?.requestId ?? '',
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
    ZkRequestKey? requestKey,
    int? fetchOuterProofMs,
    int? verifyOuterMs,
    int? wrapOuterMs,
    int? verifyWrappedMs,
    int? resumeAttemptCount,
    List<String>? outerPublicInputsHex,
  }) {
    if (requestKey != null && !_isRequestOwnedAndCurrent(requestKey)) {
      _detachRequestIfForeign(requestKey);
      return;
    }
    final requestId = requestKey?.sessionId;
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
