import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'block_production_detail_archive.stories.g.dart';

const meta = Meta<ArchivedBlockProductionDetailPrototype>(
  path: 'prototypes/challenges',
  name: 'BlockProductionDetailArchive',
);

final $Jun23RichAtomicPrototype = _Story(name: 'Jun 23 rich atomic prototype');

class ArchivedBlockProductionDetailPrototype extends StatelessWidget {
  const ArchivedBlockProductionDetailPrototype({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final horizontalInset = spacing.space32;
    final bottomScrollPadding =
        sizing.buttonHeightLarge + spacing.space12 + spacing.space32;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            spacing.space8,
            0,
            bottomScrollPadding,
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: const _ArchiveBackButton(),
            ),
            SizedBox(height: spacing.space32),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: const _ArchiveHeroTitle(),
            ),
            SizedBox(height: spacing.space24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: const _ArchiveRewardCard(),
            ),
            SizedBox(height: spacing.space24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: const _ArchiveGroup(
                title: 'Live status',
                child: _ArchiveLiveStatusList(),
              ),
            ),
            SizedBox(height: spacing.space24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: const _ArchiveSection(
                title: 'How points work',
                body:
                    'Score = block rate x assigned-slot points. Rank and reliability bonuses are added when they are earned.',
              ),
            ),
            SizedBox(height: spacing.space24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: const _ArchiveSection(
                title: 'Rules',
                body:
                    'Keep your node connected and producing whenever you win a slot.',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(
              height: borders.width,
              thickness: borders.width,
              color: colors.onSurface.withValues(alpha: borders.opacity),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                spacing.space8,
                horizontalInset,
                spacing.space12,
              ),
              child: Button(
                label: 'Check node',
                onTap: () {},
                variant: ButtonVariant.primary,
                size: ButtonSize.large,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveBackButton extends StatelessWidget {
  const _ArchiveBackButton();

  @override
  Widget build(BuildContext context) {
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final visualOffset = sizing.iconRegular / 2;

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(-visualOffset, 0),
        child: IconButton(
          constraints: BoxConstraints.tightFor(
            width: sizing.iconContainerRegular,
            height: sizing.iconContainerRegular,
          ),
          onPressed: () {},
          padding: EdgeInsets.zero,
          icon: const Icon(Symbols.arrow_back_sharp),
          tooltip: 'Back',
        ),
      ),
    );
  }
}

class _ArchiveHeroTitle extends StatelessWidget {
  const _ArchiveHeroTitle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Produce Every Block',
          style: textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
            fontFamily: kMonoFontFamily,
          ),
        ),
      ],
    );
  }
}

