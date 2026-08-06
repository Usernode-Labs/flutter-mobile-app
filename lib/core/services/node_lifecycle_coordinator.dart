import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/node_runtime_binding.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

/// What the platform (SV chrome) most recently requested of the node runtime.
enum PlatformNodeIntent { unset, start, stop }

/// Outcome of validating and applying one native Android recovery delivery.
///
/// Rejection is terminal for that delivery, while a retryable failure retains
/// the already-validated recovery authority so WorkManager can try again.
enum NodeNativeRecoveryResult { rejected, recovered, retryableFailure }

/// Immutable operational target reconciled by [NodeLifecycleCoordinator].
@immutable
class NodeDesiredState {
  const NodeDesiredState({
    required this.revision,
    required this.binding,
    required this.authority,
    required this.intent,
    required this.sleeping,
    required this.recoveryArmed,
    required this.recoveryRunRequested,
    required this.acceptingRuntimeWork,
  });

  const NodeDesiredState.initial()
      : revision = 0,
        binding = null,
        authority = null,
        intent = PlatformNodeIntent.unset,
        sleeping = false,
        recoveryArmed = false,
        recoveryRunRequested = false,
        acceptingRuntimeWork = true;

  final int revision;
  final NodeRuntimeBinding? binding;
  final NodeRuntimeAuthority? authority;
  final PlatformNodeIntent intent;
  final bool sleeping;
  final bool recoveryArmed;
  final bool recoveryRunRequested;
  final bool acceptingRuntimeWork;

  bool get runDesired =>
      acceptingRuntimeWork &&
      binding != null &&
      (intent == PlatformNodeIntent.start || recoveryRunRequested) &&
      (!sleeping || recoveryRunRequested);

  bool get mayKeepRunning =>
      acceptingRuntimeWork &&
      binding != null &&
      intent != PlatformNodeIntent.stop &&
      (intent == PlatformNodeIntent.start ||
          recoveryArmed ||
          recoveryRunRequested);

  bool get recoveryDesired =>
      acceptingRuntimeWork &&
      recoveryArmed &&
      intent != PlatformNodeIntent.stop &&
      binding?.productionEligible == true;

  NodeDesiredState copyWith({
    required int revision,
    NodeRuntimeBinding? binding,
    bool clearBinding = false,
    NodeRuntimeAuthority? authority,
    bool clearAuthority = false,
    PlatformNodeIntent? intent,
    bool? sleeping,
    bool? recoveryArmed,
    bool? recoveryRunRequested,
    bool? acceptingRuntimeWork,
  }) {
    return NodeDesiredState(
      revision: revision,
      binding: clearBinding ? null : (binding ?? this.binding),
      authority: clearAuthority ? null : (authority ?? this.authority),
      intent: intent ?? this.intent,
      sleeping: sleeping ?? this.sleeping,
      recoveryArmed: recoveryArmed ?? this.recoveryArmed,
      recoveryRunRequested: recoveryRunRequested ?? this.recoveryRunRequested,
      acceptingRuntimeWork: acceptingRuntimeWork ?? this.acceptingRuntimeWork,
    );
  }
}

