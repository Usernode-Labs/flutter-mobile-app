import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
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

  /// True if the backend (or cache) reported any epochs with data.
  /// When false, the node likely hasn't produced or indexed any blocks yet.
  final bool hasEpochsWithData;

  const ProducedBlocksSummary({
    required this.totalScore,
    required this.currentEpochSlot,
    required this.currentEpoch,
    required this.slotsInEpoch,
    required this.rewardsPerBlock,
    required this.maxEpochWithData,
    required this.epochScores,
    required this.hasEpochsWithData,
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
  const SlotData(
      {required this.result, this.slotTimeMs, this.producedBlockMetadata});
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

final _log = LoggingService.instance.withTag('usernode/ProducedBlocksProvider');

const _kEpochsWithDataKeyBase = 'node:epochs_with_data';
const _kProducedBlockMetadataKeyPrefixBase = 'node:produced_block_metadata';
const _kEpochSlotResultsKeyPrefixBase = 'node:epoch_slot_results';
const _kSlotTimeKeyPrefixBase = 'node:slot_time';

String networkPrefix = '';

// Network-prefixed keys
String get _kEpochsWithDataKey =>
    NetworkPrefs.prefixAccountKey('$_kEpochsWithDataKeyBase:$networkPrefix');
String get _kProducedBlockMetadataKeyPrefix => NetworkPrefs.prefixAccountKey(
    '$_kProducedBlockMetadataKeyPrefixBase:$networkPrefix');
String get _kEpochSlotResultsKeyPrefix => NetworkPrefs.prefixAccountKey(
    '$_kEpochSlotResultsKeyPrefixBase:$networkPrefix');
String get _kSlotTimeKeyPrefix =>
    NetworkPrefs.prefixAccountKey('$_kSlotTimeKeyPrefixBase:$networkPrefix');

Future<ProducedBlocksSummary> _buildProducedBlocksSummary(Ref ref) async {
  final stopwatch = Stopwatch()..start();
  _log.trace('ProducedBlocksSummary: build start');

  _log.trace("GETTING EPOCH DATA");

  // Centralized pre-work for this provider (status, and future additions).
  final preWorkResult = await _buildProducedBlocksPreWork();
  // this was very slow, so using pre work above instead
  //final currentEpochResult = await ref.watch(nodeStatusProvider.future);
  final currentEpoch = preWorkResult['currentEpoch'];
  final slotsInEpoch = preWorkResult['slotsInEpoch'];
  final currentGlobalSlot = preWorkResult['currentGlobalSlot'];
  final currentEpochSlot = preWorkResult['currentSlot'];

  final epochsWithData = await persistedGetEpochsWithData();

  final maxEpochWithDataAPI = epochsWithData.isEmpty
      ? currentEpoch
      : epochsWithData.reduce((int a, int b) => a > b ? a : b);

  final maxEpochWithData = math.max<int>(maxEpochWithDataAPI, currentEpoch);

  final epochsToGenerate =
      maxEpochWithData + 1; // +1 to account for epochs starting at 0

  final epochData = await Future.wait(
      List<Future<EpochData>>.generate(epochsToGenerate, (index) async {
    if (epochsWithData.contains(index)) {
      final slotStatuses = await persistedGetEpochSlotResults(
          index, slotsInEpoch, currentGlobalSlot);
      return EpochData(
          slotData: await Future.wait(
        List<Future<SlotData>>.generate(slotStatuses.length, (slot) async {
          BigInt? slotTimeMs;
          if (slotStatuses[slot] == RpcSlotResult.scheduled ||
              slotStatuses[slot] == RpcSlotResult.missed ||
              slotStatuses[slot] == RpcSlotResult.produced ||
              slotStatuses[slot] == RpcSlotResult.orphaned) {
            slotTimeMs = await persistedGetSlotTime(index, slot);
          }
          RpcProducedBlockMetadata? producedBlockMetadata;
          if (slotStatuses[slot] == RpcSlotResult.produced ||
              slotStatuses[slot] == RpcSlotResult.orphaned) {
            producedBlockMetadata =
                await persistedGetProducedBlockMetadata(index, slot);
          }
          return SlotData(
              result: slotStatuses[slot],
              slotTimeMs: slotTimeMs,
              producedBlockMetadata: producedBlockMetadata);
        }),
      ));
    } else {
      return const EpochData(
        slotData: null,
      );
    }
  }));

  _log.trace("currentEpoch: $currentEpoch");
  _log.trace("Epoch Data:");

  for (var i = 0; i < epochData.length; i++) {
    _log.trace("\tepoch: $i");
    if (epochData[i].slotData != null) {
      var prevResult = epochData[i].slotData![0].result;
      var startIndex = 0;
      for (var j = 0; j < epochData[i].slotData!.length; j++) {
        final currentResult = epochData[i].slotData![j].result;
        if (prevResult == currentResult) {
          continue;
        } else {
          _log.trace("\t\tslot: $startIndex -> $j: ${prevResult.name}");
          startIndex = j + 1;
        }
        prevResult = currentResult;
      }
      if (startIndex < epochData[i].slotData!.length) {
        _log.trace(
            "\t\tslot: $startIndex -> ${epochData[i].slotData!.length}: ${epochData[i].slotData![startIndex].result.name}");
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
      final producedCount = epoch.slotData!
          .where((slot) =>
              slot.result == RpcSlotResult.produced ||
              slot.result == RpcSlotResult.orphaned)
          .length;
      final missedCount = epoch.slotData!
          .where((slot) => slot.result == RpcSlotResult.missed)
          .length;
      final upcomingCount = epoch.slotData!
          .where((slot) => slot.result == RpcSlotResult.scheduled)
          .length;
      final notCalculatedCount = epoch.slotData!
          .where((slot) => slot.result == RpcSlotResult.notCalculated)
          .length;
      final calculatedCount = slotsInEpoch - notCalculatedCount;
      final wonCount = producedCount + missedCount + upcomingCount;

      return EpochScore(
        evaluatedPercent: calculatedCount / slotsInEpoch,
        producedOfEvaluatedPercent:
            wonCount > 0 ? producedCount / (producedCount + missedCount) : 1.0,
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

  // Consider that we "have epochs with data" only if there exists at least one
  // slot in any epoch whose status is something other than NotCalculated.
  // This is more robust than just checking the backend epochs list, which may
  // include epochs that are still entirely unevaluated.
  final bool hasEpochsWithData = epochData.any((epoch) {
    final slots = epoch.slotData;
    if (slots == null || slots.isEmpty) return false;
    return slots.any((slot) => slot.result != RpcSlotResult.notCalculated);
  });

  final totalScore = epochScores
      .map((epoch) => epoch.evaluatedPercent * epoch.producedOfEvaluatedPercent)
      .reduce((a, b) => a * b);

  stopwatch.stop();
  _log.trace(
      'ProducedBlocksSummary: build completed in ${stopwatch.elapsedMilliseconds} ms');

  return ProducedBlocksSummary(
    totalScore: totalScore,
    currentEpochSlot: currentEpochSlot,
    currentEpoch: currentEpoch,
    slotsInEpoch: slotsInEpoch,
    rewardsPerBlock: _rewardsPerBlock,
    maxEpochWithData: maxEpochWithData,
    epochScores: epochScores.toList(),
    hasEpochsWithData: hasEpochsWithData,
  );
}

RpcStatusNode? _initialStatusNode;
int _initialTimestampMs =
    0; // When using genesis, this represents the computed genesis timestamp (ms since epoch).
bool _initialFromGenesis = false;
BigInt _rewardsPerBlock = BigInt.zero;

Future<dynamic> _buildProducedBlocksPreWork() async {
  final localNowMs = DateTime.now().millisecondsSinceEpoch;
  int? rustNowMs;

  // Prefer a time-based model anchored at the chain genesis timestamp.
  // We compute genesis once from status.bestTip and reuse it, so subsequent
  // calls avoid the expensive status RPC and simply advance time locally.
  // TODO this should be simplified with a more direct / faster RPC call or a
  // way to get the current global slot directly.
  if (_initialStatusNode == null || _initialTimestampMs == 0) {
    try {
      final status =
          await RustBackendService.instance.getStatus(includeVrfDetails: false);
      final node = status?.node;
      final blockchain = status?.blockchain;
      rustNowMs = node?.timeMs.toInt();

      if (status != null && node != null && blockchain != null) {
        _initialStatusNode = node;
        final bestTip = blockchain.bestTip;
        final slotMs = node.blockInterval;
        final bestGlobalSlot = bestTip.globalSlot; // int
        final bestTimestamp = bestTip.timestamp; // BigInt (ms)

        // genesisMs = bestTip.timestamp - bestTip.globalSlot * slotMs
        // TODO get this from the backend instead of using bestTip, see
        // comment above about time to get current global slot
        final genesisMsBig =
            bestTimestamp - BigInt.from(bestGlobalSlot * slotMs);
        _initialTimestampMs = genesisMsBig.toInt();
        _initialFromGenesis = true;
        _log.trace('Computed genesis timestampMs=$_initialTimestampMs');
      } else {
        // Fallback: we couldn't get full status; fall back to node-only snapshot.
        _initialStatusNode ??=
            await RustBackendService.instance.getStatusNode();
        _initialTimestampMs = localNowMs;
        _initialFromGenesis = false;
        _log.warn(
            'Failed to compute genesis timestamp; falling back to local snapshot time');
      }
    } catch (e, st) {
      _log.error(
        'Error initializing ProducedBlocks pre-work; falling back to local snapshot time',
        error: e,
        stackTrace: st,
      );
      _initialStatusNode ??= await RustBackendService.instance.getStatusNode();
      _initialTimestampMs = localNowMs;
      _initialFromGenesis = false;
    }
  }

  rustNowMs ??= await RustBackendService.instance.resolveCurrentRustTimeMs();

  // TODO this should include the hash of the genesis block
  if (networkPrefix == '') {
    final networkType = await RustBackendService.instance.getSelectedNetwork();
    networkPrefix = networkType.name;
  }

  // Ensure we have node status before proceeding
  final statusNode = _initialStatusNode;
  if (statusNode == null) {
    _log.warn(
        'Node status unavailable, trying to use genesis timestamp fallback');

    // Try to use genesis timestamp as fallback
    final genesisTimestamp =
        await RustBackendService.instance.getGenesisTimestamp();
    if (genesisTimestamp != null) {
      _log.debug('Using genesis timestamp fallback: $genesisTimestamp ms');
      _initialTimestampMs = genesisTimestamp;
      _initialFromGenesis = true;

      // Use default values for missing node status
      final nowMs = rustNowMs ?? localNowMs;
      const defaultSlotMs = 5000; // 5 seconds default slot duration
      const defaultSlotsInEpoch = 17280; // 17280 slots per epoch default

      final currentGlobalSlot = (nowMs - _initialTimestampMs) ~/ defaultSlotMs;
      final currentEpoch = currentGlobalSlot ~/ defaultSlotsInEpoch;
      final currentSlot = currentGlobalSlot % defaultSlotsInEpoch;

      _log.debug(
          'Using fallback values: slot=$defaultSlotMs ms, slotsInEpoch=$defaultSlotsInEpoch');

      return {
        'currentGlobalSlot': currentGlobalSlot,
        'currentEpoch': currentEpoch,
        'currentSlot': currentSlot,
        'slotsInEpoch': defaultSlotsInEpoch,
        'slotMs': defaultSlotMs,
        'rewardsPerBlock': _rewardsPerBlock
      };
    }

    throw StateError(
        'Cannot build produced blocks: node status unavailable and genesis timestamp fallback failed. Is the backend running?');
  }

  final slotMs = statusNode.blockInterval;

  // TODO; would use currentGlobalSlot, but node status api is slow to
  // update (~2 seconds on my device), so using this instead. Should be
  // replaced by a faster call to the backend
  int currentGlobalSlot;
  if (_initialFromGenesis) {
    // Time since genesis, divided by slot duration.
    final nowMs = rustNowMs ?? localNowMs;
    currentGlobalSlot =
        slotMs > 0 ? (nowMs - _initialTimestampMs) ~/ slotMs : 0;
  } else {
    // Legacy behavior: advance from the snapshot slot using wall-clock delta.
    final passedTime = localNowMs - _initialTimestampMs;
    final curSlot = statusNode.curGlobalSlot;
    if (curSlot == null) {
      throw StateError(
          'Cannot build produced blocks: current global slot unavailable');
    }
    currentGlobalSlot = curSlot + (slotMs > 0 ? passedTime ~/ slotMs : 0);
  }
  int slotsInEpoch = statusNode.slotsInEpoch;
  int currentEpoch = slotsInEpoch > 0 ? currentGlobalSlot ~/ slotsInEpoch : 0;
  int currentSlot = slotsInEpoch > 0 ? currentGlobalSlot % slotsInEpoch : 0;

  //final upToDateStatus = await RustBackendService.instance.getStatusNode();

  //print('epoch start: ${_initialStatusNode!.curGlobalSlot! ~/ slotsInEpoch}');
  //print('epoch start slot: ${_initialStatusNode!.curGlobalSlot! % slotsInEpoch}');
  //print('current epoch: $currentEpoch');
  //print('current slot: $currentSlot');
  //print('_initialTimestampMs: $_initialTimestampMs');
  //print('_initialFromGenesis: $_initialFromGenesis');
  //print('nowMs: $nowMs');
  //print('current global slot: $currentGlobalSlot');
  //print('actual current global slot: ${upToDateStatus!.curGlobalSlot}');

  if (_rewardsPerBlock == BigInt.zero) {
    final rewards =
        await RustBackendService.instance.epochRewards(epoch: currentEpoch);
    if (rewards != null) {
      _rewardsPerBlock = rewards.rewardPerBlock;
    }
  }

  return {
    'currentGlobalSlot': currentGlobalSlot,
    'currentEpoch': currentEpoch,
    'currentSlot': currentSlot,
    'slotsInEpoch': slotsInEpoch,
    'slotMs': slotMs,
    'rewardsPerBlock': _rewardsPerBlock
  };
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
    int epoch, int slotsInEpoch, int currentGlobalSlot) async {
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
    if (idx != null && idx >= 0 && idx < RpcSlotResult.values.length) {
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

  for (var i = 0; i < slotsInEpoch; i++) {
    final slot = epoch * slotsInEpoch + i;
    if ((slot < currentGlobalSlot) && combined[i] == RpcSlotResult.scheduled) {
      combined[i] = RpcSlotResult
          .missed; // assume we missed the slot, since the backend wasn't able to tell us whether it was produced or not
    }
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

/// Convenience helper to fetch slot time with caching.
Future<BigInt?> persistedGetSlotTime(int epoch, int slot) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_kSlotTimeKeyPrefix:$epoch:$slot';

  // Try to read from local cache first
  final cachedTimestamp = prefs.getString(key);
  if (cachedTimestamp != null) {
    try {
      return BigInt.parse(cachedTimestamp);
    } catch (e, st) {
      _log.error(
        'Error decoding cached slot time for $epoch/$slot: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  // Fallback to backend if nothing (or invalid) in cache
  final slotTimeResponse = await RustBackendService.instance.getSlotTime(
    epoch: epoch,
    slot: slot,
  );
  final timestampMs = slotTimeResponse?.timestampMs;

  // Store fetched timestamp back to cache for future reads
  if (timestampMs != null) {
    try {
      await prefs.setString(key, timestampMs.toString());
    } catch (e, st) {
      _log.error(
        'Error caching slot time for $epoch/$slot: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  return timestampMs;
}

final producedBlocksSummaryProvider =
    FutureProvider<ProducedBlocksSummary>(_buildProducedBlocksSummary);

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
