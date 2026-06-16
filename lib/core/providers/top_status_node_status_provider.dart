import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart'
    show TopStatusNodeStatus;
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';

/// Maps the live node sync state to the [TopStatusNodeStatus] shown by the
/// shared top bar (`TopStatusAppBar`) across the Challenges / Wallet / dApps
/// root screens. `error` or not-yet-loaded resolves to offline.
final topStatusNodeStatusProvider = Provider<TopStatusNodeStatus>((ref) {
  final state = ref.watch(
    nodeStatusProvider.select((s) => s.valueOrNull?.syncStatus.state),
  );
  return switch (state) {
    NodeConnectionState.synced => TopStatusNodeStatus.synced,
    NodeConnectionState.connecting ||
    NodeConnectionState.syncing =>
      TopStatusNodeStatus.connecting,
    NodeConnectionState.error || null => TopStatusNodeStatus.offline,
  };
});