/// Single owner of node runtime transitions and Android recovery authority.
///
/// Every lifecycle mutation runs through one queue. Slow binding reads happen
/// outside it, then commit only if their request is still current. Android
/// mutations are compare-and-set operations against [_ownedAndroidLease]; an
/// accepted result advances that private cursor even when the command that
/// requested it was superseded, while a rejected result never transfers
/// ownership.
class NodeLifecycleCoordinator {
  NodeLifecycleCoordinator({
    Future<bool> Function(
      NodeRuntimeBinding binding,
      NodeRuntimeAuthority? authority,
    )? startBackend,
    Future<void> Function(int? retireThroughGeneration)? stopBackend,
    Future<void> Function()? pauseBackend,
    Future<void> Function()? resumeBackend,
    bool Function()? isNodeRunning,
    NodeRuntimeBinding? Function()? runningBinding,
    NodeRuntimeAuthority? Function()? runningAuthority,
    Future<NodeRuntimeBinding?> Function(Identity identity)? resolveBinding,
    bool Function()? isSleeping,
    void Function()? enableWatchdogRecovery,
    void Function()? disableWatchdogRecovery,
    void Function({required String reason})? auditBestEffort,
    Future<void> Function(NodeRuntimeAuthority authority)? onNodeStarted,
    Future<void> Function({
      required String reason,
      required NodeRuntimeAuthority? authority,
    })? stopMonitoring,
    Future<NodeRecoveryLease> Function()? loadRecoveryLease,
    Future<NodeRecoveryLeaseMutation> Function(
      String bindingFingerprint,
      NodeRecoveryLease expectedLease,
    )? reserveRuntimeBinding,
    Future<NodeRecoveryLeaseMutation> Function(NodeRuntimeAuthority authority)?
        activateRecoveryLease,
    Future<NodeRecoveryLeaseMutation> Function(NodeRuntimeAuthority authority)?
        disableRecoveryLease,
    Future<NodeRecoveryLeaseMutation> Function(NodeRecoveryLease expectedLease)?
        revokeRecoveryLease,
    bool Function()? isAndroid,
  })  : _startBackend = startBackend ??
            ((binding, authority) => RustBackendService.instance.startNode(
                  binding: binding,
                  runtimeAuthority: authority,
                )),
        _stopBackend = stopBackend ??
            ((retireThroughGeneration) => RustBackendService.instance.stopNode(
                  retireThroughAuthorityGeneration: retireThroughGeneration,
                )),
        _pauseBackend =
            pauseBackend ?? (() => RustBackendService.instance.pauseNode()),
        _resumeBackend =
            resumeBackend ?? (() => RustBackendService.instance.resumeNode()),
        _isNodeRunning =
            isNodeRunning ?? (() => RustBackendService.instance.isRunning),
        _runningBinding = runningBinding ??
            (() => RustBackendService.instance.runtimeBinding),
        _runningAuthority = runningAuthority ??
            (() => RustBackendService.instance.runtimeAuthority),
        _resolveBinding = resolveBinding ?? resolveNodeRuntimeBinding,
        _isSleeping = isSleeping ?? (() => AppSleepStateStore.isSleeping),
        _enableWatchdogRecovery = enableWatchdogRecovery ??
            (() => BlockProductionAlarmAuditService.instance
                .enableWatchdogRecovery()),
        _disableWatchdogRecovery = disableWatchdogRecovery ??
            (() => BlockProductionAlarmAuditService.instance
                .disableWatchdogRecovery()),
        _auditBestEffort = auditBestEffort ??
            (({required String reason}) => BlockProductionAlarmAuditService
                .instance
                .auditBestEffort(reason: reason)),
        _onNodeStarted = onNodeStarted ??
            ((authority) => AndroidForegroundTaskController.instance
                .onNodeStarted(authority: authority)),
        _stopMonitoring = stopMonitoring ??
            (({
              required String reason,
              required NodeRuntimeAuthority? authority,
            }) =>
                AndroidForegroundTaskController.instance.stopMonitoring(
                  reason: reason,
                  authority: authority,
                )),
        _loadRecoveryLease = loadRecoveryLease ??
            (() => PlatformAlarmService.instance.getNodeRecoveryLease()),
        _reserveRuntimeBinding = reserveRuntimeBinding ??
            ((bindingFingerprint, expectedLease) =>
                PlatformAlarmService.instance.reserveNodeRuntimeBinding(
                  bindingFingerprint: bindingFingerprint,
                  expectedLease: expectedLease,
                )),
        _activateRecoveryLease = activateRecoveryLease ??
            ((authority) =>
                PlatformAlarmService.instance.activateNodeRecoveryLease(
                  authority: authority,
                )),
        _disableRecoveryLease = disableRecoveryLease ??
            ((authority) =>
                PlatformAlarmService.instance.disableNodeRecoveryLease(
                  authority: authority,
                )),
        _revokeRecoveryLease = revokeRecoveryLease ??
            ((expectedLease) =>
                PlatformAlarmService.instance.revokeNodeRecoveryLease(
                  expectedLease: expectedLease,
                )),
        _isAndroid = isAndroid ??
            (() => defaultTargetPlatform == TargetPlatform.android) {
    if (onNodeStarted == null && stopMonitoring == null) {
      AndroidForegroundTaskController.instance.setMonitoringStoppedCallback(
        (authority) => completeRecoveryRun(authority: authority),
      );
    }
  }

  static NodeLifecycleCoordinator instance = NodeLifecycleCoordinator();

