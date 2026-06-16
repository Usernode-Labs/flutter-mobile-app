import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'atomic_challenge_detail_page.stories.g.dart';

const meta =
    MetaWithArgs<AtomicChallengeDetailPage, AtomicChallengeDetailInput>(
      path: 'prototypes/challenges',
    );

class AtomicChallengeDetailInput {
  const AtomicChallengeDetailInput({
    this.title = 'Propose an app change',
    this.description =
        'Improve an existing dApp and help test the new application layer.',
    this.leftText = 'Not done',
    this.rightText = '500 pts',
    this.phase = AtomicChallengePhase.open,
    this.fill = 0,
    this.dateText = 'Jun 4 - Jun 17',
    this.pointsLogic = 'Earn 500 pts when your proposed change is accepted.',
    this.ctaLabel = 'Join the challenge',
    this.rules,
    this.railTreatment = AtomicChallengeRailTreatment.checkbox,
  });

  final String title;
  final String description;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final String dateText;
  final String pointsLogic;
  final String ctaLabel;
  final String? rules;
  final AtomicChallengeRailTreatment railTreatment;
}

final defaults = _Defaults(
  builder: (context, args) {
    return AtomicChallengeDetailPage(
      title: args.title,
      description: args.description,
      leftText: args.leftText,
      rightText: args.rightText,
      phase: args.phase,
      fill: args.fill,
      dateText: args.dateText,
      pointsLogic: args.pointsLogic,
      ctaLabel: args.ctaLabel,
      rules: args.rules,
      railTreatment: args.railTreatment,
      onBackTap: () {},
      onCtaTap: () {},
    );
  },
  setup: (context, child, args) {
    return SizedBox(width: 390, height: 844, child: child);
  },
);

_Args _detailArgs({
  required String title,
  required String description,
  required String leftText,
  required String rightText,
  required AtomicChallengePhase phase,
  required double? fill,
  required String dateText,
  required String pointsLogic,
  String ctaLabel = 'Join the challenge',
  String? rules,
  AtomicChallengeRailTreatment railTreatment =
      AtomicChallengeRailTreatment.standard,
}) {
  return _Args.fixed(
    title: title,
    description: description,
    leftText: leftText,
    rightText: rightText,
    phase: phase,
    fill: fill,
    dateText: dateText,
    pointsLogic: pointsLogic,
    ctaLabel: ctaLabel,
    rules: rules,
    railTreatment: railTreatment,
  );
}

