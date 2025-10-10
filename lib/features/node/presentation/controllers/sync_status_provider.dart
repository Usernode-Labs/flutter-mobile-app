import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';

class SyncStatus {
  final bool isSynced;
  final String label;
  final double progress; // 0..1 based on heights when available
  const SyncStatus({required this.isSynced, required this.label, required this.progress});
}

final syncStatusProvider = Provider<SyncStatus>((ref) {
  final raw = ref.watch(nodeRawStatusProvider).value;
  final current = raw?.localBestHeight;
  final network = raw?.networkBestHeight;

  // Derive from heights if present
  if (current != null && network != null && network > 0) {
    final synced = current >= network;
    final prog = (current / network).clamp(0.0, 1.0);
    return SyncStatus(
      isSynced: synced,
      label: synced ? 'Synced & Healthy' : 'Syncing',
      progress: prog,
    );
  }

  // Fallback to progress data
  final fetch = raw?.fetchProgress;
  final apply = raw?.applyProgress;
  if (fetch == null && apply == null) {
    return const SyncStatus(isSynced: true, label: 'Synced & Healthy', progress: 1);
  }
  final fetchTotal = ((fetch?.idle ?? BigInt.zero) + (fetch?.pending ?? BigInt.zero) + (fetch?.done ?? BigInt.zero)).toInt();
  final applyTotal = ((apply?.idle ?? BigInt.zero) + (apply?.pending ?? BigInt.zero) + (apply?.done ?? BigInt.zero)).toInt();
  final any = fetchTotal + applyTotal;
  final synced = fetchTotal == 0 && applyTotal == 0;
  return SyncStatus(
    isSynced: synced,
    label: synced ? 'Synced & Healthy' : 'Awaiting Sync',
    progress: synced || any == 0 ? 1.0 : 0.0,
  );
});