  final Future<bool> Function(
    NodeRuntimeBinding binding,
    NodeRuntimeAuthority? authority,
  ) _startBackend;
  final Future<void> Function(int? retireThroughGeneration) _stopBackend;
  final Future<void> Function() _pauseBackend;
  final Future<void> Function() _resumeBackend;
  final bool Function() _isNodeRunning;
  final NodeRuntimeBinding? Function() _runningBinding;
  final NodeRuntimeAuthority? Function() _runningAuthority;
  final Future<NodeRuntimeBinding?> Function(Identity identity) _resolveBinding;
  final bool Function() _isSleeping;
  final void Function() _enableWatchdogRecovery;
  final void Function() _disableWatchdogRecovery;
  final void Function({required String reason}) _auditBestEffort;
  final Future<void> Function(NodeRuntimeAuthority authority) _onNodeStarted;
  final Future<void> Function({
    required String reason,
    required NodeRuntimeAuthority? authority,
  }) _stopMonitoring;
  final Future<NodeRecoveryLease> Function() _loadRecoveryLease;
  final Future<NodeRecoveryLeaseMutation> Function(
    String bindingFingerprint,
    NodeRecoveryLease expectedLease,
  ) _reserveRuntimeBinding;
  final Future<NodeRecoveryLeaseMutation> Function(
    NodeRuntimeAuthority authority,
  ) _activateRecoveryLease;
  final Future<NodeRecoveryLeaseMutation> Function(
    NodeRuntimeAuthority authority,
  ) _disableRecoveryLease;
  final Future<NodeRecoveryLeaseMutation> Function(
    NodeRecoveryLease expectedLease,
  ) _revokeRecoveryLease;
  final bool Function() _isAndroid;

  NodeDesiredState _desired = const NodeDesiredState.initial();
  Future<void> _serial = Future<void>.value();
  NodeRecoveryLease? _ownedAndroidLease;
  // Highest token this coordinator successfully superseded. It is safe to
  // retire through this bound even when another engine has already moved on.
  int? _supersededAuthorityGeneration;
  var _canRebindAndroidAuthority = false;
  var _nextRevision = 0;
  var _latestBindingRequest = 0;

  @visibleForTesting
  NodeDesiredState get desired => _desired;

  @visibleForTesting
  PlatformNodeIntent get intent => _desired.intent;

  @visibleForTesting
  bool get acceptingRuntimeWork => _desired.acceptingRuntimeWork;

  @visibleForTesting
  NodeRuntimeBinding? get binding => _desired.binding;

  @visibleForTesting
  NodeRecoveryLease? get ownedAndroidLease => _ownedAndroidLease;

  /// Captures the native authority before identity restoration starts.
  ///
  /// Interactive engines may CAS this exact token to another binding.
  /// Headless engines may consume or revoke it, but cannot mint a binding.
  void initializeAndroidAuthority(
    NodeRecoveryLease lease, {
    required bool canRebind,
  }) {
    if (!_isAndroid()) return;
    if (_ownedAndroidLease != null) return;
    _ownedAndroidLease = lease;
    _canRebindAndroidAuthority = canRebind;
  }

  /// Platform (or a standalone dapp entry) requests a node start for the exact
  /// currently-ready identity.
  Future<bool> startNode({required String reason}) async {
    if (!_desired.acceptingRuntimeWork ||
        (_isAndroid() &&
            (_ownedAndroidLease == null || !_canRebindAndroidAuthority))) {
      return false;
    }

    final request = ++_latestBindingRequest;
    final identity = IdentitySnapshots.current;
    _updateDesired(
      clearBinding: true,
      clearAuthority: true,
      intent: PlatformNodeIntent.start,
      recoveryArmed: false,
      recoveryRunRequested: false,
      sleeping: _isSleeping(),
    );

    final binding = await _resolveBinding(identity);
    if (!_requestIsCurrent(request, identity)) return false;

    return _enqueue(() async {
      if (!_requestIsCurrent(request, identity)) return false;
      if (binding == null) {
        if (_isAndroid()) await _revokeOwnedAuthority();
        if (!_requestIsCurrent(request, identity)) return false;
        _updateDesired(
          clearBinding: true,
          clearAuthority: true,
          recoveryArmed: false,
          recoveryRunRequested: false,
        );
        await _reconcileLatest(reason: reason);
        return false;
      }

      NodeRuntimeAuthority? authority;
      if (_isAndroid()) {
        authority = await _authorityForBinding(binding);
        if (!_requestIsCurrent(request, identity)) return false;
        if (authority == null) {
          _updateDesired(
            binding: binding,
            clearAuthority: true,
            recoveryArmed: false,
            recoveryRunRequested: false,
          );
          await _reconcileLatest(reason: reason);
          return false;
        }
      }

      _updateDesired(
        binding: binding,
        authority: authority,
        clearAuthority: !_isAndroid(),
        intent: PlatformNodeIntent.start,
        recoveryArmed: binding.productionEligible,
        recoveryRunRequested: false,
        sleeping: _isSleeping(),
      );
      await _reconcileLatest(reason: reason);
      return _desired.runDesired &&
          _isNodeRunning() &&
          _runningBinding() == binding;
    });
  }

