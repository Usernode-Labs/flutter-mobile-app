import 'package:crypto_mobile_app/features/dapps/bridge_admission_queue.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';

/// The ordered, testable admission phase of the JavaScript bridge.
///
/// Capability probing, identity fences, and the required listener-readiness
/// handshake happen here before domain handlers run. Ordinary admitted
/// handlers remain concurrent. A lifecycle handler holds the FIFO through its
/// completion so no later bridge request can enter during a session boundary.
final class BridgeAdmissionCoordinator {
  BridgeAdmissionCoordinator({
    required PrivilegedBridgePolicy policy,
    required Future<bool> Function(PrivilegedBridgeLease lease) markRealmReady,
  })  : _policy = policy,
        _markRealmReady = markRealmReady;

  final PrivilegedBridgePolicy _policy;
  final Future<bool> Function(PrivilegedBridgeLease lease) _markRealmReady;
  final BridgeAdmissionQueue _queue = BridgeAdmissionQueue();
  int _readinessEpoch = 0;
  bool _disposed = false;

  static const _lifecycleMethods = {
    'prepareForLogin',
    'logout',
    'establishNativeSession',
  };

  Future<T> runRequest<T>({
    required String method,
    required Map<String, dynamic> payload,
    required Future<T> Function(BridgeAdmissionDecision admission) body,
  }) {
    if (_lifecycleMethods.contains(method)) {
      return _queue.run(
        () async => _runInRequestContext(
          admission: await _admitInOrder(method, payload),
          body: body,
        ),
      );
    }
    return _runConcurrentRequest(method: method, payload: payload, body: body);
  }

  Future<T> _runConcurrentRequest<T>({
    required String method,
    required Map<String, dynamic> payload,
    required Future<T> Function(BridgeAdmissionDecision admission) body,
  }) async {
    final admission = await _queue.run(() => _admitInOrder(method, payload));
    return _runInRequestContext(admission: admission, body: body);
  }

  Future<T> _runInRequestContext<T>({
    required BridgeAdmissionDecision admission,
    required Future<T> Function(BridgeAdmissionDecision admission) body,
  }) =>
      PrivilegedBridgeRequestContext.run(
        lease: admission.lease,
        body: () => body(admission),
      );

  /// Invalidates a readiness proof that is currently awaiting a realm probe.
  /// An already-ready realm remains usable: exact-marker event guards prevent
  /// it from dispatching into a committed replacement, while a failed
  /// provisional navigation can safely leave the old document active.
  void noteDocumentLoadStarted() {
    _readinessEpoch++;
  }

  void dispose() {
    _disposed = true;
    _readinessEpoch++;
  }

  Future<BridgeAdmissionDecision> _admitInOrder(
    String method,
    Map<String, dynamic> payload,
  ) async {
    if (_disposed) {
      return const BridgeAdmissionDecision.response(
        error: 'The native bridge is no longer available',
      );
    }

    PrivilegedBridgeLease? lease;
    final requiresCapability = _policy.requiresCapability(method);
    if (requiresCapability) {
      final authorization = await _policy.authorize(
        payload['privilegedCapability'],
      );
      if (authorization?.authorized != true) {
        return BridgeAdmissionDecision.response(
          lease: authorization?.lease,
          error: '$method requires a trusted top-frame capability',
        );
      }
      lease = authorization!.lease;
    } else {
      // Ordinary dapp methods retain their existing bridge contract. This
      // coordinator scopes only the trusted Social/native boundary.
      lease = null;
    }

    if (method == 'markPrivilegedBridgeReady') {
      final requestEpoch = ++_readinessEpoch;
      if (!await _policy.revalidates(lease!) ||
          _disposed ||
          requestEpoch != _readinessEpoch) {
        return BridgeAdmissionDecision.response(
          lease: lease,
          error: '$method was cancelled because the page changed',
        );
      }
      if (!await _acceptReadyLease(lease)) {
        return BridgeAdmissionDecision.response(
          lease: lease,
          error: '$method could not replay native state into this page',
        );
      }
      return BridgeAdmissionDecision.response(
        lease: lease,
        value: const {'ready': true},
      );
    }

    return BridgeAdmissionDecision.dispatch(lease);
  }

  Future<bool> _acceptReadyLease(
    PrivilegedBridgeLease lease,
  ) async {
    final delivered = await _markRealmReady(lease);
    if (!delivered || _disposed) return false;
    return true;
  }
}

final class BridgeAdmissionDecision {
  const BridgeAdmissionDecision._({
    required this.dispatch,
    required this.lease,
    required this.value,
    required this.error,
  });

  const BridgeAdmissionDecision.dispatch(PrivilegedBridgeLease? lease)
      : this._(
          dispatch: true,
          lease: lease,
          value: null,
          error: null,
        );

  const BridgeAdmissionDecision.response({
    PrivilegedBridgeLease? lease,
    Object? value,
    String? error,
  }) : this._(
          dispatch: false,
          lease: lease,
          value: value,
          error: error,
        );

  final bool dispatch;
  final PrivilegedBridgeLease? lease;
  final Object? value;
  final String? error;
}
