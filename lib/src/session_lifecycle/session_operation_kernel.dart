part of 'package:crypto_mobile_app/main.dart';

enum _ScopeState {
  staged,
  open,
  closing,
  revoked,
}

typedef _TopLevelAdmissionGate = Future<void>? Function();

final class _SessionScope {
  _SessionScope(
    this.effects, {
    _TopLevelAdmissionGate? topLevelAdmissionGate,
  })  : _topLevelAdmissionGate = topLevelAdmissionGate,
        _state = _ScopeState.staged;

  _SessionScope.closed()
      : effects = const _ClosedSessionEffectSink(),
        _state = _ScopeState.revoked {
    _drained.complete();
  }

  final _SessionEffectSink effects;
  _TopLevelAdmissionGate? _topLevelAdmissionGate;
  _ScopeState _state;
  int _operations = 0;
  int _children = 0;
  int _effects = 0;
  final Completer<void> _drained = Completer<void>();

  late final SessionOperationRunner runner = _SessionOperationRunner(this);

  void bindTopLevelAdmissionGate(_TopLevelAdmissionGate? gate) {
    _topLevelAdmissionGate = gate;
  }

  void open() {
    if (_state != _ScopeState.staged) {
      throw StateError('A session scope can open only once.');
    }
    _state = _ScopeState.open;
  }

  _SessionOperation admitOperation() {
    if (_state != _ScopeState.open) {
      throw const SessionAdmissionClosedException();
    }
    _operations++;
    return _SessionOperation._(this, _CountedKind.operation);
  }

  _SessionOperation admitChild(_SessionOperation parent) {
    if (parent.isExpired ||
        (_state != _ScopeState.open && _state != _ScopeState.closing)) {
      throw const SessionAdmissionClosedException();
    }
    _children++;
    return _SessionOperation._(this, _CountedKind.child);
  }

  _EffectLease acquireEffect(_SessionOperation operation) {
    if (operation.isExpired) {
      throw const SessionOperationExpiredException();
    }
    if (_state == _ScopeState.staged || _state == _ScopeState.revoked) {
      throw const SessionAdmissionClosedException();
    }
    _effects++;
    return _EffectLease._(this);
  }

  Future<void> closeAndDrain() {
    if (_state == _ScopeState.open) {
      // This write is deliberately synchronous with the caller. No new
      // top-level run can enter after closeAndDrain returns its Future. Work
      // already admitted may still register counted children/effects until
      // its structured callback settles; the drain waits for all of them.
      _state = _ScopeState.closing;
      _completeDrainIfReady();
    }
    return _drained.future;
  }

  void release(_CountedKind kind) {
    switch (kind) {
      case _CountedKind.operation:
        _operations--;
      case _CountedKind.child:
        _children--;
    }
    _completeDrainIfReady();
  }

  void releaseEffect() {
    _effects--;
    _completeDrainIfReady();
  }

  void _completeDrainIfReady() {
    if (_state != _ScopeState.closing ||
        _operations != 0 ||
        _children != 0 ||
        _effects != 0) {
      return;
    }
    _state = _ScopeState.revoked;
    if (!_drained.isCompleted) _drained.complete();
  }
}

enum _CountedKind {
  operation,
  child,
}

final class _SessionOperationRunner implements SessionOperationRunner {
  const _SessionOperationRunner(this._scope);

  final _SessionScope _scope;

  @override
  Future<T> run<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  ) {
    final gate = _scope._topLevelAdmissionGate;
    final barrier = gate?.call();
    if (barrier != null) return _runAfterBarrier(barrier, body);
    final operation = _scope.admitOperation();
    return operation.invoke(body);
  }

  Future<T> _runAfterBarrier<T>(
    Future<void> barrier,
    FutureOr<T> Function(SessionOperation operation) body,
  ) async {
    await barrier;
    final operation = _scope.admitOperation();
    return operation.invoke(body);
  }
}

final class _SessionOperation implements SessionOperation {
  _SessionOperation._(this._scope, this._kind);

  final _SessionScope _scope;
  final _CountedKind _kind;
  var _expired = false;
  var _activeChildren = 0;
  Completer<void>? _childrenDrained;
  Object? _firstChildError;
  StackTrace? _firstChildStackTrace;

