import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class ProducedBlocksSummary {
  final double totalScore;
  final int currentEpochSlot;
  final int currentEpoch;
  final int slotsInEpoch;
  final BigInt rewardsPerBlock;
  final int maxEpochWithData;
  final List<EpochScore> epochScores;

  const ProducedBlocksSummary({
    required this.totalScore,
    required this.currentEpochSlot,
    required this.currentEpoch,
    required this.slotsInEpoch,
    required this.rewardsPerBlock,
    required this.maxEpochWithData,
    required this.epochScores,
  });
}

class EpochData {
  final List<SlotData>? slotData;
  const EpochData({required this.slotData});
}

class SlotData {
  final RpcSlotResult result;
  final BigInt? slotTimeMs;
  final RpcProducedBlockMetadata? producedBlockMetadata;
  const SlotData({required this.result, this.slotTimeMs, this.producedBlockMetadata});
}

class EpochScore {
  final double evaluatedPercent;
  final double producedOfEvaluatedPercent;
  final int? won;
  final int produced;
  final int? missed;
  final int? upcoming;
  final int notCalculated;
  final int calculated;
  final EpochData epochData;

  const EpochScore({
    required this.evaluatedPercent,
    required this.producedOfEvaluatedPercent,
    required this.won,
    required this.produced,
    required this.missed,
    required this.upcoming,
    required this.notCalculated,
    required this.calculated,
    required this.epochData,
  });
}

final _log = LoggingService.instance.withTag(LogTag.node);

const _kEpochsWithDataKey = 'node:epochs_with_data';
const _kProducedBlockMetadataKeyPrefix = 'node:produced_block_metadata';
const _kEpochSlotResultsKeyPrefix = 'node:epoch_slot_results';

Future<ProducedBlocksSummary> _buildProducedBlocksSummary(Ref ref) async {
  final stopwatch = Stopwatch()..start();
  _log.debug('ProducedBlocksSummary: build start');

    _log.debug("GETTING EPOCH DATA");

    // Centralized pre-work for this provider (status, and future additions).
    final preWorkResult = await _buildProducedBlocksPreWork();
    // this was very slow, so using pre work above instead
    //final currentEpochResult = await ref.watch(nodeStatusProvider.future);
    final currentEpoch = preWorkResult['currentEpoch'];
    final slotsInEpoch = preWorkResult['slotsInEpoch'];
    final currentEpochSlot = preWorkResult['currentSlot'];

    final epochsWithData = await persistedGetEpochsWithData();

    final maxEpochWithDataAPI = epochsWithData.isEmpty
        ? currentEpoch
        : epochsWithData.reduce((int a, int b) => a > b ? a : b);

    final maxEpochWithData =
        math.max<int>(maxEpochWithDataAPI, currentEpoch);

    final epochsToGenerate = maxEpochWithData + 1; // +1 to account for epochs starting at 0

    final epochData = await Future.wait(List<Future<EpochData>>.generate(epochsToGenerate, (index) async {
      if (epochsWithData.contains(index)) {
        final slotStatuses = await persistedGetEpochSlotResults(index, slotsInEpoch);
        return EpochData(
          slotData: await Future.wait(List<Future<SlotData>>.generate(slotStatuses.length, (slot) async {
            //if (i == 0){
            //  final producedBlockMetadata = _TestRpcProducedBlockMetadata(blockHash: _TestBlockHash('TEST_BLOCK_HASH'), canonical: false, timestampMs: BigInt.zero, tokensWon: BigInt.from(20));
            //  return SlotData(result: RpcSlotResult.produced, 
            //                slotTimeMs: null, 
            //                producedBlockMetadata: producedBlockMetadata);
            //}
            var slotTimeMs;
            if (slotStatuses[slot] == RpcSlotResult.scheduled) {
              slotTimeMs = (await RustBackendService.instance.getSlotTime(epoch: index, slot: slot))?.timestampMs;
            }
            var producedBlockMetadata;
            if (slotStatuses[slot] == RpcSlotResult.produced) {
              producedBlockMetadata = await persistedGetProducedBlockMetadata(index, slot);
            }
            return SlotData(result: slotStatuses[slot], 
                            slotTimeMs: slotTimeMs, 
                            producedBlockMetadata: producedBlockMetadata);
          }),
        ));
      } else {
        return EpochData(
          slotData: null,
        );
      }
    }));

    _log.debug("currentEpoch: $currentEpoch");
    _log.debug("Epoch Data:");

    for (var i = 0; i < epochData.length; i++) {
      _log.debug("\tepoch: $i");
      if (epochData[i].slotData != null) {
        var prevResult = epochData[i].slotData![0].result;
        var startIndex = 0;
        for (var j = 0; j < epochData[i].slotData!.length; j++) {
          final currentResult = epochData[i].slotData![j].result;
          if (prevResult == currentResult) {
            continue;
          } else {
            _log.debug("\t\tslot: $startIndex -> $j: ${prevResult.name}");
            startIndex = j + 1;
          }
          prevResult = currentResult;
        }
        if (startIndex < epochData[i].slotData!.length) {
          _log.debug("\t\tslot: $startIndex -> ${epochData[i].slotData!.length}: ${epochData[i].slotData![startIndex].result.name}");
        }
      }
    }

    final epochScores = epochData.map((epoch) {
      if (epoch.slotData == null) {
        return EpochScore(
          evaluatedPercent: 0.0,
          producedOfEvaluatedPercent: 0.0,
          won: null,
          produced: 0,
          missed: null,
          upcoming: null,
          notCalculated: slotsInEpoch,
          calculated: 0,
          epochData: epoch,
        );
      } else {
        final producedCount = epoch.slotData!.where((slot) => slot.result == RpcSlotResult.produced).length;
        final missedCount = epoch.slotData!.where((slot) => slot.result == RpcSlotResult.missed).length;
        final upcomingCount = epoch.slotData!.where((slot) => slot.result == RpcSlotResult.scheduled).length;
        final notCalculatedCount = epoch.slotData!.where((slot) => slot.result == RpcSlotResult.notCalculated).length;
        final calculatedCount = slotsInEpoch - notCalculatedCount;
        final wonCount = producedCount + missedCount + upcomingCount;

        return EpochScore(
          evaluatedPercent: calculatedCount / slotsInEpoch,
          producedOfEvaluatedPercent: wonCount > 0 ? producedCount / (producedCount + missedCount) : 1.0,
          won: wonCount,
          produced: producedCount,
          missed: missedCount,
          upcoming: upcomingCount,
          notCalculated: notCalculatedCount,
          calculated: calculatedCount,
          epochData: epoch,
        );
      }
    });

    final totalScore = epochScores.map((epoch) => epoch.evaluatedPercent*epoch.producedOfEvaluatedPercent)
                                  .reduce((a, b) => a * b);

    stopwatch.stop();
    _log.debug('ProducedBlocksSummary: build completed in ${stopwatch.elapsedMilliseconds} ms');

    return ProducedBlocksSummary(
      totalScore: totalScore,
      currentEpochSlot: currentEpochSlot,
      currentEpoch: currentEpoch,
      slotsInEpoch: slotsInEpoch,
      rewardsPerBlock: _rewardsPerBlock,
      maxEpochWithData: maxEpochWithData,
      epochScores: epochScores.toList(),
    );
}


