import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// Size variant for [TopStatusAppBar].
enum TopStatusAppBarSize {
  /// Native Material 3 large top app bar with expanded title.
  large,

  /// Native Material 3 compact top app bar.
  compact,
}

/// Node status surfaced by [TopStatusAppBar].
enum TopStatusNodeStatus {
  /// Node is connected and synced.
  synced,

  /// Node is connecting or catching up.
  connecting,

  /// Node is offline.
  offline,
}

const _kTopStatusLargeCollapsedHeight = 64.0;
const _kTopStatusLargeExpandedHeight = 152.0;

const _kTopStatusSurfaceKey = ValueKey('top_status_app_bar_surface');
const _kTopStatusBottomBorderKey = ValueKey('top_status_app_bar_bottom_border');
const _kTopStatusProfileHitKey = ValueKey('top_status_profile_action_hit');
const _kTopStatusProfileVisualKey =
    ValueKey('top_status_profile_action_visual');
const _kTopStatusProfileIconKey = ValueKey('top_status_profile_action_icon');
const _kTopStatusProfileLabelOpacityKey =
    ValueKey('top_status_profile_action_label_opacity');
const _kTopStatusNodeHitKey = ValueKey('top_status_node_action_hit');
const _kTopStatusNodeVisualKey = ValueKey('top_status_node_action_visual');
const _kTopStatusNodeIconKey = ValueKey('top_status_node_action_icon');
const _kTopStatusNodeLabelOpacityKey =
    ValueKey('top_status_node_action_label_opacity');

/// A native Material 3 sliver top app bar with profile and node-status actions.
///
/// The widget delegates top inset handling, pinning, title placement, and large
/// title collapse to Flutter's Material app bar implementations. Only the
/// profile/node action slots are product-specific.
class TopStatusAppBar extends StatelessWidget {
  /// Creates a large M3 top status app bar.
  const TopStatusAppBar.large({
    super.key,
    required this.title,
    required this.onProfilePressed,
    required this.onNodePressed,
    this.profileLabel = 'Profile',
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.backgroundColor,
    this.forceTransparent = false,
  }) : size = TopStatusAppBarSize.large;

  /// Creates a compact M3 top status app bar.
  const TopStatusAppBar.compact({
    super.key,
    required this.title,
    required this.onProfilePressed,
    required this.onNodePressed,
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.backgroundColor,
    this.forceTransparent = false,
  })  : size = TopStatusAppBarSize.compact,
        profileLabel = null;

  /// Visible screen title.
  final String title;

  /// Size variant.
  final TopStatusAppBarSize size;

  /// Optional label shown in the large profile pill.
  final String? profileLabel;

  /// Current node status.
  final TopStatusNodeStatus nodeStatus;

  /// Opens the profile entry point.
  final VoidCallback? onProfilePressed;

  /// Opens node status details.
  final VoidCallback? onNodePressed;

  /// Optional app-bar background override.
  final Color? backgroundColor;

  /// Uses transparent Material for floating previews.
  final bool forceTransparent;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TopStatusAppBarSize.large => _buildLarge(context),
      TopStatusAppBarSize.compact => _buildCompact(context),
    };
  }

  Widget _buildLarge(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveSurface = backgroundColor ?? colors.surfaceContainerLowest;
    final node = _NodeStatusVisual.resolve(context, nodeStatus);
    final topPadding = MediaQuery.paddingOf(context).top;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _TopStatusLargeAppBarDelegate(
        title: title,
        profileLabel: profileLabel ?? 'Profile',
        node: node,
        onProfilePressed: onProfilePressed,
        onNodePressed: onNodePressed,
        backgroundColor: effectiveSurface,
        forceTransparent: forceTransparent,
        topPadding: topPadding,
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final effectiveBackground = forceTransparent
        ? Colors.transparent
        : backgroundColor ?? colors.surfaceContainerLowest;
    final node = _NodeStatusVisual.resolve(context, nodeStatus);

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leadingWidth: spacing.space16 + sizing.iconContainerRegular,
      leading: Padding(
        padding: EdgeInsetsDirectional.only(start: spacing.space16),
        child: _TopStatusAction(
          icon: Symbols.account_circle_sharp,
          label: 'Profile',
          tooltip: 'Profile',
          onPressed: onProfilePressed,
          progress: 1,
          showLabel: false,
          alignment: AlignmentDirectional.centerStart,
          hitKey: _kTopStatusProfileHitKey,
          visualKey: _kTopStatusProfileVisualKey,
          iconKey: _kTopStatusProfileIconKey,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        _TopStatusAction(
          icon: node.icon,
          label: node.label,
          tooltip: node.tooltip,
          foregroundColor: node.foregroundColor,
          onPressed: onNodePressed,
          progress: 1,
          showLabel: false,
          alignment: AlignmentDirectional.centerEnd,
          hitKey: _kTopStatusNodeHitKey,
          visualKey: _kTopStatusNodeVisualKey,
          iconKey: _kTopStatusNodeIconKey,
        ),
      ],
      actionsPadding: EdgeInsetsDirectional.only(end: spacing.space16),
      backgroundColor: effectiveBackground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shape: forceTransparent
          ? null
          : Border(
              bottom: BorderSide(
                color: colors.onSurface.withValues(alpha: borders.opacity),
                width: borders.width,
              ),
            ),
      forceMaterialTransparency: forceTransparent,
    );
  }
}

