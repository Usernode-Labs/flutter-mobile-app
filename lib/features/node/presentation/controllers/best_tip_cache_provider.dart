import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/data/cache/best_tip_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class BestTipUiState {
  final BestTipSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
  const BestTipUiState({required this.snapshot, required this.isCached, required this.isStale});
}

class BestTipUiController extends AsyncNotifier<BestTipUiState?> {
  @override
  Future<BestTipUiState?> build() async {
    // Skip cache loading - fetch only live data
    final status = await RustBackendService.instance.getStatus();
    if (status == null) return null;

    try {
      final bestTip = status.blockchain.bestTip;
      final txs = bestTip.batches.map((b) => b.transactions.toString()).toList();
      final snap = BestTipSnapshot(
        height: bestTip.height,
        hash: bestTip.hash.toString(),
        batchTransactions: txs,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      return BestTipUiState(
        snapshot: snap,
        isCached: false,
        isStale: false,
      );
    } catch (_) {
      // ignore bad parse
      return null;
    }
  }
}

final bestTipUiProvider = AsyncNotifierProvider<BestTipUiController, BestTipUiState?>(
  BestTipUiController.new,
);