RpcStatusNode? _initialStatusNode;
int _initialTimestampMs = 0;
BigInt _rewardsPerBlock = BigInt.zero;

Future<dynamic> _buildProducedBlocksPreWork() async {
  if (_initialStatusNode == null) {
    _initialStatusNode = await RustBackendService.instance.getStatusNode();
    _initialTimestampMs = DateTime.now().millisecondsSinceEpoch;
  }
  if (_initialTimestampMs == 0) {
    _initialTimestampMs = DateTime.now().millisecondsSinceEpoch;
  }

  int passedTime = DateTime.now().millisecondsSinceEpoch - _initialTimestampMs;
  final slotMs = _initialStatusNode!.blockInterval;

  int currentGlobalSlot = _initialStatusNode!.curGlobalSlot! + (passedTime ~/ slotMs);
  int slotsInEpoch = _initialStatusNode!.slotsInEpoch;
  int currentEpoch = currentGlobalSlot ~/ slotsInEpoch;
  int currentSlot = currentGlobalSlot % slotsInEpoch;

  if (_rewardsPerBlock == BigInt.zero) {
    final rewards =
        await RustBackendService.instance.epochRewards(epoch: currentEpoch);
    if (rewards != null) {
      _rewardsPerBlock = rewards.rewardPerBlock;
    }
  }

  return { 'currentGlobalSlot': currentGlobalSlot, 
           'currentEpoch': currentEpoch, 
           'currentSlot': currentSlot, 
           'slotsInEpoch': slotsInEpoch, 
           'slotMs': slotMs,
           'rewardsPerBlock': _rewardsPerBlock };
}

 Future<Set<int>> persistedGetEpochsWithData() async {
  // Fetch epochs with data from backend
  final epochsWithDataResult =
      await RustBackendService.instance.getEpochsWithData();
  final backendEpochs =
      epochsWithDataResult?.epochs.toList().toSet() ?? <int>{};

  // Load any previously persisted epochs with data
  final prefs = await SharedPreferences.getInstance();
  final persistedList = prefs.getStringList(_kEpochsWithDataKey) ?? <String>[];
  final persistedEpochs =
      persistedList.map((e) => int.tryParse(e)).whereType<int>().toSet();

  // Union of backend + persisted epochs
  final allEpochsWithData = <int>{...backendEpochs, ...persistedEpochs};

  // Persist the union back to local storage
  await prefs.setStringList(
    _kEpochsWithDataKey,
    allEpochsWithData.map((e) => e.toString()).toList(),
  );

  return allEpochsWithData;
 }

