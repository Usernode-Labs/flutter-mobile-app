import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

enum _ScopeState {
  staged,
  open,
  closing,
  revoked,
}

final class _SessionScope {
  _SessionScope() : _state = _ScopeState.staged;

  _SessionScope.closed() : _state = _ScopeState.revoked {
    _drained.complete();
  }

  _ScopeState _state;
  int _operations = 0;
  int _children = 0;
  int _effects = 0;
  final Completer<void> _drained = Completer<void>();

  late final SessionOperationRunner runner = _SessionOperationRunner(this);

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

  _SessionOperation admitChild() {
    if (_state != _ScopeState.open) {
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
      // This write is deliberately synchronous with the caller. No new run or
      // child can enter after closeAndDrain returns its Future.
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
    final child = _scope.admitChild();
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
/// Production bootstrap will construct exactly one of these after native
/// recovery can provide a truthful initial projection. Until then it remains
/// deliberately unmounted: the existing application identity must not gain a
/// decorative second publisher. Only the read-only [view] crosses this root.
final class _SessionCompositionRoot {
  _SessionCompositionRoot(SessionIdentityProjection initialIdentity) {
    final initial = switch (initialIdentity.status) {
      SessionProjectionStatus.signedOut =>
        _createSignedOutSession(initialIdentity),
      SessionProjectionStatus.ready => _createOpenSession(initialIdentity),
    };
    _published = initial;
    _view = _ReadOnlySessionView(initial.featureAccess);
  }

  late _PublishedSession _published;
  late final _ReadOnlySessionView _view;
  var _logoutInFlight = false;
  var _disposed = false;

  SessionFeatureAccessView get view => _view;

  Future<void> logout(SessionIdentityProjection signedOut) {
    if (signedOut.status != SessionProjectionStatus.signedOut) {
      throw ArgumentError.value(
        signedOut.status,
        'signedOut',
        'Logout requires a signed-out projection.',
      );
    }
    _checkActive();
    if (_logoutInFlight) {
      throw StateError('Session logout is already in progress.');
    }
    if (_published.featureAccess.identity.status ==
        SessionProjectionStatus.signedOut) {
      return Future<void>.value();
    }
    _logoutInFlight = true;

    // Closing admission is synchronous. Publication remains on A until this
    // exact drain completes; there is no timeout or forced publication.
    final drain = _published.scope.closeAndDrain();
    return drain.then<void>((_) {
      if (_disposed) return;
      final publication = _createSignedOutSession(signedOut);
      _published = publication;
      _view.publish(publication.featureAccess);
    }).whenComplete(() {
      _logoutInFlight = false;
    });
  }

  void login(SessionIdentityProjection ready) {
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

    final publication = _createOpenSession(ready);
    _published = publication;
    _view.publish(publication.featureAccess);
  }

  void _checkActive() {
    if (_disposed) throw StateError('Session composition root is disposed.');
  }

  _PublishedSession _createOpenSession(SessionIdentityProjection identity) {
    final scope = _SessionScope()..open();
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

/// Test-only access to the in-memory scheduling core.
///
/// This type lives under `lib/src`, is not exported, and owns no native
/// transport or production sink. It can only exercise fake operations and a
/// fake counted effect.
final class SessionOperationKernelTestHarness {
  SessionOperationKernelTestHarness(SessionIdentityProjection initialIdentity)
      : _root = _SessionCompositionRoot(initialIdentity);

  final _SessionCompositionRoot _root;
  final SessionEffectTestSink effects = const SessionEffectTestSink._();

  SessionFeatureAccessView get view => _root.view;

  Future<void> logout(SessionIdentityProjection signedOut) =>
      _root.logout(signedOut);

  void login(SessionIdentityProjection ready) => _root.login(ready);

  void dispose() => _root.dispose();
}

/// Fake sink used only to prove synchronous effect acquisition and drain.
final class SessionEffectTestSink {
  const SessionEffectTestSink._();

  Future<T> run<T>(
    SessionOperation operation,
    FutureOr<T> Function() body,
  ) {
    if (operation is! _SessionOperation) {
      throw const SessionOperationExpiredException();
    }
    // Acquire synchronously before invoking even a synchronous sink body.
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