final $ExpandedAtomic = _Story(
  name: 'Expanded atomic',
  args: _Args(
    title: StringArg('Propose an app change'),
    description: StringArg(
      'Improve an existing dApp and help test the new application layer.',
    ),
    leftText: StringArg('Not done'),
    rightText: StringArg('500 pts'),
    phase: EnumArg(
      AtomicChallengePhase.open,
      values: AtomicChallengePhase.values,
    ),
    fill: NullableDoubleArg(
      0,
      style: const SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    dateText: StringArg('Jun 4 - Jun 17'),
    pointsLogic: StringArg(
      'Earn 500 pts when your proposed change is accepted.',
    ),
    ctaLabel: StringArg('Join the challenge'),
    rules: NullableStringArg(null),
    railTreatment: EnumArg(
      AtomicChallengeRailTreatment.checkbox,
      values: AtomicChallengeRailTreatment.values,
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'One step open',
      args: _detailArgs(
        title: 'Propose an app change',
        description:
            'Improve an existing dApp and help test the new application layer.',
        leftText: 'Not done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        dateText: 'Jun 4 - Jun 17',
        pointsLogic: 'Earn 500 pts when your proposed change is accepted.',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Counted progress',
      args: _detailArgs(
        title: 'Give kudos',
        description:
            'Recognize useful contributions from other members during the season.',
        leftText: '2 / 5',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        dateText: 'Ends in 4d',
        pointsLogic: 'Earn points for each accepted kudos action, up to 5.',
        ctaLabel: 'Give kudos',
      ),
    ),
    _Scenario(
      name: 'Pending finalization',
      args: _detailArgs(
        title: 'Fill in survey',
        description: 'Share feedback that helps shape the next testnet season.',
        leftText: 'Submitted',
        rightText: '500 pts',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        dateText: 'Ends today',
        pointsLogic: 'Points are awarded after your response is reviewed.',
        ctaLabel: 'View survey',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Completed',
      args: _detailArgs(
        title: 'Fill in survey',
        description: 'You completed the survey for this season.',
        leftText: 'Done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        dateText: 'Completed today',
        pointsLogic: 'You earned 500 pts for completing the survey.',
        ctaLabel: 'View activity',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Background block production',
      args: _detailArgs(
        title: 'Produce Every Block',
        description:
            'Keep your node online and ready during the season window.',
        leftText: '90% success',
        rightText: 'Earned 10,550.1 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        dateText: 'Season ends in 128d',
        pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
        ctaLabel: 'Check node',
        rules: 'Keep your node connected when you win a slot.',
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
      ),
    ),
  ],
);

final $BackgroundBlockProduction = _Story(
  name: 'Background block production',
  args: _detailArgs(
    title: 'Produce Every Block',
    description: 'Keep your node online and ready during the season window.',
    leftText: '90% success',
    rightText: 'Earned 10,550.1 pts',
    phase: AtomicChallengePhase.inProgress,
    fill: null,
    dateText: 'Season ends in 128d',
    pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
    ctaLabel: 'Check node',
    rules: 'Keep your node connected when you win a slot.',
    railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
  ),
  scenarios: [
    _Scenario(
      name: 'Ongoing status',
      args: _detailArgs(
        title: 'Produce Every Block',
        description:
            'Keep your node online and ready during the season window.',
        leftText: '90% success',
        rightText: 'Earned 10,550.1 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        dateText: 'Season ends in 128d',
        pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
        ctaLabel: 'Check node',
        rules: 'Keep your node connected when you win a slot.',
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
      ),
    ),
  ],
);

/// Widgetbook-only exploration of an atomic challenge detail page.
///
/// The detail keeps the compressed challenge card structure intact: goal first,
/// then the same progress rail. Supporting copy sits below the rail so the page
/// feels like an expansion, not a separate backend record view.
class AtomicChallengeDetailPage extends StatelessWidget {
  const AtomicChallengeDetailPage({
    super.key,
    required this.title,
    required this.description,
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.fill,
    required this.dateText,
    required this.pointsLogic,
    required this.ctaLabel,
    required this.onBackTap,
    required this.onCtaTap,
    this.rules,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
  });

  final String title;
  final String description;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final String dateText;
  final String pointsLogic;
  final String ctaLabel;
  final VoidCallback onBackTap;
  final VoidCallback onCtaTap;
  final String? rules;
  final AtomicChallengeRailTreatment railTreatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final horizontalInset = spacing.space32;
    final isBlockProductionDetail =
        railTreatment == AtomicChallengeRailTreatment.technicalOngoing;
    final pageHorizontalInset = isBlockProductionDetail ? 0.0 : horizontalInset;
    final bottomScrollPadding =
        sizing.buttonHeightLarge + spacing.space12 + spacing.space32;
    Widget inset(Widget child) => isBlockProductionDetail
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: child,
          )
        : child;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            pageHorizontalInset,
            spacing.space8,
            pageHorizontalInset,
            bottomScrollPadding,
          ),
          children: [
            inset(_DetailBackButton(onTap: onBackTap)),
            SizedBox(height: spacing.space32),
            inset(
              _DetailHero(
                title: title,
                leftText: leftText,
                rightText: rightText,
                phase: phase,
                fill: fill,
                railTreatment: railTreatment,
                showRail: !isBlockProductionDetail,
              ),
            ),
            if (isBlockProductionDetail) ...[
              SizedBox(height: spacing.space24),
              const _BlockProductionDetailExtension(),
            ] else ...[
              SizedBox(height: spacing.space32),
              _DetailSection(title: 'Why it matters', body: description),
              SizedBox(height: spacing.space24),
              _DetailSection(title: 'Available', body: dateText),
            ],
            SizedBox(height: spacing.space24),
            inset(
              _DetailExpansion(title: 'How points work', body: pointsLogic),
            ),
            if (rules != null && rules!.isNotEmpty) ...[
              SizedBox(height: spacing.space8),
              inset(_DetailExpansion(title: 'Rules', body: rules!)),
            ],
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
              child: SizedBox(
                width: double.infinity,
                child: Button(
                  label: ctaLabel,
                  onTap: onCtaTap,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockProductionDetailExtension extends StatelessWidget {
  const _BlockProductionDetailExtension();

  static const _statusSteps = [
    _LiveStatusStep(
      label: 'Network',
      icon: Symbols.wifi_sharp,
      statusText: 'Connected',
      statusVariant: StatusBadgeVariant.success,
      tappable: true,
    ),
    _LiveStatusStep(
      label: 'VRF calculation',
      icon: Symbols.casino_sharp,
      statusText: 'Complete',
      statusVariant: StatusBadgeVariant.success,
      tappable: true,
    ),
    _LiveStatusStep(
      label: 'Next block',
      icon: Symbols.schedule_sharp,
      trailingText: 'in < 1 min',
      tappable: true,
    ),
    _LiveStatusStep(
      label: 'Last produced',
      icon: Symbols.check_circle_sharp,
      trailingText: '1 min ago',
      tappable: true,
    ),
    _LiveStatusStep(
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
      spacing: spacing.space24,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          child: const _ExpandedBlockProductionReward(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space32),
          child: const _DetailGroup(
            title: 'Live status',
            child: _LiveStatusList(steps: _statusSteps),
          ),
        ),
      ],
    );
  }
}

class _ExpandedBlockProductionReward extends StatelessWidget {
  const _ExpandedBlockProductionReward();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final foreground = semantic.technical.onColor;
    final secondaryForeground = foreground.withValues(alpha: 0.78);

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
                  'Total earned',
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
                _StaticTechnicalRewardRail(
                  leftText: '90% success',
                  rightText: 'Earned 10,550.1 pts',
                  foregroundColor: foreground,
                ),
                SizedBox(height: spacing.space16),
                _ExpandedRewardCalculation(
                  foregroundColor: foreground,
                  secondaryColor: secondaryForeground,
                ),
                SizedBox(height: spacing.space16),
                _ExpandedRewardLine(
                  label: 'Top 3 rank reward',
                  badge: '2nd',
                  value: '+500',
                  foregroundColor: foreground,
                  secondaryColor: secondaryForeground,
                ),
                SizedBox(height: spacing.space16),
                _ExpandedRewardLine(
                  label: 'First block reward',
                  value: '+250',
                  foregroundColor: foreground,
                  secondaryColor: secondaryForeground,
                ),
                SizedBox(height: spacing.space16),
                _ExpandedRewardLine(
                  label: '50% success reward',
                  value: '+1,000',
                  foregroundColor: foreground,
                  secondaryColor: secondaryForeground,
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

class _StaticTechnicalRewardRail extends StatelessWidget {
  const _StaticTechnicalRewardRail({
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

class _ExpandedRewardCalculation extends StatelessWidget {
  const _ExpandedRewardCalculation({
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RewardFormulaTerm(
                label: 'Success rate',
                value: '90%',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
              SizedBox(width: spacing.space12),
              Text('x', style: operatorStyle),
              SizedBox(width: spacing.space12),
              _RewardFormulaTerm(
                label: 'Assigned slots',
                value: '5,000',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.space12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('=', style: operatorStyle),
            SizedBox(width: spacing.space12),
            _RewardFormulaTerm(
              label: 'Base reward',
              value: '4,500',
              textAlign: TextAlign.end,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _RewardFormulaTerm extends StatelessWidget {
  const _RewardFormulaTerm({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: labelStyle,
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: valueStyle,
        ),
      ],
    );
  }
}

class _ExpandedRewardLine extends StatelessWidget {
  const _ExpandedRewardLine({
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _LiveStatusStep {
  const _LiveStatusStep({
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

class _LiveStatusList extends StatelessWidget {
  const _LiveStatusList({required this.steps});

  final List<_LiveStatusStep> steps;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      spacing: spacing.space8,
      children: [for (final step in steps) _LiveStatusRow(step: step)],
    );
  }
}

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({required this.step});

  final _LiveStatusStep step;

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
            SizedBox(width: spacing.space8),
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

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: spacing.space12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        child,
      ],
    );
  }
}

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton({required this.onTap});

  final VoidCallback onTap;

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
          onPressed: onTap,
          padding: EdgeInsets.zero,
          icon: const Icon(Symbols.arrow_back_sharp),
          tooltip: 'Back',
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.phase,
    required this.fill,
    required this.railTreatment,
    this.showRail = true,
  });

  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final AtomicChallengeRailTreatment railTreatment;
  final bool showRail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: spacing.space24,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
            fontFamily: kMonoFontFamily,
          ),
        ),
        if (showRail)
          AtomicChallengeRail(
            leftText: leftText,
            rightText: rightText,
            phase: phase,
            fill: fill,
            featured: false,
            treatment: railTreatment,
          ),
      ],
    );
  }
}

class _DetailExpansion extends StatelessWidget {
  const _DetailExpansion({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: spacing.space8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          body,
          style: textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontFeatures: title == 'Available'
                ? const [FontFeature.tabularFigures()]
                : null,
          ),
        ),
      ],
    );
  }
}