Future<List<RpcSlotResult>> persistedGetEpochSlotResults(
    int epoch, int slotsInEpoch) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_kEpochSlotResultsKeyPrefix:$epoch';

  // Fetch from backend
  final slotStatusResults =
      await RustBackendService.instance.getEpochSlotResults(epoch: epoch);
  final backendStatuses =
      slotStatusResults?.results.toList() ?? <RpcSlotResult>[];

  // Load cached results, stored as indices into RpcSlotResult.values
  final cachedList = prefs.getStringList(key) ?? const <String>[];
  final List<RpcSlotResult?> cachedStatuses =
      List<RpcSlotResult?>.filled(slotsInEpoch, null, growable: false);
  for (var i = 0; i < slotsInEpoch && i < cachedList.length; i++) {
    final raw = cachedList[i];
    final idx = int.tryParse(raw);
    if (idx != null &&
        idx >= 0 &&
        idx < RpcSlotResult.values.length) {
      cachedStatuses[i] = RpcSlotResult.values[idx];
    }
  }

  // Combine backend + cache according to rules
  final List<RpcSlotResult> combined =
      List<RpcSlotResult>.filled(slotsInEpoch, RpcSlotResult.notCalculated);

  for (var i = 0; i < slotsInEpoch; i++) {
    final RpcSlotResult? backend =
        i < backendStatuses.length ? backendStatuses[i] : null;
    final RpcSlotResult? cached = cachedStatuses[i];

    RpcSlotResult value;

    if (backend == null) {
      // 2) If a slot is in neither backend nor cached, we return NotCalculated
      // 3) If a slot comes back from cached but not backend, we take the one from cached
      value = cached ?? RpcSlotResult.notCalculated;
    } else if (backend == RpcSlotResult.notCalculated) {
      // 4) If backend says NotCalculated but cache has something else, use cache
      if (cached != null && cached != RpcSlotResult.notCalculated) {
        value = cached;
      } else {
        value = backend;
      }
    } else {
      // 5) Otherwise we take the value from Backend
      value = backend;
    }

    combined[i] = value;
  }

  // Persist the combined results back to cache
  try {
    final toStore = combined
        .map((r) => RpcSlotResult.values.indexOf(r).toString())
        .toList(growable: false);
    await prefs.setStringList(key, toStore);
  } catch (e, st) {
    _log.error(
      'Error caching epoch slot results for epoch $epoch: $e',
      error: e,
      stackTrace: st,
    );
  }

  return combined;
}

Future<RpcProducedBlockMetadata?> persistedGetProducedBlockMetadata(
    int epoch, int slot) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_kProducedBlockMetadataKeyPrefix:$epoch:$slot';

  // Try to read from local cache first
  final cachedJson = prefs.getString(key);
  if (cachedJson != null) {
    try {
      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      final metadata = _TestRpcProducedBlockMetadata(
        blockHash: _TestBlockHash(data['blockHash'] as String),
        canonical: data['canonical'] as bool,
        timestampMs: BigInt.parse(data['timestampMs'] as String),
        tokensWon: BigInt.parse(data['tokensWon'] as String),
      );
      return metadata;
    } catch (e, st) {
      _log.error(
        'Error decoding cached produced block metadata for $epoch/$slot: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  // Fallback to backend if nothing (or invalid) in cache
  final producedBlockMetadata =
      (await RustBackendService.instance.getProducedBlockMetadata(
    epoch: epoch,
    slot: slot,
  ))
          ?.metadata;

  // Store fetched metadata back to cache for future reads
  if (producedBlockMetadata != null) {
    try {
      final serializable = <String, dynamic>{
        'blockHash': producedBlockMetadata.blockHash.toString(),
        'canonical': producedBlockMetadata.canonical,
        'timestampMs': producedBlockMetadata.timestampMs.toString(),
        'tokensWon': producedBlockMetadata.tokensWon.toString(),
      };
      await prefs.setString(key, jsonEncode(serializable));
    } catch (e, st) {
      _log.error(
        'Error caching produced block metadata for $epoch/$slot: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  return producedBlockMetadata;
}

final producedBlocksSummaryProvider =
    FutureProvider.autoDispose<ProducedBlocksSummary>(
        _buildProducedBlocksSummary);

/// Simple stand-in implementations for testing UI without relying on backend metadata.
class _TestBlockHash implements BlockHash {
  final String value;
  _TestBlockHash(this.value);

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  String toString() => value;
}

class _TestRpcProducedBlockMetadata implements RpcProducedBlockMetadata {
  @override
  BlockHash blockHash;

  @override
  bool canonical;

  @override
  BigInt timestampMs;

  @override
  BigInt tokensWon;

  _TestRpcProducedBlockMetadata({
    required this.blockHash,
    required this.canonical,
    required this.timestampMs,
    required this.tokensWon,
  });

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
  }

  @override
  bool get isDisposed => _isDisposed;
}
