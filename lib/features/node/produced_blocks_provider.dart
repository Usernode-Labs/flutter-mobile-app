import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart';

class ProducedBlocksSummary {
  final double totalScore;
  final int currentEpochSlot;
  final int currentEpoch;
  final int slotsInEpoch;
  final List<EpochScore> epochScores;

  const ProducedBlocksSummary({
    required this.totalScore,
    required this.currentEpochSlot,
    required this.currentEpoch,
    required this.slotsInEpoch,
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

Future<ProducedBlocksSummary> _buildProducedBlocksSummary(Ref ref) async {

    print("GETTING EPOCH DATA");

    final currentEpochResult = await ref.watch(nodeStatusProvider.future);
    final currentEpoch = currentEpochResult?.currentEpoch ?? 0;
    final slotsInEpoch = currentEpochResult?.node.slotsInEpoch ?? 0;
    final currentGlobalSlot = currentEpochResult?.currentGlobalSlot ?? 0;
    final currentEpochSlot = currentGlobalSlot % slotsInEpoch;

    final epochsWithDataResult = await RustBackendService.instance.getEpochsWithData();
    final epochsWithData = epochsWithDataResult?.epochs.toList().toSet() ?? <int>{};

    final epochData = await Future.wait(List<Future<EpochData>>.generate(currentEpoch+1, (index) async {
      if (epochsWithData.contains(index)) {
        final slotStatusResults = await RustBackendService.instance.getEpochSlotResults(epoch: index);
        final slotStatuses = slotStatusResults?.results.toList() ?? <RpcSlotResult>[];
        return EpochData(
          slotData: await Future.wait(List<Future<SlotData>>.generate(slotStatuses.length, (i) async {
            if (i == 0){
              final producedBlockMetadata = _TestRpcProducedBlockMetadata(blockHash: _TestBlockHash('TEST_BLOCK_HASH'), canonical: false, timestampMs: BigInt.zero, tokensWon: BigInt.from(20));
              return SlotData(result: RpcSlotResult.produced, 
                            slotTimeMs: null, 
                            producedBlockMetadata: producedBlockMetadata);
            }
            var slotTimeMs;
            if (slotStatuses[i] == RpcSlotResult.scheduled) {
              slotTimeMs = (await RustBackendService.instance.getSlotTime(epoch: index, slot: i))?.timestampMs;
            }
            var producedBlockMetadata;
            if (slotStatuses[i] == RpcSlotResult.produced) {
              producedBlockMetadata = (await RustBackendService.instance.getProducedBlockMetadata(epoch: index, slot: i))?.metadata;
            }
            return SlotData(result: slotStatuses[i], 
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

    print("currentEpoch: $currentEpoch");
    print("Epoch Data:");

    for (var i = 0; i < epochData.length; i++) {
      print("\tepoch: $i");
      if (epochData[i].slotData != null) {
        var prevResult = epochData[i].slotData![0].result;
        var startIndex = 0;
        for (var j = 0; j < epochData[i].slotData!.length; j++) {
          final currentResult = epochData[i].slotData![j].result;
          if (prevResult == currentResult) {
            continue;
          } else {
            print("\t\tslot: $startIndex -> $j: ${prevResult.name}");
            startIndex = j + 1;
          }
          prevResult = currentResult;
        }
        if (startIndex < epochData[i].slotData!.length) {
          print("\t\tslot: $startIndex -> ${epochData[i].slotData!.length}: ${epochData[i].slotData![startIndex].result.name}");
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

    return ProducedBlocksSummary(
      totalScore: totalScore,
      currentEpochSlot: currentEpochSlot,
      currentEpoch: currentEpoch,
      slotsInEpoch: slotsInEpoch,
      epochScores: epochScores.toList(),
    );
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
