import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

enum _ScopeState {
  staged,
  open,
  closing,
  revoked,
}

final class _SessionScope {
  _ScopeState _state = _ScopeState.staged;
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

final class _SessionOperationKernel {
  _SessionOperationKernel(SessionIdentityProjection initialIdentity) {
    final initial = _createOpenSession(initialIdentity);
    _published = initial;
    _view = _ReadOnlySessionView(initial.featureAccess);
  }

  late _PublishedSession _published;
  late final _ReadOnlySessionView _view;
  var _replacementInFlight = false;
  var _disposed = false;

  SessionFeatureAccessView get view => _view;

  Future<void> replaceWith(SessionIdentityProjection identity) async {
    if (_disposed) throw StateError('Session operation kernel is disposed.');
    if (_replacementInFlight) {
      throw StateError('A session replacement is already in progress.');
    }
    _replacementInFlight = true;

    // Closing admission is synchronous. Publication remains on A until this
    // exact drain completes; there is no timeout or forced successor.
    final drain = _published.scope.closeAndDrain();
    try {
      await drain;
      if (_disposed) return;
      final successor = _createOpenSession(identity);
      _published = successor;
      _view.publish(successor.featureAccess);
    } finally {
      _replacementInFlight = false;
    }
  }

  _PublishedSession _createOpenSession(SessionIdentityProjection identity) {
    final scope = _SessionScope()..open();
    return _PublishedSession(
      scope: scope,
      featureAccess: SessionFeatureAccess(
        identity: identity,
        operations: scope.runner,
      ),
    );
  }

  void dispose() {
    _disposed = true;
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
      : _kernel = _SessionOperationKernel(initialIdentity);

  final _SessionOperationKernel _kernel;
  final SessionEffectTestSink effects = const SessionEffectTestSink._();

  SessionFeatureAccessView get view => _kernel.view;

  Future<void> replaceWith(SessionIdentityProjection identity) =>
      _kernel.replaceWith(identity);

  void dispose() => _kernel.dispose();
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
