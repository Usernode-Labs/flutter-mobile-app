import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/node/data/cache/best_tip_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class BestTipUiState {
  final BestTipSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
  const BestTipUiState({required this.snapshot, required this.isCached, required this.isStale});
}

final bestTipCacheRepoProvider = Provider((ref) => BestTipCacheRepository());

class BestTipUiController extends AsyncNotifier<BestTipUiState?> {
  @override
  Future<BestTipUiState?> build() async {
    final repo = ref.read(bestTipCacheRepoProvider);
    final envKey = AppConfig.instance.environment;

    final cached = await repo.getCached(envKey);
    BestTipUiState? initial;
    if (cached != null) {
      initial = BestTipUiState(
        snapshot: cached,
        isCached: true,
        isStale: _isStale(cached.updatedAt),
      );
    }

    Future(() async {
      final status = await RustBackendService.instance.getStatus();
      if (status != null) {
        try {
          final bestTip = status.blockchain.bestTip;
          final txs = bestTip.batches.map((b) => b.transactions.toString()).toList();
          final snap = BestTipSnapshot(
            height: bestTip.height,
            hash: bestTip.hash.toString(),
            batchTransactions: txs,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          );
          await repo.save(envKey, snap);
          state = AsyncData(BestTipUiState(snapshot: snap, isCached: false, isStale: false));
        } catch (_) {
          // ignore bad parse
        }
      }
    });

    return initial;
  }

  bool _isStale(String updatedAtIso) {
    try {
      final ts = DateTime.parse(updatedAtIso).toUtc();
      final age = DateTime.now().toUtc().difference(ts);
      return age > const Duration(seconds: 5);
    } catch (_) {
      return true;
    }
  }
}

final bestTipUiProvider = AsyncNotifierProvider<BestTipUiController, BestTipUiState?>(
  BestTipUiController.new,
);
