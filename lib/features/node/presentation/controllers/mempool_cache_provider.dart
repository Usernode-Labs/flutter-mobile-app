import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/data/cache/mempool_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class MempoolUiState {
  final MempoolSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
  const MempoolUiState(
      {required this.snapshot, required this.isCached, required this.isStale});
}

class MempoolUiController extends AsyncNotifier<MempoolUiState?> {
  @override
  Future<MempoolUiState?> build() async {
    // Skip cache loading - fetch only live data
    final live = await RustBackendService.instance.listMempool();
    if (live == null) return null;

    final snap = MempoolSnapshot(
      count: live.count.toString(),
      orphans: live.orphans.toString(),
      totalSize: live.totalSize.toString(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    return MempoolUiState(
      snapshot: snap,
      isCached: false,
      isStale: false,
    );
  }
}

final mempoolUiProvider =
    AsyncNotifierProvider<MempoolUiController, MempoolUiState?>(
  MempoolUiController.new,
);