class _ArchiveRewardCard extends StatelessWidget {
  const _ArchiveRewardCard();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final foreground = semantic.technical.onColor;
    final secondary = foreground.withValues(alpha: 0.78);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: semantic.technical.color,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Earned',
                  style: textTheme.labelLarge?.copyWith(color: foreground),
                ),
                SizedBox(height: spacing.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        '10,550.1',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.displaySmall?.copyWith(
                          color: foreground,
                          fontFamily: kMonoFontFamily,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.space4),
                    Text(
                      'pts',
                      style: textTheme.titleLarge?.copyWith(color: foreground),
                    ),
                  ],
                ),
                SizedBox(height: spacing.space24),
                _ArchiveTechnicalRail(
                  leftText: '90% success',
                  rightText: 'Earned 10,550.1 pts',
                  foregroundColor: foreground,
                ),
                SizedBox(height: spacing.space16),
                _ArchiveFormulaRow(
                  foregroundColor: foreground,
                  secondaryColor: secondary,
                ),
                SizedBox(height: spacing.space16),
                _ArchiveRewardLine(
                  label: 'Top 3 rank reward',
                  badge: '2nd',
                  value: '+500',
                  foregroundColor: foreground,
                  secondaryColor: secondary,
                ),
                SizedBox(height: spacing.space16),
                _ArchiveRewardLine(
                  label: 'First block reward',
                  value: '+250',
                  foregroundColor: foreground,
                  secondaryColor: secondary,
                ),
                SizedBox(height: spacing.space16),
                _ArchiveRewardLine(
                  label: '50% success reward',
                  value: '+1,000',
                  foregroundColor: foreground,
                  secondaryColor: secondary,
                ),
              ],
            ),
          ),
          Divider(
            height: borders.width,
            thickness: borders.width,
            color: foreground.withValues(alpha: borders.opacity),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.space16),
            child: Button(
              label: 'View epoch 176',
              onTap: () {},
              variant: ButtonVariant.surface,
              size: ButtonSize.regular,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveTechnicalRail extends StatelessWidget {
  const _ArchiveTechnicalRail({
    required this.leftText,
    required this.rightText,
    required this.foregroundColor,
  });

  final String leftText;
  final String rightText;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final textTheme = Theme.of(context).textTheme;

    return OngoingRailFrame(
      color: foregroundColor.withValues(alpha: 0.64),
      borderRadius: radii.large,
      strokeWidth: borders.width,
      child: SizedBox(
        height: spacing.space48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  leftText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                flex: 3,
                child: Text(
                  rightText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveFormulaRow extends StatelessWidget {
  const _ArchiveFormulaRow({
    required this.foregroundColor,
    required this.secondaryColor,
  });

  final Color foregroundColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: secondaryColor,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: foregroundColor,
      fontFamily: kMonoFontFamily,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final operatorStyle = textTheme.bodyMedium?.copyWith(
      color: foregroundColor,
    );

    return Wrap(
      spacing: spacing.space12,
      runSpacing: spacing.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ArchiveFormulaTerm(
          label: 'Success rate',
          value: '90%',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        Text('x', style: operatorStyle),
        _ArchiveFormulaTerm(
          label: 'Assigned slots',
          value: '5,000',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        Text('=', style: operatorStyle),
        _ArchiveFormulaTerm(
          label: 'Base reward',
          value: '4,500',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      ],
    );
  }
}

class _ArchiveFormulaTerm extends StatelessWidget {
  const _ArchiveFormulaTerm({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _ArchiveRewardLine extends StatelessWidget {
  const _ArchiveRewardLine({
    required this.label,
    required this.value,
    required this.foregroundColor,
    required this.secondaryColor,
    this.badge,
  });

  final String label;
  final String value;
  final Color foregroundColor;
  final Color secondaryColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null) ...[
                SizedBox(width: spacing.space8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: foregroundColor.withValues(alpha: 0.15),
                    borderRadius: radii.borderRadiusFull,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space8,
                      vertical: spacing.space4,
                    ),
                    child: Text(
                      badge!,
                      style: textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: spacing.space12),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: foregroundColor,
            fontFamily: kMonoFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ArchiveGroup extends StatelessWidget {
  const _ArchiveGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
        ),
        SizedBox(height: spacing.space12),
        child,
      ],
    );
  }
}

class _ArchiveLiveStatusList extends StatelessWidget {
  const _ArchiveLiveStatusList();

  static const _steps = [
    _ArchiveLiveStatusStep(
      label: 'Network',
      icon: Symbols.wifi_sharp,
      statusText: 'Connected',
      statusVariant: StatusBadgeVariant.success,
      tappable: true,
    ),
    _ArchiveLiveStatusStep(
      label: 'VRF calculation',
      icon: Symbols.casino_sharp,
      statusText: 'Complete',
      statusVariant: StatusBadgeVariant.success,
      tappable: true,
    ),
    _ArchiveLiveStatusStep(
      label: 'Next block',
      icon: Symbols.schedule_sharp,
      trailingText: 'in < 1 min',
      tappable: true,
    ),
    _ArchiveLiveStatusStep(
      label: 'Last produced',
      icon: Symbols.check_circle_sharp,
      trailingText: '1 min ago',
      tappable: true,
    ),
    _ArchiveLiveStatusStep(
      label: 'Missed blocks',
      icon: Symbols.disabled_by_default_sharp,
      statusText: 'None',
      statusVariant: StatusBadgeVariant.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      children: [
        for (final step in _steps) ...[
          _ArchiveLiveStatusRow(step: step),
          if (step != _steps.last) SizedBox(height: spacing.space8),
        ],
      ],
    );
  }
}

class _ArchiveLiveStatusStep {
  const _ArchiveLiveStatusStep({
    required this.label,
    required this.icon,
    this.trailingText,
    this.statusText,
    this.statusVariant,
    this.tappable = false,
  }) : assert(
         trailingText != null || (statusText != null && statusVariant != null),
       );

  final String label;
  final IconData icon;
  final String? trailingText;
  final String? statusText;
  final StatusBadgeVariant? statusVariant;
  final bool tappable;
}

class _ArchiveLiveStatusRow extends StatelessWidget {
  const _ArchiveLiveStatusRow({required this.step});

  final _ArchiveLiveStatusStep step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    final trailing = step.statusText != null && step.statusVariant != null
        ? StatusTextTrailing(
            text: step.statusText!,
            variant: step.statusVariant!,
          )
        : Text(
            step.trailingText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: sizing.iconContainerRegular),
      child: Row(
        children: [
          IconBadge(icon: step.icon, size: sizing.iconContainerSmall),
          SizedBox(width: spacing.space12),
          Expanded(
            child: Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            ),
          ),
          SizedBox(width: spacing.space12),
          trailing,
          if (step.tappable) ...[
            SizedBox(width: spacing.space4),
            Icon(
              Symbols.chevron_right_sharp,
              size: sizing.iconSmall,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
        ),
        SizedBox(height: spacing.space4),
        Text(
          body,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