  bool get isExpired => _expired;

  Future<T> invoke<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  ) {
    late FutureOr<T> result;
    try {
      // Admission was counted before this synchronous callback invocation.
      result = body(this);
    } catch (error, stackTrace) {
      return _finish(Future<T>.error(error, stackTrace));
    }
    return _finish(Future<T>.value(result));
  }

  @override
  Future<T> runChild<T>(
    FutureOr<T> Function(SessionOperation child) body,
  ) {
    if (_expired) throw const SessionOperationExpiredException();

    // The scope check and count increment happen before the child callback.
    final child = _scope.admitChild(this);
    if (_activeChildren == 0) {
      _childrenDrained = Completer<void>();
    }
    _activeChildren++;
    final future = child.invoke(body);
    final observed = future.then<void>(
      (_) => _childSettled(),
      onError: (Object error, StackTrace stackTrace) {
        _firstChildError ??= error;
        _firstChildStackTrace ??= stackTrace;
        _childSettled();
      },
    );
    // [observed] consumes child failures for the structured join. The original
    // Future still reports the same failure to a caller that explicitly waits.
    unawaited(observed);
    return future;
  }

  Future<T> _runEffect<T>(Future<T> Function(_SessionEffectSink sink) body) {
    final lease = acquireEffect();
    late Future<T> result;
    try {
      result = body(_scope.effects);
    } catch (error, stackTrace) {
      lease.release();
      return Future<T>.error(error, stackTrace);
    }
    return result.whenComplete(lease.release);
  }

  @override
  Future<SessionNodeStatus> readNodeStatus() =>
      _runEffect((sink) => sink.readNodeStatus());

  @override
  Future<SessionWalletSnapshot> readWallet() =>
      _runEffect((sink) => sink.readWallet());

  @override
  Future<SessionTransactionSubmission> submitTransaction({
    required String destinationAddress,
    required BigInt amount,
    required String memo,
  }) =>
      _runEffect(
        (sink) => sink.submitTransaction(
          destinationAddress: destinationAddress,
          amount: amount,
          memo: memo,
        ),
      );

  @override
  Future<SessionMessageSignature> signMessage(String message) =>
      _runEffect((sink) => sink.signMessage(message));

  @override
  Future<perf_types.PerfCatalog> readDeviceBenchmarkCatalog() =>
      _runEffect((sink) => sink.readDeviceBenchmarkCatalog());

  @override
  Future<perf_types.PerfRunHandle> startDeviceBenchmark(
    perf_types.PerfRunProfile profile,
  ) =>
      _runEffect((sink) => sink.startDeviceBenchmark(profile));

  @override
  Future<perf_types.PerfRunStatus?> readDeviceBenchmarkStatus(int runId) =>
      _runEffect((sink) => sink.readDeviceBenchmarkStatus(runId));

  @override
  Future<perf_types.PerfRunReport?> readDeviceBenchmarkResult(int runId) =>
      _runEffect((sink) => sink.readDeviceBenchmarkResult(runId));

  @override
  Future<bool> cancelDeviceBenchmark(int runId) =>
      _runEffect((sink) => sink.cancelDeviceBenchmark(runId));

  @override
  Future<SessionObservabilityRecordResult> recordObservability({
    required SessionObservabilityKind kind,
    required String event,
    String? payloadJson,
  }) =>
      _runEffect(
        (sink) => sink.recordObservability(
          kind: kind,
          event: event,
          payloadJson: payloadJson,
        ),
      );

  @override
  Future<SessionZkPassportVerifyOuterResult> verifyZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) =>
      _runEffect(
        (sink) => sink.verifyZkPassportOuter(
          outerProof: outerProof,
          facematchStrict: facematchStrict,
        ),
      );

  @override
  Future<SessionZkPassportWrapOuterResult> wrapZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) =>
      _runEffect(
        (sink) => sink.wrapZkPassportOuter(
          outerProof: outerProof,
          facematchStrict: facematchStrict,
        ),
      );

  @override
  Future<SessionZkPassportVerifyWrappedResult> verifyZkPassportWrapped({
    required List<int> wrappedProof,
    required bool facematchStrict,
  }) =>
      _runEffect(
        (sink) => sink.verifyZkPassportWrapped(
          wrappedProof: wrappedProof,
          facematchStrict: facematchStrict,
        ),
      );

  @override
  Future<int> resolveLegacyZkPassportChallengeId() =>
      _runEffect((sink) => sink.resolveLegacyZkPassportChallengeId());

  @override
  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) =>
      _runEffect(
        (sink) => sink.completeLegacyZkPassport(
          challengeId: challengeId,
          sessionId: sessionId,
          nullifierHex: nullifierHex,
          completedAt: completedAt,
        ),
      );

  @override
  Future<SessionDelegationSnapshot> readDelegation() =>
      _runEffect((sink) => sink.readDelegation());

  @override
  Future<SessionDelegationSnapshot> setDelegated(bool delegated) =>
      _runEffect((sink) => sink.setDelegated(delegated));

  @override
  Future<SessionSleepSnapshot> readSleep() =>
      _runEffect((sink) => sink.readSleep());

  @override
  Future<SessionSleepSnapshot> setSleepEnabled(bool enabled) =>
      _runEffect((sink) => sink.setSleepEnabled(enabled));

  @override
  Future<SessionSleepSnapshot> setSleeping(bool sleeping) =>
      _runEffect((sink) => sink.setSleeping(sleeping));

  @override
  Future<SessionSocialPushStatus> readSocialPushStatus({
    required String installationId,
  }) =>
      _runEffect(
        (sink) => sink.readSocialPushStatus(installationId: installationId),
      );

  @override
  Future<SessionSocialPushStatus> registerSocialPush(
    SessionSocialPushRegistration request,
  ) =>
      _runEffect((sink) => sink.registerSocialPush(request));

  @override
  Future<SessionSocialPushStatus> unregisterSocialPush(
    SessionSocialPushUnregistration request,
  ) =>
      _runEffect((sink) => sink.unregisterSocialPush(request));

  _EffectLease acquireEffect() {
    if (_expired) throw const SessionOperationExpiredException();
    return _scope.acquireEffect(this);
  }

  Future<T> _finish<T>(Future<T> body) async {
    Object? bodyError;
    StackTrace? bodyStackTrace;
    late T value;
    try {
      value = await body;
    } catch (error, stackTrace) {
      bodyError = error;
      bodyStackTrace = stackTrace;
    }

    final childrenDrained = _childrenDrained;
    if (_activeChildren != 0 && childrenDrained != null) {
      await childrenDrained.future;
    }

    _expired = true;
    _scope.release(_kind);

    if (bodyError != null) {
      Error.throwWithStackTrace(bodyError, bodyStackTrace!);
    }
    final childError = _firstChildError;
    if (childError != null) {
      Error.throwWithStackTrace(childError, _firstChildStackTrace!);
    }
    return value;
  }

  void _childSettled() {
    _activeChildren--;
    if (_activeChildren == 0) {
      final drained = _childrenDrained;
      if (drained != null && !drained.isCompleted) drained.complete();
    }
  }
}

