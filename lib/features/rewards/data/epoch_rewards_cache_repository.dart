import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

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

class EpochRewardsCacheRepository {
  static const _keyPrefix = 'rewards:last_snapshot:';

  Future<EpochRewardsSnapshot?> getCached(String envKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$envKey');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return EpochRewardsSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String envKey, EpochRewardsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$envKey', jsonEncode(snapshot.toJson()));
  }
}
