import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum NodeSyncTone { connecting, syncing, synced, offline }

class NodeSyncOverviewData {
  const NodeSyncOverviewData({
    required this.statusLabel,
    required this.tone,
    this.chainLabel,
    this.lastCheckedLabel,
    this.copyChainTooltip,
  });

  final String statusLabel;
  final NodeSyncTone tone;
  final String? chainLabel;
  final String? lastCheckedLabel;
  final String? copyChainTooltip;
}

class NodeSyncProgressData {
  const NodeSyncProgressData({
    required this.title,
    required this.percentLabel,
    required this.progress,
    this.supportingLabel,
  });

  final String title;
  final String percentLabel;
  final double progress;
  final String? supportingLabel;
}

class NodeSyncDetailSectionData {
  const NodeSyncDetailSectionData({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<NodeSyncDetailRowData> rows;
}

class NodeSyncDetailRowData {
  const NodeSyncDetailRowData({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final NodeSyncRowTrailing trailing;
  final VoidCallback? onTap;
}

sealed class NodeSyncRowTrailing {
  const NodeSyncRowTrailing();
}

class NodeSyncValueTrailing extends NodeSyncRowTrailing {
  const NodeSyncValueTrailing({
    required this.text,
    this.showChevron = false,
  });

  final String text;
  final bool showChevron;
}

class NodeSyncStatusTrailing extends NodeSyncRowTrailing {
  const NodeSyncStatusTrailing({
    required this.text,
    required this.variant,
  });

  final String text;
  final StatusBadgeVariant variant;
}

class NodeSyncDetailPage extends StatelessWidget {
  const NodeSyncDetailPage({
    super.key,
    required this.title,
    required this.overview,
    required this.progress,
    required this.sections,
    this.onBackTap,
    this.onSettingsTap,
    this.onCopyChainTap,
  });

  final String title;
  final NodeSyncOverviewData overview;
  final NodeSyncProgressData progress;
  final List<NodeSyncDetailSectionData> sections;
  final VoidCallback? onBackTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCopyChainTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // Detail pattern: raw SliverAppBar keeps the shell on white; TopAppBar
          // currently paints the grey scaffold surface.
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.surfaceContainerLowest,
            foregroundColor: colors.onSurface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            toolbarHeight: sizing.iconContainerXLarge,
            leading: IconButton(
              onPressed: onBackTap,
              icon: Icon(
                Symbols.arrow_back_sharp,
                size: sizing.iconRegular,
              ),
            ),
            titleSpacing: 0,
            title: Text(title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Node settings',
                onPressed: onSettingsTap,
                icon: Icon(
                  Symbols.settings_sharp,
                  size: sizing.iconRegular,
                ),
              ),
              SizedBox(width: spacing.space4),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            sliver: SliverList.list(
              children: [
                SizedBox(height: spacing.space24),
                _NodeSyncOverview(
                  data: overview,
                  onCopyChainTap: onCopyChainTap,
                ),
                SizedBox(height: spacing.space32),
                _NodeSyncProgress(data: progress),
                for (final section in sections) ...[
                  SizedBox(height: spacing.space24),
                  _NodeSyncSection(section: section),
                ],
                SizedBox(height: spacing.space32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeSyncOverview extends StatelessWidget {
  const _NodeSyncOverview({
    required this.data,
    this.onCopyChainTap,
  });

  final NodeSyncOverviewData data;
  final VoidCallback? onCopyChainTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final textTheme = theme.textTheme;

    final tone = _toneDisplay(theme, data.tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: spacing.space12,
      children: [
        IconBadge(
          icon: tone.icon,
          size: sizing.iconContainerXLarge,
          surfaceSize: sizing.iconContainerXLarge,
          backgroundColor: tone.background,
          iconColor: tone.foreground,
        ),
        Text(
          data.statusLabel,
          style: textTheme.displaySmall?.copyWith(
            fontFamily: kMonoFontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        if (data.chainLabel != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: spacing.space4,
            children: [
              Flexible(
                child: Text(
                  data.chainLabel!,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (onCopyChainTap != null)
                IconButton(
                  tooltip: data.copyChainTooltip,
                  onPressed: onCopyChainTap,
                  icon: Icon(
                    Symbols.content_copy_sharp,
                    size: sizing.iconSmall,
                  ),
                ),
            ],
          ),
        if (data.lastCheckedLabel != null)
          Text(
            data.lastCheckedLabel!,
            style: textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _NodeSyncProgress extends StatelessWidget {
  const _NodeSyncProgress({required this.data});

  final NodeSyncProgressData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: sizing.iconContainerRegular,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                data.percentLabel,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        AppProgressBar(
          value: data.progress.clamp(0.0, 1.0).toDouble(),
          backgroundColor: colors.surfaceContainerHighest,
          valueColor: colors.primary,
          height: spacing.space8,
        ),
        if (data.supportingLabel != null) ...[
          SizedBox(height: spacing.space4),
          Text(
            data.supportingLabel!,
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _NodeSyncSection extends StatelessWidget {
  const _NodeSyncSection({required this.section});

  final NodeSyncDetailSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: section.title),
        for (final row in section.rows) _NodeSyncRow(row: row),
      ],
    );
  }
}

class _NodeSyncRow extends StatelessWidget {
  const _NodeSyncRow({required this.row});

  final NodeSyncDetailRowData row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final textTheme = theme.textTheme;

    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: sizing.iconContainerRegular),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconBadge(
              icon: row.icon,
              size: sizing.iconContainerSmall,
            ),
            SizedBox(width: spacing.space16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: row.subtitle == null ? 0 : spacing.space4,
                children: [
                  Text(
                    row.title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (row.subtitle != null)
                    Text(
                      row.subtitle!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: spacing.space12),
            _NodeSyncTrailing(trailing: row.trailing),
          ],
        ),
      ),
    );

    if (row.onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: radii.borderRadiusMedium,
      onTap: row.onTap,
      child: content,
    );
  }
}

class _NodeSyncTrailing extends StatelessWidget {
  const _NodeSyncTrailing({required this.trailing});

  final NodeSyncRowTrailing trailing;

  @override
  Widget build(BuildContext context) {
    return switch (trailing) {
      NodeSyncStatusTrailing(:final text, :final variant) =>
        StatusTextTrailing(text: text, variant: variant),
      NodeSyncValueTrailing(:final text, :final showChevron) =>
        showChevron ? TextChevronTrailing(text: text) : Text(text),
    };
  }
}

({IconData icon, Color background, Color foreground}) _toneDisplay(
  ThemeData theme,
  NodeSyncTone tone,
) {
  final colors = theme.colorScheme;
  final semantic = theme.extension<AppSemanticColors>()!;

  return switch (tone) {
    NodeSyncTone.connecting => (
        icon: Symbols.hourglass_empty_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
    NodeSyncTone.syncing => (
        icon: Symbols.sync_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
    NodeSyncTone.synced => (
        icon: Symbols.check_sharp,
        background: semantic.success.colorContainer,
        foreground: semantic.success.onColorContainer,
      ),
    NodeSyncTone.offline => (
        icon: Symbols.close_sharp,
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
      ),
  };
}