  /// Platform explicitly requests a node stop and retires owned authority.
  Future<void> stopNode({required String reason}) {
    _latestBindingRequest += 1;
    if (!_desired.acceptingRuntimeWork) return Future.value();
    _updateDesired(
      clearAuthority: true,
      intent: PlatformNodeIntent.stop,
      recoveryArmed: false,
      recoveryRunRequested: false,
    );
    return _enqueue(() async {
      if (_isAndroid()) await _revokeOwnedAuthority();
      await _reconcileLatest(reason: reason);
    });
  }

  /// Publishes the latest identity/configuration binding.
  Future<void> reportIdentityChanged(
    Identity identity, {
    String reason = 'identity_changed',
  }) async {
    if (!_desired.acceptingRuntimeWork) return;
    final request = ++_latestBindingRequest;
    _updateDesired(
      clearBinding: true,
      clearAuthority: true,
      recoveryArmed: false,
      recoveryRunRequested: false,
    );

    final binding = await _resolveBinding(identity);
    if (!_requestIsCurrent(request, identity)) return;

    return _enqueue(() async {
      if (!_requestIsCurrent(request, identity)) return;
      NodeRuntimeAuthority? authority;
      if (_isAndroid()) {
        if (_ownedAndroidLease == null) {
          await _reconcileLatest(reason: reason);
          return;
        }
        authority = await _authorityForBinding(binding);
        if (!_requestIsCurrent(request, identity)) return;
      }

      final recoveryArmed = binding?.productionEligible == true &&
          (_desired.intent == PlatformNodeIntent.start ||
              (_ownedAndroidLease?.enabled == true &&
                  authority?.bindingFingerprint ==
                      binding?.recoveryFingerprint));
      _updateDesired(
        binding: binding,
        clearBinding: binding == null,
        authority: authority,
        clearAuthority: !_isAndroid() || authority == null,
        sleeping: _isSleeping(),
        recoveryArmed: recoveryArmed,
        recoveryRunRequested: false,
      );
      await _reconcileLatest(reason: reason);
    });
  }

  /// Reconciles the boot authority captured before identity restoration.
  ///
  /// A newer engine that advances the native lease while binding resolution
  /// is in flight causes our CAS to fail; its authority is never adopted or
  /// revoked by this coordinator.
  Future<bool> reportColdBoot({String reason = 'cold_boot'}) async {
    if (!_desired.acceptingRuntimeWork) return false;
    final request = _latestBindingRequest;
    final identity = IdentitySnapshots.current;
    final binding = await _resolveBinding(identity);
    if (!_requestIsCurrent(request, identity)) return _isNodeRunning();

    return _enqueue(() async {
      if (!_requestIsCurrent(request, identity)) return _isNodeRunning();
      NodeRuntimeAuthority? authority;
      if (_isAndroid()) {
        if (_ownedAndroidLease == null) {
          await _reconcileLatest(reason: reason);
          return false;
        }
        authority = await _authorityForBinding(binding);
        if (!_requestIsCurrent(request, identity)) return _isNodeRunning();
      }

      final leaseMatches = binding != null &&
          binding.productionEligible &&
          _ownedAndroidLease?.enabled == true &&
          authority?.bindingFingerprint == binding.recoveryFingerprint;
      _updateDesired(
        binding: binding,
        clearBinding: binding == null,
        authority: authority,
        clearAuthority: !_isAndroid() || authority == null,
        sleeping: _isSleeping(),
        recoveryArmed: leaseMatches,
        recoveryRunRequested: false,
      );
      await _reconcileLatest(reason: reason);
      return _isNodeRunning();
    });
  }

