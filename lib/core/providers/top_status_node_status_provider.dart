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

/// Maps the live node sync state to the [TopStatusNodeStatus] shown by the
/// shared top bar (`TopStatusAppBar`) across the Challenges / Wallet / dApps
/// root screens. `error` or not-yet-loaded resolves to offline.
final topStatusNodeStatusProvider = Provider<TopStatusNodeStatus>((ref) {
  final state = ref.watch(
    nodeStatusProvider.select((s) => s.valueOrNull?.syncStatus.state),
  );
  return topStatusNodeStatusFromConnectionState(state);
});