final class _EffectLease {
  _EffectLease._(this._scope);

  final _SessionScope _scope;
  var _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _scope.releaseEffect();
  }
}

abstract interface class _SessionEffectSink {
  Future<SessionNodeStatus> readNodeStatus();

  Future<SessionWalletSnapshot> readWallet();

  Future<SessionTransactionSubmission> submitTransaction({
    required String destinationAddress,
    required BigInt amount,
    required String memo,
  });

  Future<SessionMessageSignature> signMessage(String message);

  Future<perf_types.PerfCatalog> readDeviceBenchmarkCatalog();

  Future<perf_types.PerfRunHandle> startDeviceBenchmark(
    perf_types.PerfRunProfile profile,
  );

  Future<perf_types.PerfRunStatus?> readDeviceBenchmarkStatus(int runId);

  Future<perf_types.PerfRunReport?> readDeviceBenchmarkResult(int runId);

  Future<bool> cancelDeviceBenchmark(int runId);

  Future<SessionObservabilityRecordResult> recordObservability({
    required SessionObservabilityKind kind,
    required String event,
    String? payloadJson,
  });

  Future<SessionZkPassportVerifyOuterResult> verifyZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  });

  Future<SessionZkPassportWrapOuterResult> wrapZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  });

  Future<SessionZkPassportVerifyWrappedResult> verifyZkPassportWrapped({
    required List<int> wrappedProof,
    required bool facematchStrict,
  });

  Future<int> resolveLegacyZkPassportChallengeId();

  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  });

  Future<SessionDelegationSnapshot> readDelegation();

  Future<SessionDelegationSnapshot> setDelegated(bool delegated);

  Future<SessionSleepSnapshot> readSleep();

  Future<SessionSleepSnapshot> setSleepEnabled(bool enabled);

  Future<SessionSleepSnapshot> setSleeping(bool sleeping);

  Future<SessionSocialPushStatus> readSocialPushStatus({
    required String installationId,
  });

  Future<SessionSocialPushStatus> registerSocialPush(
    SessionSocialPushRegistration request,
  );

  Future<SessionSocialPushStatus> unregisterSocialPush(
    SessionSocialPushUnregistration request,
  );
}

