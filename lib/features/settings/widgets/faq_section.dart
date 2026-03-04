import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// A numbered step in the "How it works" FAQ tile.
class FaqStep {
  const FaqStep({required this.title, required this.description});

  final String title;
  final String description;
}

/// A reliability mode row in the platform FAQ tile.
class ReliabilityMode {
  const ReliabilityMode({
    required this.mode,
    required this.reliability,
    required this.description,
  });

  final String mode;
  final String reliability;
  final String description;
}

/// Localization strings needed by the FAQ section.
class FaqLocalizations {
  const FaqLocalizations({
    required this.helpAndInfoTitle,
    required this.aboutTitle,
    required this.aboutDescription,
    required this.whatIsTitle,
    required this.whatIsDescription,
    required this.steps,
    required this.platformReliabilityTitle,
    required this.platformAndroidDesc,
    required this.platformIosDesc,
    required this.reliabilityByMode,
    required this.androidModes,
    required this.iosModes,
    this.deviceLabel,
    required this.vrfSlotsTitle,
    required this.vrfWhatIsTitle,
    required this.vrfWhatIsDescription,
    required this.vrfStatusMeaningsTitle,
    required this.vrfStatusPending,
    required this.vrfStatusPendingDesc,
    required this.vrfStatusCalculating,
    required this.vrfStatusCalculatingDesc,
    required this.vrfStatusComplete,
    required this.vrfStatusCompleteDesc,
    required this.vrfWonSlotTitle,
    required this.vrfWonSlotDescription,
    required this.vrfTimingTitle,
    required this.vrfTimingDescription,
  });

  final String helpAndInfoTitle;
  final String aboutTitle;
  final String aboutDescription;
  final String whatIsTitle;
  final String whatIsDescription;
  final List<FaqStep> steps;
  final String platformReliabilityTitle;
  final String platformAndroidDesc;
  final String platformIosDesc;
  final String reliabilityByMode;
  final List<ReliabilityMode> androidModes;
  final List<ReliabilityMode> iosModes;
  final String? deviceLabel;
  final String vrfSlotsTitle;
  final String vrfWhatIsTitle;
  final String vrfWhatIsDescription;
  final String vrfStatusMeaningsTitle;
  final String vrfStatusPending;
  final String vrfStatusPendingDesc;
  final String vrfStatusCalculating;
  final String vrfStatusCalculatingDesc;
  final String vrfStatusComplete;
  final String vrfStatusCompleteDesc;
  final String vrfWonSlotTitle;
  final String vrfWonSlotDescription;
  final String vrfTimingTitle;
  final String vrfTimingDescription;
}

/// Tier 3: Help & Info FAQ section with 4 ExpansionTiles.
class FaqSection extends StatelessWidget {
  const FaqSection({
    super.key,
    required this.localizations,
    this.deviceManufacturer,
    this.platformOverride,
  });

  final FaqLocalizations localizations;
  final String? deviceManufacturer;
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: localizations.helpAndInfoTitle),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildAboutTile(context),
              _buildHowItWorksTile(context),
              _buildPlatformTile(context),
              _buildVrfTile(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Symbols.info_sharp),
      title: Text(localizations.aboutTitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.aboutDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Symbols.lightbulb_sharp),
      title: Text(localizations.whatIsTitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.whatIsDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        for (var i = 0; i < localizations.steps.length; i++) ...[
          if (i > 0) SizedBox(height: spacing.space12),
          _NumberedStep(
            number: '${i + 1}',
            title: localizations.steps[i].title,
            description: localizations.steps[i].description,
          ),
        ],
      ],
    );
  }

  Widget _buildPlatformTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final isAndroid =
        (platformOverride ?? defaultTargetPlatform) == TargetPlatform.android;
    final modes =
        isAndroid ? localizations.androidModes : localizations.iosModes;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Symbols.smartphone_sharp),
      title: Text(localizations.platformReliabilityTitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAndroid
              ? localizations.platformAndroidDesc
              : localizations.platformIosDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.space16),
        Container(
          padding: EdgeInsets.all(spacing.space12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: radii.borderRadiusSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.reliabilityByMode,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.space12),
              for (var i = 0; i < modes.length; i++) ...[
                if (i > 0) SizedBox(height: spacing.space8),
                _ReliabilityRow(
                  mode: modes[i].mode,
                  percentage: modes[i].reliability,
                  description: modes[i].description,
                  color: i == 0
                      ? semantic.success.color
                      : (isAndroid
                          ? semantic.technical.color
                          : semantic.warning.color),
                ),
              ],
            ],
          ),
        ),
        if (isAndroid && deviceManufacturer != null) ...[
          SizedBox(height: spacing.space12),
          Row(
            children: [
              Icon(
                Symbols.smartphone_sharp,
                size: sizing.iconXSmall,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: spacing.space8),
              Text(
                localizations.deviceLabel ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVrfTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Symbols.casino_sharp),
      title: Text(localizations.vrfSlotsTitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.vrfWhatIsTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          localizations.vrfWhatIsDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        Text(
          localizations.vrfStatusMeaningsTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: localizations.vrfStatusPending,
          description: localizations.vrfStatusPendingDesc,
          color: colorScheme.outline,
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: localizations.vrfStatusCalculating,
          description: localizations.vrfStatusCalculatingDesc,
          color: semantic.warning.color,
        ),
        SizedBox(height: spacing.space8),
        _StatusExplanation(
          status: localizations.vrfStatusComplete,
          description: localizations.vrfStatusCompleteDesc,
          color: semantic.success.color,
        ),
        SizedBox(height: spacing.space16),
        Text(
          localizations.vrfWonSlotTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          localizations.vrfWonSlotDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        SizedBox(height: spacing.space16),
        Container(
          padding: EdgeInsets.all(spacing.space12),
          decoration: BoxDecoration(
            color: semantic.warning.colorContainer,
            borderRadius: radii.borderRadiusSmall,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.timer_sharp,
                size: sizing.iconSmall,
                color: semantic.warning.color,
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.vrfTimingTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: semantic.warning.color,
                      ),
                    ),
                    SizedBox(height: spacing.space4),
                    Text(
                      localizations.vrfTimingDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: sizing.iconRegular,
          height: sizing.iconRegular,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: radii.borderRadiusMedium,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.space4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReliabilityRow extends StatelessWidget {
  const _ReliabilityRow({
    required this.mode,
    required this.percentage,
    required this.description,
    required this.color,
  });

  final String mode;
  final String percentage;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.space8,
            vertical: spacing.space4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: radii.borderRadiusXSmall,
          ),
          child: Text(
            percentage,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusExplanation extends StatelessWidget {
  const _StatusExplanation({
    required this.status,
    required this.description,
    required this.color,
  });

  final String status;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(top: spacing.space8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$status: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
