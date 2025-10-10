import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/core/result.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class NodeStatusController extends AsyncNotifier<NodeStatus?> {
  Timer? _timer;

  @override
  Future<NodeStatus?> build() async {
    final repo = ref.read(nodeRepositoryProvider);
    // Initial fetch
    final res = await repo.getStatus();
    if (res.isErr) {
      throw res.err!;
    }
    final status = res.ok;

    // Periodic refresh every 2 minutes (matched to screen's previous behavior)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) async {
      final r = await repo.getStatus();
      if (r.isOk) {
        state = AsyncData(r.ok);
      } else {
        state = AsyncError(r.err!, StackTrace.current);
      }
    });

    ref.onDispose(() => _timer?.cancel());
    return status;
  }

  Future<void> refresh() async {
    final repo = ref.read(nodeRepositoryProvider);
    state = const AsyncLoading();
    final r = await repo.getStatus();
    if (r.isOk) {
      state = AsyncData(r.ok);
    } else {
      state = AsyncError(r.err!, StackTrace.current);
    }
  }
}

final nodeStatusProvider =
    AsyncNotifierProvider<NodeStatusController, NodeStatus?>(
  NodeStatusController.new,
);
