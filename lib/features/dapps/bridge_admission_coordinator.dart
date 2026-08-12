import 'package:crypto_mobile_app/features/dapps/bridge_admission_queue.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:crypto_mobile_app/features/dapps/session_bound_auth_status.dart';

/// The ordered, testable admission phase of the JavaScript bridge.
///
/// Capability probing, identity fences, and the explicit listener-readiness
/// handshake happen here before domain handlers run. Only admission is FIFO;
/// [runInRequestContext] lets admitted handlers remain concurrent while their
/// asynchronous replies retain the correct realm lease.
final class BridgeAdmissionCoordinator {
  BridgeAdmissionCoordinator({
    required PrivilegedBridgePolicy policy,
    required SessionHandoffGate sessionGate,
    required bool Function() admitAnonymousSession,
    required Future<bool> Function(PrivilegedBridgeLease lease) markRealmReady,
  })  : _policy = policy,
        _sessionGate = sessionGate,
        _admitAnonymousSession = admitAnonymousSession,
        _markRealmReady = markRealmReady;

  final PrivilegedBridgePolicy _policy;
  final SessionHandoffGate _sessionGate;
  final bool Function() _admitAnonymousSession;
  final Future<bool> Function(PrivilegedBridgeLease lease) _markRealmReady;
  final BridgeAdmissionQueue _queue = BridgeAdmissionQueue();
  int _readinessEpoch = 0;
  String? _currentReadyMarker;
  bool _disposed = false;

  Future<BridgeAdmissionDecision> admit(
    String method,
    Map<String, dynamic> payload,
  ) =>
      _queue.run(() => _admitInOrder(method, payload));

  Future<T> runInRequestContext<T>({
    required BridgeAdmissionDecision admission,
    required Future<T> Function() body,
  }) =>
      PrivilegedBridgeRequestContext.run(
        lease: admission.lease,
        body: body,
      );

  /// Invalidates a readiness proof that is currently awaiting a realm probe.
  /// An already-ready realm remains usable: exact-marker event guards prevent
  /// it from dispatching into a committed replacement, while a failed
  /// provisional navigation can safely leave the old document active.
  void noteDocumentLoadStarted() {
    _readinessEpoch++;
    // A canceled provisional load may leave this exact legacy realm active,
    // but native events attempted during the load were marker-guarded/dropped.
    // Clear only the replay dedupe so its next authorized call reseeds state.
    _currentReadyMarker = null;
  }

  void dispose() {
    _disposed = true;
    _readinessEpoch++;
    _currentReadyMarker = null;
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

      // Older/cached Social shells predate markPrivilegedBridgeReady. Promote
      // only the exact authorized realm and only after proving that the API is
      // conclusively absent. New shells remain gated on their explicit signal.
      if (method != 'markPrivilegedBridgeReady' &&
          lease.marker != _currentReadyMarker) {
        final supportsReadiness =
            await _policy.supportsExplicitReadiness(lease);
        if (supportsReadiness == false) await _acceptReadyLease(lease);
      }
    } else {
      // Ordinary dapp methods retain their existing bridge contract. This
      // coordinator scopes only the trusted Social/native boundary.
      lease = null;
    }

    // Raw Android child-frame channel messages bypass the page relay. Keeping
    // this check inside ordered admission preserves the identity fence.
    if (_sessionGate.blocks(method)) {
      return BridgeAdmissionDecision.response(
        lease: lease,
        error: '$method is unavailable during an identity transition',
      );
    }

    if (method == 'beginSessionHandoff') {
      _sessionGate.begin();
      return BridgeAdmissionDecision.response(
        lease: lease,
        value: const {'blocked': true},
      );
    }

    if (method == 'enterAnonymousSession') {
      if (!await _policy.revalidates(lease!)) {
        return BridgeAdmissionDecision.response(
          lease: lease,
          error: '$method was cancelled because the page changed',
        );
      }
      return BridgeAdmissionDecision.response(
        lease: lease,
        value: {'admitted': _admitAnonymousSession()},
      );
    }

    if (method == 'logout') {
      // Close admission in arrival order. The handler still revalidates the
      // realm immediately around the terminal native effect.
      _sessionGate.begin();
    }

    if (method == 'markPrivilegedBridgeReady') {
      final requestEpoch = ++_readinessEpoch;
      // Mixed cached assets can expose the method before the coordinator that
      // promises listener readiness is present. Only the explicit client
      // marker makes this handshake authoritative; otherwise the next normal
      // privileged call uses the legacy post-initialization fallback.
      final supportsReadiness = await _policy.supportsExplicitReadiness(lease!);
      if (supportsReadiness == false) {
        return BridgeAdmissionDecision.response(
          lease: lease,
          value: const {'ready': false},
        );
      }
      if (supportsReadiness != true ||
          !await _policy.revalidates(lease) ||
          _disposed ||
          requestEpoch != _readinessEpoch) {
        return BridgeAdmissionDecision.response(
          lease: lease,
          error: '$method was cancelled because the page changed',
        );
      }
      if (!await _acceptReadyLease(lease, forceReplay: true)) {
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
    PrivilegedBridgeLease lease, {
    bool forceReplay = false,
  }) async {
    if (!forceReplay && _currentReadyMarker == lease.marker) return true;
    final delivered = await _markRealmReady(lease);
    if (!delivered || _disposed) return false;
    _currentReadyMarker = lease.marker;
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