final class _ClosedSessionEffectSink implements _SessionEffectSink {
  const _ClosedSessionEffectSink();

  Never _closed() => throw const SessionAdmissionClosedException();

  @override
  Future<SessionNodeStatus> readNodeStatus() => _closed();
  @override
  Future<SessionWalletSnapshot> readWallet() => _closed();
  @override
  Future<SessionTransactionSubmission> submitTransaction({
    required String destinationAddress,
    required BigInt amount,
    required String memo,
  }) =>
      _closed();
  @override
  Future<SessionMessageSignature> signMessage(String message) => _closed();
  @override
  Future<perf_types.PerfCatalog> readDeviceBenchmarkCatalog() => _closed();
  @override
  Future<perf_types.PerfRunHandle> startDeviceBenchmark(
    perf_types.PerfRunProfile profile,
  ) =>
      _closed();
  @override
  Future<perf_types.PerfRunStatus?> readDeviceBenchmarkStatus(int runId) =>
      _closed();
  @override
  Future<perf_types.PerfRunReport?> readDeviceBenchmarkResult(int runId) =>
      _closed();
  @override
  Future<bool> cancelDeviceBenchmark(int runId) => _closed();
  @override
  Future<SessionObservabilityRecordResult> recordObservability({
    required SessionObservabilityKind kind,
    required String event,
    String? payloadJson,
  }) =>
      _closed();
  @override
  Future<SessionZkPassportVerifyOuterResult> verifyZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) =>
      _closed();
  @override
  Future<SessionZkPassportWrapOuterResult> wrapZkPassportOuter({
    required List<int> outerProof,
    required bool facematchStrict,
  }) =>
      _closed();
  @override
  Future<SessionZkPassportVerifyWrappedResult> verifyZkPassportWrapped({
    required List<int> wrappedProof,
    required bool facematchStrict,
  }) =>
      _closed();
  @override
  Future<int> resolveLegacyZkPassportChallengeId() => _closed();
  @override
  Future<SessionZkPassportCompletion> completeLegacyZkPassport({
    required int challengeId,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) =>
      _closed();
  @override
  Future<SessionDelegationSnapshot> readDelegation() => _closed();
  @override
  Future<SessionDelegationSnapshot> setDelegated(bool delegated) => _closed();
  @override
  Future<SessionSleepSnapshot> readSleep() => _closed();
  @override
  Future<SessionSleepSnapshot> setSleepEnabled(bool enabled) => _closed();
  @override
  Future<SessionSleepSnapshot> setSleeping(bool sleeping) => _closed();
  @override
  Future<SessionSocialPushStatus> readSocialPushStatus({
    required String installationId,
  }) =>
      _closed();
  @override
  Future<SessionSocialPushStatus> registerSocialPush(
    SessionSocialPushRegistration request,
  ) =>
      _closed();
  @override
  Future<SessionSocialPushStatus> unregisterSocialPush(
    SessionSocialPushUnregistration request,
  ) =>
      _closed();
}

final class _PublishedSession {
  const _PublishedSession({
    required this.scope,
    required this.featureAccess,
  });

  final _SessionScope scope;
  final SessionFeatureAccess featureAccess;
}

final class _ReadOnlySessionView implements SessionFeatureAccessView {
  _ReadOnlySessionView(SessionFeatureAccess initial) : _current = initial;

