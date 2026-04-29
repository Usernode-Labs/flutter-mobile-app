import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/features/node/screens/widgets/node_status_summary_modal.dart';

/// Icon button that displays current node sync status as a colored circle
/// (`*.colorContainer`) with a centered icon (`*.onColorContainer`) inside.
/// This matches the icon-in-pill convention used on the Node Status page,
/// and reads as "green / amber / red" much more legibly than a foreground
/// color on a transparent background at AppBar sizes.
///
/// State -> visual:
/// - Error: red circle with an X (Symbols.close_sharp).
/// - Loading / Connecting: amber circle with a rotating sync icon.
/// - Syncing: amber circle with a rotating sync icon.
/// - Synced: green circle with a check (Symbols.check_sharp).
///
/// Loading and connecting share the same visual on purpose: from the user's
/// perspective both mean "we're working on it, hold on". The tooltip
/// (`syncStatus.label`) carries the more specific text.
///
/// Background hues come from [AppSemanticColors] `*.colorContainer` and
/// `colorScheme.errorContainer`; the icon is drawn in the matching
/// `*.onColorContainer` / `colorScheme.onErrorContainer`. This keeps the
/// design system's "structural roles are grey; chromatic comes from the
/// semantic extension" rule intact.
class NodeStatusIcon extends ConsumerWidget {
  const NodeStatusIcon({super.key});

  /// Visible coloured circle diameter. The IconButton's tap target stays at
  /// 40x40 so accessibility isn't compromised; the circle just sits inside.
  static const double _badgeSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final sizing = theme.extension<AppSizing>()!;
    final statusAsync = ref.watch(nodeStatusProvider);

    // Extract sync status. Note: a null syncStatus means we're still loading
    // (or briefly between refetches) — that is NOT a hard error and must not
    // surface the red error icon. Real errors come from `statusAsync.hasError`,
    // an explicit `data: null` payload, or `syncStatus.hasError`.
    final syncStatus = statusAsync.valueOrNull?.syncStatus;
    final hasRealError = statusAsync.hasError ||
        (statusAsync.hasValue && statusAsync.value == null) ||
        (syncStatus?.hasError ?? false);

    final IconData icon;
    final Color backgroundColor;
    final Color foregroundColor;
    final bool shouldRotate;

    if (hasRealError) {
      icon = Symbols.close_sharp;
      backgroundColor = colorScheme.errorContainer;
      foregroundColor = colorScheme.onErrorContainer;
      shouldRotate = false;
    } else if (syncStatus == null || syncStatus.isConnecting) {
      icon = Symbols.sync_sharp;
      backgroundColor = semantic.warning.colorContainer;
      foregroundColor = semantic.warning.onColorContainer;
      shouldRotate = true;
    } else if (syncStatus.isSynced) {
      icon = Symbols.check_sharp;
      backgroundColor = semantic.success.colorContainer;
      foregroundColor = semantic.success.onColorContainer;
      shouldRotate = false;
    } else {
      icon = Symbols.sync_sharp;
      backgroundColor = semantic.warning.colorContainer;
      foregroundColor = semantic.warning.onColorContainer;
      shouldRotate = true;
    }

    final iconWidget = shouldRotate
        ? _RotatingIcon(
            icon: icon, color: foregroundColor, size: sizing.iconSmall)
        : Icon(icon, color: foregroundColor, size: sizing.iconSmall);

    return IconButton(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      icon: Container(
        width: _badgeSize,
        height: _badgeSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: iconWidget,
      ),
      onPressed: () {
        showNodeStatusSummaryModal(context);
      },
      tooltip: syncStatus?.label ?? 'Node status',
    );
  }
}

/// Widget that rotates an icon continuously (for syncing/connecting states).
class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RotatingIcon({
    required this.icon,
    required this.color,
    required this.size,
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
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