  /// Accepts a native recovery only while the event, durable lease, desired
  /// binding, and locally-owned authority all name the same token.
  Future<NodeNativeRecoveryResult> recoverFromNativeEvent(
    Map<String, dynamic> eventData, {
    required String reason,
  }) {
    return _enqueue(() async {
      final target = _desired;
      final targetBinding = target.binding;
      final targetAuthority = target.authority;
      if (!target.acceptingRuntimeWork ||
          targetBinding == null ||
          !targetBinding.productionEligible ||
          targetAuthority == null ||
          !_owns(targetAuthority)) {
        return NodeNativeRecoveryResult.rejected;
      }

      final lease = await _loadRecoveryLease();
      if (!_isCurrent(target) ||
          !lease.matchesEvent(eventData) ||
          !lease.matchesAuthority(targetAuthority) ||
          lease.bindingFingerprint != targetBinding.recoveryFingerprint) {
        return NodeNativeRecoveryResult.rejected;
      }

      _updateDesired(
        recoveryArmed: true,
        recoveryRunRequested: true,
      );
      await _reconcileLatest(reason: reason);
      final current = _desired;
      final authorityStillValid = current.acceptingRuntimeWork &&
          current.binding == targetBinding &&
          current.authority == targetAuthority &&
          current.recoveryArmed &&
          _owns(targetAuthority);
      if (!authorityStillValid) return NodeNativeRecoveryResult.rejected;
      return _isNodeRunning() && _runningBinding() == targetBinding
          ? NodeNativeRecoveryResult.recovered
          : NodeNativeRecoveryResult.retryableFailure;
    });
  }

  /// Recovery used by audits that were not triggered by a native event.
  Future<bool> recoverFromCurrentLease({required String reason}) {
    return _enqueue(() async {
      final target = _desired;
      final targetBinding = target.binding;
      final targetAuthority = target.authority;
      if (!target.acceptingRuntimeWork ||
          targetBinding == null ||
          !targetBinding.productionEligible ||
          targetAuthority == null ||
          !_owns(targetAuthority)) {
        return false;
      }

      final lease = await _loadRecoveryLease();
      if (!_isCurrent(target) ||
          !lease.enabled ||
          !lease.matchesAuthority(targetAuthority) ||
          lease.bindingFingerprint != targetBinding.recoveryFingerprint) {
        return false;
      }

      _updateDesired(
        recoveryArmed: true,
        recoveryRunRequested: true,
      );
      await _reconcileLatest(reason: reason);
      return _isNodeRunning() && _runningBinding() == targetBinding;
    });
  }

  /// Updates operational sleep state without changing the runtime binding.
  Future<void> reportSleepChanged({
    required bool sleeping,
    String reason = 'sleep_changed',
  }) {
    if (!_desired.acceptingRuntimeWork) return Future.value();
    _updateDesired(
      sleeping: sleeping,
      // Native recovery owns its own monitoring window. A later app lifecycle
      // transition must not carry that temporary demand into another cycle.
      recoveryRunRequested: false,
    );
    return _enqueue(() => _reconcileLatest(reason: reason));
  }

  /// Releases the temporary run demand after its monitoring or audit owner
  /// finishes. The durable recovery lease remains armed for future wakes.
  Future<void> completeRecoveryRun({
    required NodeRuntimeAuthority authority,
  }) {
    final current = _desired;
    if (!current.recoveryRunRequested || current.authority != authority) {
      return Future.value();
    }

    _updateDesired(recoveryRunRequested: false);
    return _enqueue(() async {
      final target = _desired;
      if (target.recoveryRunRequested ||
          target.authority != authority ||
          target.runDesired ||
          !_isNodeRunning() ||
          _runningBinding() != target.binding ||
          _runningAuthority() != authority) {
        return;
      }
      await _pauseBackend();
    });
  }

  /// Stops admitting work and blocks until the node and every production
  /// support path have been disarmed.
  Future<void> hardStopForSessionBoundary({required String reason}) {
    _latestBindingRequest += 1;
    _updateDesired(
      clearBinding: true,
      clearAuthority: true,
      intent: PlatformNodeIntent.unset,
      recoveryArmed: false,
      recoveryRunRequested: false,
      acceptingRuntimeWork: false,
    );
    return _enqueue(() async {
      if (_isAndroid()) await _revokeOwnedAuthority();
      await _reconcileLatest(reason: reason);
    });
  }