  SessionFeatureAccess _current;
  final StreamController<SessionFeatureAccess> _changes =
      StreamController<SessionFeatureAccess>.broadcast(sync: true);

  @override
  SessionFeatureAccess get current => _current;

  @override
  Stream<SessionFeatureAccess> get changes => _changes.stream;

  void publish(SessionFeatureAccess next) {
    // Swap first. A synchronous listener can only observe the new bundle.
    _current = next;
    _changes.add(next);
  }

  void dispose() => _changes.close();
}

/// The private owner of session publication and lifecycle mutation.
///
/// Production bootstrap constructs exactly one of these only after native
/// recovery provides a truthful initial projection. Only the read-only [view]
/// crosses this mounted root.
final class _SessionCompositionRoot {
  _SessionCompositionRoot(
    SessionIdentityProjection initialIdentity, {
    _SessionEffectSink? readyEffects,
  }) {
    final initial = switch (initialIdentity.status) {
      SessionProjectionStatus.signedOut =>
        _createSignedOutSession(initialIdentity),
      SessionProjectionStatus.ready => _createOpenSession(
          initialIdentity,
          readyEffects ?? const _ClosedSessionEffectSink(),
        ),
    };
    _published = initial;
    _view = _ReadOnlySessionView(initial.featureAccess);
  }

  late _PublishedSession _published;
  late final _ReadOnlySessionView _view;
  _TopLevelAdmissionGate? _topLevelAdmissionGate;
  var _logoutInFlight = false;
  Completer<void>? _logoutSettled;
  var _disposed = false;

  SessionFeatureAccessView get view => _view;

  void bindTopLevelAdmissionGate(_TopLevelAdmissionGate gate) {
    _topLevelAdmissionGate = gate;
    _published.scope.bindTopLevelAdmissionGate(gate);
  }

  Future<void> logout(SessionIdentityProjection signedOut) {
    if (signedOut.status != SessionProjectionStatus.signedOut) {
      throw ArgumentError.value(
        signedOut.status,
        'signedOut',
        'Logout requires a signed-out projection.',
      );
    }
    return logoutAfterDrain(() => signedOut);
  }

  Future<void> logoutAfterDrain(
    FutureOr<SessionIdentityProjection> Function() commit,
  ) async {
    _checkActive();
    if (_logoutInFlight) {
      throw StateError('Session logout is already in progress.');
    }
    if (_published.featureAccess.identity.status ==
        SessionProjectionStatus.signedOut) {
      return;
    }
    _logoutInFlight = true;
    final settlement = Completer<void>();
    _logoutSettled = settlement;

    // Closing admission is synchronous. Publication remains on A until this
    // exact drain completes; there is no timeout or forced publication.
    final drain = _published.scope.closeAndDrain();
    try {
      await drain;
      final signedOut = await commit();
      if (signedOut.status != SessionProjectionStatus.signedOut) {
        throw ArgumentError.value(
          signedOut.status,
          'commit',
          'Logout commit must return a signed-out projection.',
        );
      }
      if (_disposed) return;
      final publication = _createSignedOutSession(signedOut);
      _published = publication;
      _view.publish(publication.featureAccess);
    } finally {
      _logoutInFlight = false;
      if (identical(_logoutSettled, settlement)) _logoutSettled = null;
      if (!settlement.isCompleted) settlement.complete();
    }
  }

  /// Publishes a native terminal outcome after joining any explicit logout.
  ///
  /// Native definitive absence may win Rust's transition lane while an
  /// explicit logout is already draining. That logout can then fail its Rust
  /// commit with RecoveryRequired; terminal publication must still settle to
  /// the inert signed-out projection instead of leaving closed Ready visible.
  Future<void> retireAfterDrain(SessionIdentityProjection signedOut) async {
    if (signedOut.status != SessionProjectionStatus.signedOut) {
      throw ArgumentError.value(
        signedOut.status,
        'signedOut',
        'Retirement requires a signed-out projection.',
      );
    }
    _checkActive();
    final activeLogout = _logoutSettled;
    if (activeLogout != null) await activeLogout.future;
    if (_disposed) return;
    if (_published.featureAccess.identity.status ==
        SessionProjectionStatus.ready) {
      await logout(signedOut);
      return;
    }
    replaceSignedOut(signedOut);
  }

