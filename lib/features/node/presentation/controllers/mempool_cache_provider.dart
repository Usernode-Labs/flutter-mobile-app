import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/node/data/cache/mempool_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class MempoolUiState {
  final MempoolSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
  const MempoolUiState({required this.snapshot, required this.isCached, required this.isStale});
}

final mempoolCacheRepoProvider = Provider((ref) => MempoolCacheRepository());

class MempoolUiController extends AsyncNotifier<MempoolUiState?> {
  @override
  Future<MempoolUiState?> build() async {
    final repo = ref.read(mempoolCacheRepoProvider);
    final envKey = AppConfig.instance.environment;

    final cached = await repo.getCached(envKey);
    MempoolUiState? initial;
    if (cached != null) {
      initial = MempoolUiState(
        snapshot: cached,
        isCached: true,
        isStale: _isStale(cached.updatedAt),
      );
    }

    Future(() async {
      final live = await RustBackendService.instance.listMempool();
      if (live != null) {
        final snap = MempoolSnapshot(
          count: live.count.toString(),
          orphans: live.orphans.toString(),
          totalSize: live.totalSize.toString(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await repo.save(envKey, snap);
        state = AsyncData(MempoolUiState(snapshot: snap, isCached: false, isStale: false));
      }
    });

    return initial;
  }

  bool _isStale(String updatedAtIso) {
    try {
      final ts = DateTime.parse(updatedAtIso).toUtc();
      final age = DateTime.now().toUtc().difference(ts);
      return age > const Duration(seconds: 10);
    } catch (_) {
      return true;
    }
  }
}

final mempoolUiProvider = AsyncNotifierProvider<MempoolUiController, MempoolUiState?>(
  MempoolUiController.new,
);

