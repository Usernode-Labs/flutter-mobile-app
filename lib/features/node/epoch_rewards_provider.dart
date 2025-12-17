import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'node_provider.dart';

final _log = LoggingService.instance.withTag('usernode/EpochRewardsProvider');

// --- Cache data model ---

class EpochRewardsSnapshot {
  final int epoch;
  final String earnedSoFar; // BigInt as string
  final String expectedTotal; // BigInt as string
  final int producedInEpoch;
  final int winsInEpoch;
  final String rewardPerBlock; // BigInt as string
  final String updatedAt; // ISO8601
  final List<RpcEpochWonSlot>? wonSlots;

  const EpochRewardsSnapshot({
    required this.epoch,
    required this.earnedSoFar,
    required this.expectedTotal,
    required this.producedInEpoch,
    required this.winsInEpoch,
    required this.rewardPerBlock,
    required this.updatedAt,
    this.wonSlots,
  });

  Map<String, dynamic> toJson() => {
        'epoch': epoch,
        'earnedSoFar': earnedSoFar,
        'expectedTotal': expectedTotal,
        'producedInEpoch': producedInEpoch,
        'winsInEpoch': winsInEpoch,
        'rewardPerBlock': rewardPerBlock,
        'updatedAt': updatedAt,
        'wonSlots': wonSlots
            ?.map((slot) => {
                  'globalSlot': slot.globalSlot,
                  'expectedTimeMs': slot.expectedTimeMs.toString(),
                })
            .toList(),
      };

  static EpochRewardsSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      List<RpcEpochWonSlot>? wonSlots;
      if (json['wonSlots'] != null) {
        wonSlots = (json['wonSlots'] as List)
            .map((slot) => RpcEpochWonSlot(
                  globalSlot: (slot['globalSlot'] as num).toInt(),
                  expectedTimeMs:
                      BigInt.parse(slot['expectedTimeMs'] as String),
                ))
            .toList();
      }
      return EpochRewardsSnapshot(
        epoch: (json['epoch'] as num).toInt(),
        earnedSoFar: json['earnedSoFar'] as String,
        expectedTotal: json['expectedTotal'] as String,
        producedInEpoch: (json['producedInEpoch'] as num).toInt(),
        winsInEpoch: (json['winsInEpoch'] as num).toInt(),
        rewardPerBlock: json['rewardPerBlock'] as String,
        updatedAt: json['updatedAt'] as String,
        wonSlots: wonSlots,
      );
    } catch (_) {
      return null;
    }
  }
}

// --- State and Controller ---

/// Unified epoch rewards state combining raw data and UI state
class EpochRewardsState {
  // Raw backend data
  final RpcEpochRewardsResp? rawData;

  // UI state with caching
  final EpochRewardsSnapshot? snapshot;
  final bool isCached;
  final bool isStale;

  const EpochRewardsState({
    required this.rawData,
    required this.snapshot,
    required this.isCached,
    required this.isStale,
  });

  // Convenience getters for direct raw data access
  int? get epoch => rawData?.epoch;
  BigInt? get earnedSoFar => rawData?.earnedSoFar;
  BigInt? get expectedTotal => rawData?.expectedTotal;
  int? get producedInEpoch => rawData?.producedInEpoch;
  int? get winsInEpoch => rawData?.winsInEpoch;
  BigInt? get rewardPerBlock => rawData?.rewardPerBlock;
  List<RpcEpochWonSlot> get wonSlots => rawData?.wonSlots ?? const [];
}

/// Unified epoch rewards controller
class EpochRewardsController extends AsyncNotifier<EpochRewardsState?> {
  BigInt? _previousEarnedSoFar;
  static const String _cacheKey = 'rewards:last_snapshot:default';

  @override
  Future<EpochRewardsState?> build() async {
    // Read status to get epoch value (use read, not watch, to avoid rebuilds on every status update)
    final statusAsync = ref.read(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;

    // Step 1: Load cache immediately to show previous data (only on initial build)
    _log.debug('Loading cached epoch rewards...');
    final cached = await _getCached();

    // Step 2: Return cache if available (avoids empty UI while loading)
    if (cached != null) {
      _log.trace(
        'Loaded cached data: epoch=${cached.epoch}, earnedSoFar=${cached.earnedSoFar}',
      );

      // Immediately return cached data (no raw data yet)
      state = AsyncData(EpochRewardsState(
        rawData: null,
        snapshot: cached,
        isCached: true,
        isStale: false,
      ));
    }

    // Step 3: Fetch live data in background
    if (epoch == null) return state.value;
    return await _load(epoch);
  }

  Future<void> refresh() async {
    final statusAsync = ref.read(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;

    if (epoch == null) {
      state = const AsyncData(null);
      return;
    }

    state = await AsyncValue.guard(() => _load(epoch));
  }

  Future<EpochRewardsState?> _load(int epoch) async {
    try {
      _log.debug('Fetching live epoch rewards for epoch $epoch...');

      final rewards =
          await RustBackendService.instance.epochRewards(epoch: epoch);

      if (rewards == null) {
        _log.warn('epochRewards returned null');
        // Return current state if live fetch failed
        return state.value;
      }

      _log.info(
        '[EpochRewards] Backend returned: epoch=${rewards.epoch}, '
        'producedInEpoch=${rewards.producedInEpoch}, '
        'winsInEpoch=${rewards.winsInEpoch}, '
        'wonSlots.length=${rewards.wonSlots?.length ?? 0}',
      );

      // Create snapshot for caching
      final snapshot = EpochRewardsSnapshot(
        epoch: rewards.epoch,
        earnedSoFar: rewards.earnedSoFar.toString(),
        expectedTotal: rewards.expectedTotal.toString(),
        producedInEpoch: rewards.producedInEpoch,
        winsInEpoch: rewards.winsInEpoch,
        rewardPerBlock: rewards.rewardPerBlock.toString(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        wonSlots: rewards.wonSlots,
      );

      _log.trace(
        'Created snapshot: earnedSoFar=${snapshot.earnedSoFar}, expectedTotal=${snapshot.expectedTotal}',
      );

      // Save to cache
      try {
        await _saveToCache(snapshot);
        _log.trace('Saved epoch rewards to cache');
      } catch (e, st) {
        _log.error('Failed to save epoch rewards to cache',
            error: e, stackTrace: st);
      }

      // Check if rewards increased and trigger notification
      _checkAndNotifyRewardIncrease(rewards.earnedSoFar, rewards.epoch);

      // Return unified state with both raw data and snapshot
      return EpochRewardsState(
        rawData: rewards,
        snapshot: snapshot,
        isCached: false,
        isStale: false,
      );
    } catch (e, st) {
      _log.error('Failed to load epoch rewards', error: e, stackTrace: st);
      rethrow;
    }
  }

  void _checkAndNotifyRewardIncrease(BigInt earnedSoFar, int epoch) {
    if (_previousEarnedSoFar != null && earnedSoFar > _previousEarnedSoFar!) {
      final diff = earnedSoFar - _previousEarnedSoFar!;
      _log.trace('Reward increased by $diff TKN');
    }
    _previousEarnedSoFar = earnedSoFar;
  }

  // --- Inline cache methods ---

  Future<EpochRewardsSnapshot?> _getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return EpochRewardsSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(EpochRewardsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
  }
}

final epochRewardsProvider =
    AsyncNotifierProvider<EpochRewardsController, EpochRewardsState?>(
  EpochRewardsController.new,
);
