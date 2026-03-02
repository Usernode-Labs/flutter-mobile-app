import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/features/node/screens/widgets/node_status_summary_modal.dart';

/// Icon button that displays current node sync status in the app bar
/// Shows different icons and colors based on sync state:
/// - Connecting: Grey hourglass (hourglass_empty) - no peers
/// - Syncing: Blue rotating sync icon (sync) - syncing with peers
/// - Synced: Green check circle (check_circle) - fully synced
/// - Error: Red error icon (error) - backend error
class NodeStatusIcon extends ConsumerWidget {
  const NodeStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusAsync = ref.watch(nodeStatusProvider);

    // Extract sync status and determine if there's a provider-level error
    final syncStatus = statusAsync.valueOrNull?.syncStatus;
    final providerHasError = statusAsync.when(
      data: (status) => status == null,
      loading: () => false,
      error: (_, __) => true,
    );

    // Determine icon, color, and rotation based on status
    final IconData icon;
    final Color color;
    final bool shouldRotate;

    if (providerHasError || syncStatus == null || syncStatus.hasError) {
      // Error state
      icon = Symbols.error_sharp;
      color = colorScheme.error;
      shouldRotate = false;
    } else if (syncStatus.isConnecting) {
      // Connecting state (no peers)
      icon = Symbols.hourglass_empty_sharp;
      color = colorScheme.outline;
      shouldRotate = false;
    } else if (syncStatus.isSynced) {
      // Synced state
      icon = Symbols.check_circle_sharp;
      color = colorScheme.tertiary;
      shouldRotate = false;
    } else {
      // Syncing state
      icon = Symbols.sync_sharp;
      color = colorScheme.primary;
      shouldRotate = true;
    }

    return IconButton(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: shouldRotate
          ? _RotatingIcon(icon: icon, color: color)
          : Icon(icon, color: color, size: 20),
      onPressed: () {
        showNodeStatusSummaryModal(context);
      },
      tooltip: syncStatus?.label ?? 'Node status',
    );
  }
}

/// Widget that rotates an icon continuously (for syncing state)
class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _RotatingIcon({
    required this.icon,
    required this.color,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 1.0, end: 0.0).animate(_controller),
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}
