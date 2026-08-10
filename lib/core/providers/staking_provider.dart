import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/staking_preference_store.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

final _log = LoggingService.instance.withTag('usernode/Staking');

/// The only delegation target currently supported by the product.
const kServerDelegateAddress =
    'B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG';

enum StakingMode { active, delegated }

class StakingState {
  const StakingState({
    required this.mode,
    this.delegateAddress,
    this.delegatedSince,
  });

  const StakingState.active()
      : mode = StakingMode.active,
        delegateAddress = null,
        delegatedSince = null;

  final StakingMode mode;
  final String? delegateAddress;

  /// ISO-8601 start of the current delegation period, as reported by the
  /// backend. Null while delegation is disabled or before backend hydration.
  final String? delegatedSince;

  bool get isDelegated => mode == StakingMode.delegated;

  /// Public bridge representation.
  ///
  /// A null delegate means delegation is disabled; a non-null delegate is
  /// the address currently receiving the wallet's delegated stake.
  Map<String, dynamic> toBridgeJson() => {
        'delegate': delegateAddress,
        'delegated_since': delegatedSince,
      };

  @override
  bool operator ==(Object other) =>
      other is StakingState &&
      other.mode == mode &&
      other.delegateAddress == delegateAddress &&
      other.delegatedSince == delegatedSince;

  @override
  int get hashCode => Object.hash(mode, delegateAddress, delegatedSince);
}

/// Owns one identity bucket's durable staking choice and backend flag.
///
/// The on-chain delegation transaction remains mocked. The backend flag,
/// bucket-scoped preference, and node producer configuration are real.
class StakingController extends StateNotifier<StakingState> {
  StakingController({
    required StakingPreferenceStore store,
    Future<DelegationStatus> Function(bool delegated)? syncBackend,
    Future<DelegationStatus?> Function()? fetchBackend,
    Future<void> Function()? applyNodeEffects,
    bool Function()? isScopeCurrent,
    bool hydrate = true,
  })  : _store = store,
        _syncBackend = syncBackend,
        _fetchBackend = fetchBackend,
        _applyNodeEffects = applyNodeEffects,
        _isScopeCurrent = isScopeCurrent ?? (() => true),
        super(const StakingState.active()) {
    ready = hydrate ? _hydrate() : Future<void>.value();
    unawaited(ready);
  }

  final StakingPreferenceStore _store;
  final Future<DelegationStatus> Function(bool delegated)? _syncBackend;
  final Future<DelegationStatus?> Function()? _fetchBackend;
  final Future<void> Function()? _applyNodeEffects;
  final bool Function() _isScopeCurrent;
  late final Future<void> ready;
  int _revision = 0;

  Future<void> _hydrate() async {
    final revision = _revision;
    try {
      final address = await _store.loadDelegateAddress();
      if (!_canApply(revision)) return;
      state = address == null
          ? const StakingState.active()
          : StakingState(mode: StakingMode.delegated, delegateAddress: address);
    } catch (error) {
      _log.debug('Failed to hydrate staking preference: $error');
    }

    final fetch = _fetchBackend;
    if (fetch == null || !_canApply(revision)) return;
    try {
      final status = await fetch();
      if (status == null || !_canApply(revision)) return;
      final target = status.delegated ? kServerDelegateAddress : null;
      final delegatedSince = status.delegated ? status.delegatedSince : null;
      if (status.delegated == state.isDelegated &&
          (!status.delegated || state.delegateAddress == target) &&
          state.delegatedSince == delegatedSince) {
        return;
      }
      await _store.setDelegateAddress(target);
      if (!_canApply(revision)) return;
      state = status.delegated
          ? StakingState(
              mode: StakingMode.delegated,
              delegateAddress: kServerDelegateAddress,
              delegatedSince: delegatedSince,
            )
          : const StakingState.active();
    } catch (error) {
      _log.debug('Skipping delegation reconciliation: $error');
    }
  }

  bool _canApply(int revision) =>
      mounted && revision == _revision && _isScopeCurrent();

  Future<void> delegate() async {
    final revision = ++_revision;
    _log.info('Delegating stake to the server');
    final status = await _syncBackend?.call(true);
    await _store.setDelegateAddress(kServerDelegateAddress);
    if (!_canApply(revision)) return;
    state = StakingState(
      mode: StakingMode.delegated,
      delegateAddress: kServerDelegateAddress,
      delegatedSince: status?.delegatedSince,
    );
    _applyNodeEffectsInBackground();
  }

  Future<void> undelegate() async {
    final revision = ++_revision;
    _log.info('Returning stake to this node');
    await _syncBackend?.call(false);
    await _store.setDelegateAddress(null);
    if (!_canApply(revision)) return;
    state = const StakingState.active();
    _applyNodeEffectsInBackground();
  }

  void _applyNodeEffectsInBackground() {
    final effect = _applyNodeEffects?.call();
    if (effect == null) return;
    unawaited(
      effect.catchError((Object error, StackTrace stackTrace) {
        _log.error(
          'Delegation node reconfiguration failed',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }
}

final stakingProvider = StateNotifierProvider<StakingController, StakingState>((
  ref,
) {
  final identity = ref.watch(identityProvider);
  final api = ref.watch(leaderboardApiServiceProvider);
  final address = identity.address;
  final canUseBackend = identity.phase == IdentityPhase.ready &&
      address != null &&
      address.isNotEmpty;

  return StakingController(
    store: StakingPreferenceStore(bucket: identity.bucket),
    syncBackend: canUseBackend
        ? (delegated) => api.setDelegation(
              walletAddress: address,
              delegated: delegated,
            )
        : (_) => Future<DelegationStatus>.error(
              StateError('Delegation requires a ready authenticated wallet'),
            ),
    fetchBackend:
        canUseBackend ? () => api.getDelegation(walletAddress: address) : null,
    isScopeCurrent: () => identity.sameScopeAs(ref.read(identityProvider)),
    applyNodeEffects: () => NodeLifecycleCoordinator.instance
        .reconfigureForDelegationChange(reason: 'staking_changed'),
  );
});
