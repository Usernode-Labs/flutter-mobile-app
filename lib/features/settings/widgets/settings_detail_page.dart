import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum SettingsDetailStatusTone { allGood, attention }

enum SettingsDetailRowType { navigation, status, toggle, action }

class SettingsDetailStatusData {
  const SettingsDetailStatusData({
    required this.label,
    required this.headline,
    required this.tone,
    this.description,
    this.rows = const <SettingsDetailRowData>[],
  });

  final String label;
  final String headline;
  final SettingsDetailStatusTone tone;
  final String? description;
  final List<SettingsDetailRowData> rows;
}

class SettingsDetailSectionData {
  const SettingsDetailSectionData({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<SettingsDetailRowData> rows;
}

class SettingsDetailRowData {
  const SettingsDetailRowData.navigation({
    required this.icon,
    required this.title,
    this.subtitle,
    this.valueLabel,
    this.onTap,
  })  : type = SettingsDetailRowType.navigation,
        statusLabel = null,
        statusVariant = null,
        switchValue = null,
        onSwitchChanged = null,
        actionLabel = null;

  const SettingsDetailRowData.status({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.statusVariant,
    this.subtitle,
    this.onTap,
  })  : type = SettingsDetailRowType.status,
        valueLabel = null,
        switchValue = null,
        onSwitchChanged = null,
        actionLabel = null;

  const SettingsDetailRowData.toggle({
    required this.icon,
    required this.title,
    required this.switchValue,
    required this.onSwitchChanged,
    this.subtitle,
  })  : type = SettingsDetailRowType.toggle,
        valueLabel = null,
        statusLabel = null,
        statusVariant = null,
        actionLabel = null,
        onTap = null;

  const SettingsDetailRowData.action({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onTap,
    this.subtitle,
  })  : type = SettingsDetailRowType.action,
        valueLabel = null,
        statusLabel = null,
        statusVariant = null,
        switchValue = null,
        onSwitchChanged = null;

  final SettingsDetailRowType type;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? valueLabel;
  final String? statusLabel;
  final StatusBadgeVariant? statusVariant;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final String? actionLabel;
  final VoidCallback? onTap;
}

class SettingsDetailPage extends StatelessWidget {
  const SettingsDetailPage({
    super.key,
    required this.title,
    required this.status,
    required this.sections,
    this.onBackTap,
    this.onSettingsTap,
  });

  final String title;
  final SettingsDetailStatusData status;
  final List<SettingsDetailSectionData> sections;
  final VoidCallback? onBackTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.surfaceContainerLowest,
            foregroundColor: colors.onSurface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
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
                tooltip: title,
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
                SizedBox(height: spacing.space16),
                _SettingsStatusSurface(data: status),
                SizedBox(height: spacing.space24),
                for (final section in sections) ...[
                  _SettingsSection(section: section),
                  SizedBox(height: spacing.space24),
                ],
                SizedBox(height: spacing.space8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsStatusSurface extends StatelessWidget {
  const _SettingsStatusSurface({required this.data});

  final SettingsDetailStatusData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final group = data.tone == SettingsDetailStatusTone.allGood
        ? semantic.success
        : semantic.warning;

    return AppCard(
      color: group.colorSurface,
      elevation: 0,
      borderRadius: radii.borderRadiusLargeIncreased,
      padding: EdgeInsets.symmetric(vertical: spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.space8,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: group.onColorSurface,
                  ),
                ),
                Text(
                  data.headline,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: group.onColorSurface,
                    fontFamily: kMonoFontFamily,
                  ),
                ),
                if (data.description != null)
                  Text(
                    data.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: group.onColorSurface,
                    ),
                  ),
              ],
            ),
          ),
          if (data.rows.isNotEmpty) ...[
            SizedBox(height: spacing.space12),
            ListTileTheme(
              iconColor: colors.onSurface,
              textColor: colors.onSurface,
              child: Column(
                children: [
                  for (final row in data.rows)
                    _SettingsRow(
                      row: row,
                      horizontalInset: spacing.space16,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.section});

  final SettingsDetailSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: section.title),
        for (final row in section.rows) _SettingsRow(row: row),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.row,
    this.horizontalInset = 0,
  });

  final SettingsDetailRowData row;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final textTheme = theme.textTheme;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: spacing.space8,
      ),
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
            _SettingsRowTrailing(row: row),
          ],
        ),
      ),
    );

    final onTap = row.type == SettingsDetailRowType.action ? null : row.onTap;
    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: radii.borderRadiusMedium,
      onTap: onTap,
      child: content,
    );
  }
}

class _SettingsRowTrailing extends StatelessWidget {
  const _SettingsRowTrailing({required this.row});

  final SettingsDetailRowData row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return switch (row.type) {
      SettingsDetailRowType.status => StatusTextTrailing(
          text: row.statusLabel ?? '',
          variant: row.statusVariant ?? StatusBadgeVariant.neutral,
        ),
      SettingsDetailRowType.action => Button(
          label: row.actionLabel ?? '',
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          onTap: row.onTap,
        ),
      SettingsDetailRowType.navigation => row.valueLabel == null
          ? Icon(
              Symbols.chevron_right_sharp,
              size: sizing.iconSmall,
              color: colors.onSurfaceVariant,
            )
          : TextChevronTrailing(text: row.valueLabel!),
      SettingsDetailRowType.toggle => Switch(
          value: row.switchValue ?? false,
          onChanged: row.onSwitchChanged,
        ),
    };
  }
}
