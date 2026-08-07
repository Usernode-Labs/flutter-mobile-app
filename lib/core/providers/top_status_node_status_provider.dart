import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart'
    show TopStatusNodeStatus;
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';

/// Maps a domain sync state to the shared top-status visual state.
TopStatusNodeStatus topStatusNodeStatusFromConnectionState(
  NodeConnectionState? state, {
  TopStatusNodeStatus nullStatus = TopStatusNodeStatus.offline,
}) {
  return switch (state) {
    NodeConnectionState.synced => TopStatusNodeStatus.synced,
    NodeConnectionState.connecting => TopStatusNodeStatus.connecting,
    NodeConnectionState.syncing => TopStatusNodeStatus.syncing,
    NodeConnectionState.error => TopStatusNodeStatus.offline,
    null => nullStatus,
  };
}

/// Maps a nullable [SyncStatus] to the shared top-status visual state.
TopStatusNodeStatus topStatusNodeStatusFromSyncStatus(
  SyncStatus? syncStatus, {
  bool hasRealError = false,
  TopStatusNodeStatus nullStatus = TopStatusNodeStatus.offline,
}) {
  if (hasRealError || (syncStatus?.hasError ?? false)) {
    return TopStatusNodeStatus.offline;
  }

  return topStatusNodeStatusFromConnectionState(
    syncStatus?.state,
    nullStatus: nullStatus,
  );
}

const topStatusChromeSyncingGracePeriod = Duration(seconds: 3);

final topStatusChromeSyncingGracePeriodProvider = Provider<Duration>(
  (ref) => topStatusChromeSyncingGracePeriod,
);

final topStatusChromeRawNodeStatusProvider =
    Provider<TopStatusNodeStatus>((ref) {
  final statusAsync = ref.watch(nodeStatusProvider);
  final syncStatus = statusAsync.valueOrNull?.syncStatus;
  final hasRealError = statusAsync.hasError ||
      (statusAsync.hasValue && statusAsync.value == null);

  return topStatusNodeStatusFromSyncStatus(
    syncStatus,
    hasRealError: hasRealError,
    nullStatus: TopStatusNodeStatus.connecting,
  );
});

/// Chrome-level node status with light hysteresis for tiny `synced`/`syncing`
/// oscillations caused by the 1s node status poll.
final topStatusChromeNodeStatusProvider = StateNotifierProvider<
    TopStatusChromeNodeStatusController, TopStatusNodeStatus>((ref) {
  final controller = TopStatusChromeNodeStatusController(
    syncingGracePeriod: ref.watch(topStatusChromeSyncingGracePeriodProvider),
  );
  ref.listen<TopStatusNodeStatus>(
    topStatusChromeRawNodeStatusProvider,
    (_, next) => controller.updateRawStatus(next),
    fireImmediately: true,
  );
  return controller;
});

class TopStatusChromeNodeStatusController
    extends StateNotifier<TopStatusNodeStatus> {
  TopStatusChromeNodeStatusController({
    required this.syncingGracePeriod,
  }) : super(TopStatusNodeStatus.offline);

  final Duration syncingGracePeriod;
  Timer? _syncingTimer;
  TopStatusNodeStatus? _pendingRawStatus;

  void updateRawStatus(TopStatusNodeStatus rawStatus) {
    _pendingRawStatus = rawStatus;

    if (rawStatus == TopStatusNodeStatus.syncing &&
        state == TopStatusNodeStatus.synced) {
      _syncingTimer ??= Timer(syncingGracePeriod, () {
        _syncingTimer = null;
        if (_pendingRawStatus == TopStatusNodeStatus.syncing) {
          state = TopStatusNodeStatus.syncing;
        }
      });
      return;
    }

    _cancelSyncingTimer();
    if (state != rawStatus) {
      state = rawStatus;
    }
  }

  void _cancelSyncingTimer() {
    _syncingTimer?.cancel();
    _syncingTimer = null;
  }

  @override
  void dispose() {
    _cancelSyncingTimer();
    super.dispose();
  }
}
