import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/node/screens/widgets/node_status_summary_modal.dart';

/// Icon button that displays current node sync status as a compact circle
/// using the shared [TopStatusNodeVisual] mapping.
class NodeStatusIcon extends ConsumerWidget {
  const NodeStatusIcon({super.key});

  /// Visible coloured circle diameter. The IconButton's tap target stays at
  /// the DS 48dp minimum; the circle just sits inside.
  static const double _badgeSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sizing = theme.extension<AppSizing>()!;
    final statusAsync = ref.watch(nodeStatusProvider);

    // Extract sync status. Note: a null syncStatus means we're still loading
    // (or briefly between refetches) — that is NOT a hard error and must not
    // surface the red error icon. Real errors come from `statusAsync.hasError`,
    // an explicit `data: null` payload, or the shared mapper seeing an error
    // sync state.
    final syncStatus = statusAsync.valueOrNull?.syncStatus;
    final hasRealError = statusAsync.hasError ||
        (statusAsync.hasValue && statusAsync.value == null);
    final visualStatus = topStatusNodeStatusFromSyncStatus(
      syncStatus,
      hasRealError: hasRealError,
      nullStatus: TopStatusNodeStatus.connecting,
    );
    final visual = TopStatusNodeVisual.resolve(
      context,
      visualStatus,
      intent: TopStatusNodeVisualIntent.chrome,
    );

    return IconButton(
      constraints: BoxConstraints(
        minWidth: sizing.iconContainerRegular,
        minHeight: sizing.iconContainerRegular,
      ),
      padding: EdgeInsets.zero,
      icon: Container(
        width: _badgeSize,
        height: _badgeSize,
        decoration: BoxDecoration(
          color: visual.backgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          visual.icon,
          color: visual.foregroundColor,
          size: sizing.iconSmall,
        ),
      ),
      onPressed: () {
        showNodeStatusSummaryModal(context);
      },
      tooltip: visual.tooltip,
    );
  }
}