  void login(
    SessionIdentityProjection ready, {
    required _SessionEffectSink effects,
  }) {
    if (ready.status != SessionProjectionStatus.ready) {
      throw ArgumentError.value(
        ready.status,
        'ready',
        'Login requires a ready projection.',
      );
    }
    _checkActive();
    if (_logoutInFlight ||
        _published.featureAccess.identity.status !=
            SessionProjectionStatus.signedOut) {
      throw StateError('Logout must drain and publish before login.');
    }

    final publication = _createOpenSession(ready, effects);
    _published = publication;
    _view.publish(publication.featureAccess);
  }

  void replaceSignedOut(SessionIdentityProjection signedOut) {
    if (signedOut.status != SessionProjectionStatus.signedOut) {
      throw ArgumentError.value(
        signedOut.status,
        'signedOut',
        'Signed-out replacement requires a signed-out projection.',
      );
    }
    _checkActive();
    if (_logoutInFlight ||
        _published.featureAccess.identity.status !=
            SessionProjectionStatus.signedOut) {
      throw StateError('Only a closed signed-out projection can be replaced.');
    }

    final publication = _createSignedOutSession(signedOut);
    _published = publication;
    _view.publish(publication.featureAccess);
  }

  void _checkActive() {
    if (_disposed) throw StateError('Session composition root is disposed.');
  }

  _PublishedSession _createOpenSession(
    SessionIdentityProjection identity,
    _SessionEffectSink effects,
  ) {
    final scope = _SessionScope(
      effects,
      topLevelAdmissionGate: _topLevelAdmissionGate,
    )..open();
    return _createSession(identity, scope);
  }

  _PublishedSession _createSignedOutSession(
    SessionIdentityProjection identity,
  ) {
    return _createSession(identity, _SessionScope.closed());
  }