  /// Reopens admission after the retired runtime has fully drained.
  void resumeAfterSessionBoundary() {
    _updateDesired(acceptingRuntimeWork: true);
  }

  bool _requestIsCurrent(int request, Identity identity) =>
      request == _latestBindingRequest &&
      _desired.acceptingRuntimeWork &&
      IdentitySnapshots.current.sameScopeAs(identity);

  bool _owns(NodeRuntimeAuthority authority) =>
      _ownedAndroidLease?.matchesAuthority(authority) == true;

  Future<NodeRuntimeAuthority?> _authorityForBinding(
    NodeRuntimeBinding? binding,
  ) async {
    final owned = _ownedAndroidLease;
    if (owned == null) return null;

    if (binding == null) {
      await _revokeOwnedAuthority();
      return null;
    }
    if (owned.bindingFingerprint == binding.recoveryFingerprint) {
      return owned.authority;
    }
    if (!_canRebindAndroidAuthority) {
      await _revokeOwnedAuthority();
      return null;
    }

    final mutation = await _reserveRuntimeBinding(
      binding.recoveryFingerprint,
      owned,
    );
    if (!mutation.accepted ||
        mutation.lease.bindingFingerprint != binding.recoveryFingerprint) {
      return null;
    }
    _rememberSupersededAuthority(owned);
    _ownedAndroidLease = mutation.lease;
    return mutation.lease.authority;
  }

  Future<bool> _revokeOwnedAuthority() async {
    final owned = _ownedAndroidLease;
    if (owned == null) return false;
    if (!owned.enabled && owned.bindingFingerprint == null) return true;

    final mutation = await _revokeRecoveryLease(owned);
    if (!mutation.accepted || mutation.lease.bindingFingerprint != null) {
      return false;
    }
    _rememberSupersededAuthority(owned);
    _ownedAndroidLease = mutation.lease;
    return true;
  }

  void _rememberSupersededAuthority(NodeRecoveryLease authority) {
    if (authority.bindingFingerprint == null) return;
    final previous = _supersededAuthorityGeneration;
    if (previous == null || authority.generation > previous) {
      _supersededAuthorityGeneration = authority.generation;
    }
  }

  Future<NodeRuntimeAuthority?> _activateOwnedAuthority(
    NodeRuntimeAuthority authority,
  ) async {
    if (!_owns(authority)) return null;
    final mutation = await _activateRecoveryLease(authority);
    if (!mutation.accepted ||
        !mutation.lease.matchesAuthority(authority) ||
        !mutation.lease.enabled) {
      return null;
    }
    _ownedAndroidLease = mutation.lease;
    return mutation.lease.authority;
  }

  Future<bool> _disableOwnedAuthority(NodeRuntimeAuthority authority) async {
    if (!_owns(authority)) return false;
    final mutation = await _disableRecoveryLease(authority);
    if (!mutation.accepted ||
        !mutation.lease.matchesAuthority(authority) ||
        mutation.lease.enabled) {
      return false;
    }
    _ownedAndroidLease = mutation.lease;
    return true;
  }