class _TopStatusLargeAppBarDelegate extends SliverPersistentHeaderDelegate {
  const _TopStatusLargeAppBarDelegate({
    required this.title,
    required this.profileLabel,
    required this.node,
    required this.onProfilePressed,
    required this.onNodePressed,
    required this.backgroundColor,
    required this.forceTransparent,
    required this.topPadding,
  });

  final String title;
  final String profileLabel;
  final _NodeStatusVisual node;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onNodePressed;
  final Color backgroundColor;
  final bool forceTransparent;
  final double topPadding;

  @override
  double get minExtent => topPadding + _kTopStatusLargeCollapsedHeight;

  @override
  double get maxExtent => topPadding + _kTopStatusLargeExpandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final titleSideInset = sizing.iconContainerRegular + spacing.space24;
    final surfaceColor = forceTransparent
        ? Colors.transparent
        : Color.lerp(Colors.transparent, backgroundColor, progress)!;
    final collapsedBorderColor = colors.onSurface.withValues(
      alpha: borders.opacity,
    );
    final borderColor = forceTransparent
        ? Colors.transparent
        : Color.lerp(Colors.transparent, collapsedBorderColor, progress)!;

    return Material(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ColoredBox(key: _kTopStatusSurfaceKey, color: surfaceColor),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: borders.width,
            child: ColoredBox(
              key: _kTopStatusBottomBorderKey,
              color: borderColor,
            ),
          ),
          PositionedDirectional(
            top: topPadding + spacing.space8,
            start: spacing.space16,
            child: _TopStatusAction(
              icon: Symbols.account_circle_sharp,
              label: profileLabel,
              tooltip: 'Profile',
              onPressed: onProfilePressed,
              progress: progress,
              alignment: AlignmentDirectional.centerStart,
              hitKey: _kTopStatusProfileHitKey,
              visualKey: _kTopStatusProfileVisualKey,
              iconKey: _kTopStatusProfileIconKey,
              labelOpacityKey: _kTopStatusProfileLabelOpacityKey,
            ),
          ),
          PositionedDirectional(
            top: topPadding + spacing.space8,
            end: spacing.space16,
            child: _TopStatusAction(
              icon: node.icon,
              label: node.label,
              tooltip: node.tooltip,
              foregroundColor: node.foregroundColor,
              onPressed: onNodePressed,
              progress: progress,
              iconAfterLabel: true,
              alignment: AlignmentDirectional.centerEnd,
              hitKey: _kTopStatusNodeHitKey,
              visualKey: _kTopStatusNodeVisualKey,
              iconKey: _kTopStatusNodeIconKey,
              labelOpacityKey: _kTopStatusNodeLabelOpacityKey,
            ),
          ),
          PositionedDirectional(
            top: topPadding,
            start: titleSideInset,
            end: titleSideInset,
            height: _kTopStatusLargeCollapsedHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: progress,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: spacing.space16,
            end: spacing.space16,
            bottom: spacing.space24 + spacing.space4,
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - progress,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TopStatusLargeAppBarDelegate oldDelegate) {
    return title != oldDelegate.title ||
        profileLabel != oldDelegate.profileLabel ||
        node != oldDelegate.node ||
        onProfilePressed != oldDelegate.onProfilePressed ||
        onNodePressed != oldDelegate.onNodePressed ||
        backgroundColor != oldDelegate.backgroundColor ||
        forceTransparent != oldDelegate.forceTransparent ||
        topPadding != oldDelegate.topPadding;
  }
}