  _PublishedSession _createSession(
    SessionIdentityProjection identity,
    _SessionScope scope,
  ) {
    return _PublishedSession(
      scope: scope,
      featureAccess: SessionFeatureAccess(
        identity: identity,
        operations: scope.runner,
      ),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Widget/process-root disposal cannot await, but admission still closes
    // synchronously and no successor is ever published from this root.
    unawaited(_published.scope.closeAndDrain());
    _view.dispose();
  }
}

/// Run the fixed deterministic ordering proof used by the lifecycle test.
///
/// This deliberately accepts no projections, callbacks, roots, runners, or
/// sinks and returns only inert event labels. It lets the test exercise the
/// private scheduling implementation without publishing a second lifecycle
/// owner as production-callable API.
Future<List<String>> runSessionLifecycleOrderingSelfCheck() async {
  final identityA = SessionIdentityProjection.ready(
    nativeRevision: '1',
    participantId: 1,
    accountId: 'account-a',
    address: 'address-a',
    publicKey: 'public-key-a',
  );
  final signedOut = SessionIdentityProjection.signedOut(nativeRevision: '2');
  final identityB = SessionIdentityProjection.ready(
    nativeRevision: '3',
    participantId: 2,
    accountId: 'account-b',
    address: 'address-b',
    publicKey: 'public-key-b',
  );
  final events = <String>[];
  final root = _SessionCompositionRoot(identityA);
  final runnerA = root.view.current.operations;
  final publication = root.view.changes.listen(
    (next) => events.add('publish:${next.identity.nativeRevision}'),
  );
  try {
    final operationRelease = Completer<void>();
    final childRelease = Completer<void>();
    final effectRelease = Completer<void>();
    final closingChildRelease = Completer<void>();
    late SessionOperation operation;
    late Future<void> child;
    late Future<void> effect;
    final running = runnerA.run<void>((admitted) {
      events.add('operation-entered');
      operation = admitted;
      child = admitted.runChild<void>((_) {
        events.add('child-entered');
        return childRelease.future;
      });
      effect = _SessionEffectSelfCheckSink.run<void>(admitted, () {
        events.add('effect-entered');
        return effectRelease.future;
      });
      return operationRelease.future;
    });

    final logout = root.logoutAfterDrain(() {
      events.add('commit');
      return signedOut;
    });
    _expectSelfCheckThrows<SessionAdmissionClosedException>(
      () => runnerA.run<void>((_) {}),
      'close must reject new admission synchronously',
    );
    events.add('admission-closed');

    final closingChild = operation.runChild<void>((_) {
      events.add('closing-child-entered');
      return closingChildRelease.future;
    });

    operationRelease.complete();
    await Future<void>.delayed(Duration.zero);
    _expectSelfCheck(
        !events.contains('commit'), 'operation body did not drain');
    childRelease.complete();
    await child;
    await Future<void>.delayed(Duration.zero);
    _expectSelfCheck(!events.contains('commit'), 'effect did not drain');
    effectRelease.complete();
    await Future<void>.delayed(Duration.zero);
    _expectSelfCheck(
      !events.contains('commit'),
      'child admitted by live operation during closing did not drain',
    );
    closingChildRelease.complete();
    await Future.wait<void>([running, child, closingChild, effect, logout]);
    _expectSelfCheck(
      root.view.current.identity.nativeRevision == '2',
      'signed-out publication must follow commit',
    );

    root.login(identityB, effects: const _ClosedSessionEffectSink());
    _expectSelfCheckThrows<SessionAdmissionClosedException>(
      () => runnerA.run<void>((_) {}),
      'retired runner reopened',
    );
    events.add('retired-runner-rejected');
    _expectSelfCheckThrows<SessionOperationExpiredException>(
      () => _SessionEffectSelfCheckSink.run<void>(operation, () {}),
      'expired operation reacquired an effect',
    );
    events.add('expired-effect-rejected');
  } finally {
    await publication.cancel();
    root.dispose();
  }

  final queuedRoot = _SessionCompositionRoot(
    SessionIdentityProjection.signedOut(nativeRevision: '0'),
  );
  final transitions = _NativeSessionTransitionSlot();
  final queuedPublication = queuedRoot.view.changes.listen(
    (next) => events.add('queued-publish:${next.identity.nativeRevision}'),
  );
  try {
    const realm = 'trusted-realm';
    transitions.beginEstablish(realm);
    final establishCompleted = transitions.beginLogout(realm);
    _expectSelfCheck(
        establishCompleted != null, 'logout did not join establish');
    final queuedLogout = () async {
      await establishCompleted;
      queuedRoot.replaceSignedOut(
        SessionIdentityProjection.signedOut(nativeRevision: '4'),
      );
      transitions.finishLogout(succeeded: true);
    }();
    if (!transitions.hasTerminalIntentFor(realm)) {
      queuedRoot.login(
        identityB,
        effects: const _ClosedSessionEffectSink(),
      );
    }
    transitions.finishEstablish(_NativeEstablishOutcome.ready);
    await queuedLogout;
    _expectSelfCheck(
      queuedRoot.view.current.identity.status ==
          SessionProjectionStatus.signedOut,
      'queued logout published Ready',
    );
    _expectSelfCheckThrows<SessionAdmissionClosedException>(
      () => queuedRoot.view.current.operations.run<void>((_) {}),
      'queued logout opened admission',
    );
    events.add('queued-runner-rejected');
  } finally {
    await queuedPublication.cancel();
    queuedRoot.dispose();
  }

  final heldWakeRoot = _SessionCompositionRoot(
    SessionIdentityProjection.signedOut(nativeRevision: '0'),
  );
  final heldWakeTransitions = _NativeSessionTransitionSlot();
  final wakeRelease = Completer<void>();
  var heldWakePublishedReady = false;
  final heldWakePublication = heldWakeRoot.view.changes.listen((next) {
    if (next.identity.status == SessionProjectionStatus.ready) {
      heldWakePublishedReady = true;
    }
  });
  try {
    const realm = 'held-wake-realm';
    heldWakeTransitions.beginEstablish(realm);
    final establishing = () async {
      if (!heldWakeTransitions.hasTerminalIntentFor(realm)) {
        await wakeRelease.future;
        if (!heldWakeTransitions.hasTerminalIntentFor(realm)) {
          heldWakeRoot.login(
            identityB,
            effects: const _ClosedSessionEffectSink(),
          );
        }
      }
      heldWakeTransitions.finishEstablish(_NativeEstablishOutcome.ready);
    }();
    await Future<void>.delayed(Duration.zero);
    final establishCompleted = heldWakeTransitions.beginLogout(realm);
    _expectSelfCheck(
      establishCompleted != null,
      'held-wake logout did not join establish',
    );
    final queuedLogout = () async {
      await establishCompleted;
      heldWakeRoot.replaceSignedOut(
        SessionIdentityProjection.signedOut(nativeRevision: '5'),
      );
      heldWakeTransitions.finishLogout(succeeded: true);
    }();
    wakeRelease.complete();
    await Future.wait<void>([establishing, queuedLogout]);
    _expectSelfCheck(
      !heldWakePublishedReady,
      'terminal intent queued during wake published Ready',
    );
    events.add('held-wake-terminal-suppressed');
  } finally {
    if (!wakeRelease.isCompleted) wakeRelease.complete();
    await heldWakePublication.cancel();
    heldWakeRoot.dispose();
  }

  final terminalRoot = _SessionCompositionRoot(
    identityA,
    readyEffects: const _ClosedSessionEffectSink(),
  );
  final explicitCommitEntered = Completer<void>();
  final explicitCommitRelease = Completer<void>();
  try {
    final explicitLogout = terminalRoot.logoutAfterDrain(() async {
      explicitCommitEntered.complete();
      await explicitCommitRelease.future;
      throw StateError('simulated native RecoveryRequired');
    });
    await explicitCommitEntered.future;
    final nativeRetirement = terminalRoot.retireAfterDrain(
      SessionIdentityProjection.signedOut(nativeRevision: '6'),
    );
    explicitCommitRelease.complete();
    try {
      await explicitLogout;
      throw StateError('explicit logout unexpectedly committed');
    } on StateError catch (error) {
      _expectSelfCheck(
        error.message == 'simulated native RecoveryRequired',
        'unexpected explicit logout failure',
      );
    }
    await nativeRetirement;
    _expectSelfCheck(
      terminalRoot.view.current.identity.status ==
              SessionProjectionStatus.signedOut &&
          terminalRoot.view.current.identity.nativeRevision == '6',
      'native retirement did not settle concurrent logout to signed-out',
    );
    events.add('terminal-retirement-joined-logout');
  } finally {
    if (!explicitCommitRelease.isCompleted) explicitCommitRelease.complete();
    terminalRoot.dispose();
  }

  final gatedRoot = _SessionCompositionRoot(
    identityA,
    readyEffects: const _ClosedSessionEffectSink(),
  );
  final resumeGate = Completer<void>();
  gatedRoot.bindTopLevelAdmissionGate(() => resumeGate.future);
  try {
    var entered = false;
    final gatedOperation = gatedRoot.view.current.operations.run<void>((_) {
      entered = true;
    });
    await Future<void>.delayed(Duration.zero);
    _expectSelfCheck(!entered, 'resume validation did not gate admission');
    events.add('resume-gate-held');

    await gatedRoot.logout(signedOut);
    resumeGate.complete();
    try {
      await gatedOperation;
      throw StateError('retired runner admitted after resume validation');
    } on SessionAdmissionClosedException {
      events.add('resume-gate-retired-runner-rejected');
    }
  } finally {
    if (!resumeGate.isCompleted) resumeGate.complete();
    gatedRoot.dispose();
  }

  return List<String>.unmodifiable(events);
}

abstract final class _SessionEffectSelfCheckSink {
  static Future<T> run<T>(
    SessionOperation operation,
    FutureOr<T> Function() body,
  ) {
    if (operation is! _SessionOperation) {
      throw const SessionOperationExpiredException();
    }
    final lease = operation.acquireEffect();
    late FutureOr<T> result;
    try {
      result = body();
    } catch (error, stackTrace) {
      lease.release();
      return Future<T>.error(error, stackTrace);
    }
    return Future<T>.value(result).whenComplete(lease.release);
  }
}

void _expectSelfCheck(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectSelfCheckThrows<T extends Object>(
  void Function() body,
  String message,
) {
  try {
    body();
  } catch (error) {
    if (error is T) return;
    Error.throwWithStackTrace(error, StackTrace.current);
  }
  throw StateError(message);
}