  int _updateDesired({
    NodeRuntimeBinding? binding,
    bool clearBinding = false,
    NodeRuntimeAuthority? authority,
    bool clearAuthority = false,
    PlatformNodeIntent? intent,
    bool? sleeping,
    bool? recoveryArmed,
    bool? recoveryRunRequested,
    bool? acceptingRuntimeWork,
  }) {
    final revision = ++_nextRevision;
    _desired = _desired.copyWith(
      revision: revision,
      binding: binding,
      clearBinding: clearBinding,
      authority: authority,
      clearAuthority: clearAuthority,
      intent: intent,
      sleeping: sleeping,
      recoveryArmed: recoveryArmed,
      recoveryRunRequested: recoveryRunRequested,
      acceptingRuntimeWork: acceptingRuntimeWork,
    );
    return revision;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _reconcileLatest({required String reason}) async {
    while (true) {
      final target = _desired;
      await _apply(target, reason: reason);
      if (_isCurrent(target)) return;
    }
  }

  bool _isCurrent(NodeDesiredState target) =>
      _desired.revision == target.revision;

  Future<void> _apply(
    NodeDesiredState target, {
    required String reason,
  }) async {
    final targetBinding = target.binding;
    final targetAuthority = target.authority;
    if (!target.mayKeepRunning || targetBinding == null) {
      await _tearDownRuntime(reason: reason);
      return;
    }
    if (_isAndroid() &&
        (targetAuthority == null ||
            targetAuthority.bindingFingerprint !=
                targetBinding.recoveryFingerprint ||
            !_owns(targetAuthority))) {
      await _tearDownRuntime(reason: 'missing_runtime_authority:$reason');
      return;
    }

    var running = _isNodeRunning();
    final actualBinding = _runningBinding();
    final actualAuthority = _runningAuthority();
    final authorityChanged = _isAndroid() &&
        (actualAuthority == null || actualAuthority != targetAuthority);
    if (running && (actualBinding != targetBinding || authorityChanged)) {
      await _tearDownRuntime(
        reason: actualBinding != targetBinding
            ? 'binding_changed:$reason'
            : 'runtime_authority_changed:$reason',
      );
      if (!_isCurrent(target)) return;
      running = false;
    }

    if (target.sleeping && !target.recoveryRunRequested) {
      if (running) await _pauseBackend();
      return;
    }

    if (target.runDesired && !running) {
      running = await _startBackend(targetBinding, targetAuthority);
      if (!_isCurrent(target)) {
        if (running) await _stopBackend(targetAuthority?.generation);
        return;
      }
    } else if (running) {
      await _resumeBackend();
      if (!_isCurrent(target)) return;
    }

    if (!_isAndroid()) return;

    if (!target.recoveryDesired) {
      await _disarmProductionSupport(
        reason: reason,
        authority: targetAuthority!,
      );
      return;
    }

    if (running) {
      final lease = await _activateOwnedAuthority(targetAuthority!);
      if (!_isCurrent(target) ||
          lease == null ||
          lease.bindingFingerprint != targetBinding.recoveryFingerprint) {
        await _tearDownRuntime(
          reason: 'runtime_authority_superseded:$reason',
        );
        return;
      }
      _enableWatchdogRecovery();
      if (!_isCurrent(target)) return;
      await _onNodeStarted(lease);
      if (!_isCurrent(target)) return;
      // Native recovery dispatches its event-specific monitoring/audit after
      // this authorized start. Starting another audit here can finish before
      // that owner attaches and prematurely release the temporary run demand.
      if (!target.recoveryRunRequested) {
        _auditBestEffort(reason: reason);
      }
      final currentLease = await _loadRecoveryLease();
      if (!_isCurrent(target) ||
          !currentLease.enabled ||
          !currentLease.matchesAuthority(targetAuthority)) {
        await _tearDownRuntime(
          reason: 'runtime_authority_superseded:$reason',
        );
      }
    } else if (target.runDesired) {
      if (target.recoveryRunRequested && target.recoveryDesired) {
        // The delivery and lease were already authorized. Preserve them when
        // startup fails transiently so WorkManager can retry this generation.
        _enableWatchdogRecovery();
      } else {
        _disableWatchdogRecovery();
        await _disableOwnedAuthority(targetAuthority!);
      }
    } else {
      _enableWatchdogRecovery();
    }
  }

  Future<void> _disarmProductionSupport({
    required String reason,
    required NodeRuntimeAuthority authority,
  }) async {
    await _disableOwnedAuthority(authority);
    _disableWatchdogRecovery();
    await _stopMonitoring(reason: reason, authority: authority);
  }

  Future<void> _tearDownRuntime({required String reason}) async {
    final runtimeAuthority = _runningAuthority();
    if (_isAndroid()) {
      _disableWatchdogRecovery();
      await _stopMonitoring(reason: reason, authority: runtimeAuthority);
      final runtimeGeneration = runtimeAuthority?.generation;
      final supersededGeneration = _supersededAuthorityGeneration;
      final retireThrough = runtimeGeneration == null
          ? supersededGeneration
          : supersededGeneration == null ||
                  runtimeGeneration > supersededGeneration
              ? runtimeGeneration
              : supersededGeneration;
      if (retireThrough != null) await _stopBackend(retireThrough);
      return;
    }
    await _stopBackend(null);
  }
}