class _TopStatusAction extends StatelessWidget {
  const _TopStatusAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.progress,
    required this.alignment,
    required this.hitKey,
    required this.visualKey,
    required this.iconKey,
    this.labelOpacityKey,
    this.foregroundColor,
    this.iconAfterLabel = false,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final double progress;
  final AlignmentGeometry alignment;
  final Key hitKey;
  final Key visualKey;
  final Key iconKey;
  final Key? labelOpacityKey;
  final Color? foregroundColor;
  final bool iconAfterLabel;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final t = progress.clamp(0.0, 1.0);
    final labelProgress = showLabel ? 1 - t : 0.0;
    final iconSize = lerpDouble(sizing.iconSmall, sizing.iconRegular, t)!;
    final horizontalPadding = lerpDouble(spacing.space16, spacing.space8, t)!;
    final gap = spacing.space8 * labelProgress;
    final enabled = onPressed != null;
    final minVisualWidth = lerpDouble(
      sizing.iconContainerXLarge,
      sizing.iconContainerSmall,
      t,
    )!;
    final effectiveForeground = enabled
        ? foregroundColor ?? colors.onSecondaryContainer
        : colors.onSurface.withValues(alpha: 0.38);
    final effectiveBackground = enabled
        ? colors.secondaryContainer
        : colors.onSurface.withValues(alpha: 0.12);
    final labelWidget = showLabel
        ? _MorphingStatusActionLabel(
            label: label,
            progress: labelProgress,
            opacityKey: labelOpacityKey,
            style: textTheme.labelLarge?.copyWith(color: effectiveForeground),
          )
        : null;
    final iconWidget = Icon(
      icon,
      key: iconKey,
      size: iconSize,
      color: effectiveForeground,
    );
    final children = iconAfterLabel
        ? <Widget>[
            if (labelWidget != null) labelWidget,
            if (labelWidget != null) SizedBox(width: gap),
            iconWidget,
          ]
        : <Widget>[
            iconWidget,
            if (labelWidget != null) SizedBox(width: gap),
            if (labelWidget != null) labelWidget,
          ];

    return Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        key: hitKey,
        constraints: BoxConstraints(
          minWidth: sizing.iconContainerRegular,
          minHeight: sizing.iconContainerRegular,
        ),
        child: Align(
          alignment: alignment,
          child: Material(
            key: visualKey,
            color: effectiveBackground,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minVisualWidth),
                child: SizedBox(
                  height: sizing.buttonHeightSmall,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingStatusActionLabel extends StatelessWidget {
  const _MorphingStatusActionLabel({
    required this.label,
    required this.progress,
    required this.style,
    this.opacityKey,
  });

  final String label;
  final double progress;
  final TextStyle? style;
  final Key? opacityKey;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        widthFactor: progress,
        child: Opacity(
          key: opacityKey,
          opacity: progress,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _NodeStatusVisual {
  const _NodeStatusVisual({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color? foregroundColor;

  @override
  bool operator ==(Object other) {
    return other is _NodeStatusVisual &&
        other.icon == icon &&
        other.label == label &&
        other.tooltip == tooltip &&
        other.foregroundColor == foregroundColor;
  }

  @override
  int get hashCode => Object.hash(icon, label, tooltip, foregroundColor);

  static _NodeStatusVisual resolve(
    BuildContext context,
    TopStatusNodeStatus status,
  ) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return switch (status) {
      TopStatusNodeStatus.synced => const _NodeStatusVisual(
          icon: Symbols.check_circle_sharp,
          label: 'Synced',
          tooltip: 'Node synced',
        ),
      TopStatusNodeStatus.connecting => _NodeStatusVisual(
          icon: Symbols.sync_sharp,
          label: 'Connecting',
          tooltip: 'Node connecting',
          foregroundColor: semantic.technical.color,
        ),
      TopStatusNodeStatus.offline => _NodeStatusVisual(
          icon: Symbols.wifi_off_sharp,
          label: 'Offline',
          tooltip: 'Node offline',
          foregroundColor: colors.error,
        ),
    };
  }
}
