import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'atomic_challenge_card.dart';
import 'button.dart';
import 'icon_badge.dart';
import 'status_badge.dart';
import 'status_text_trailing.dart';

/// Optional technical hero content for block-production challenge details.
///
/// The page still owns the surrounding atomic detail structure; this data only
/// swaps the default standalone rail for a richer technical card that can carry
/// reward stats and live node/block-production status.
class AtomicChallengeTechnicalHeroCardData {
  const AtomicChallengeTechnicalHeroCardData({
    required this.totalEarned,
    this.totalLabel = 'Total Earned',
    this.totalUnit = 'pts',
    this.formula,
    this.rewardLines = const [],
    this.epochLabel,
    this.onEpochTap,
    this.stats = const [],
    this.overviewTitle = 'Live status',
    this.overview = const [],
  });

  final String totalEarned;
  final String totalLabel;
  final String? totalUnit;
  final AtomicChallengeHeroFormula? formula;
  final List<AtomicChallengeHeroRewardLine> rewardLines;
  final String? epochLabel;
  final VoidCallback? onEpochTap;

  /// Legacy compact stat rows. Prefer [formula] + [rewardLines] for the
  /// production block-detail hero; this remains for simple story/test coverage.
  final List<AtomicChallengeHeroStat> stats;
  final String overviewTitle;
  final List<AtomicChallengeHeroOverviewItem> overview;
}

class AtomicChallengeHeroFormula {
  const AtomicChallengeHeroFormula({
    required this.rateLabel,
    required this.rateValue,
    required this.maxLabel,
    required this.maxValue,
    required this.totalLabel,
    required this.totalValue,
  });

  final String rateLabel;
  final String rateValue;
  final String maxLabel;
  final String maxValue;
  final String totalLabel;
  final String totalValue;
}

class AtomicChallengeHeroRewardLine {
  const AtomicChallengeHeroRewardLine({
    required this.label,
    required this.value,
    this.badge,
  });

  final String label;
  final String value;
  final String? badge;
}

class AtomicChallengeHeroStat {
  const AtomicChallengeHeroStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

enum AtomicChallengeHeroOverviewTone {
  neutral,
  success,
  warning,
  error,
  info,
}

class AtomicChallengeHeroOverviewItem {
  const AtomicChallengeHeroOverviewItem({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AtomicChallengeHeroOverviewTone.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final AtomicChallengeHeroOverviewTone tone;
  final VoidCallback? onTap;
}

/// The simplified Fair Rewards challenge detail page.
///
/// Keeps the compressed card structure intact — goal first, then the same
/// [AtomicChallengeRail] — so the page reads as an expansion of the card rather
/// than a separate backend record view. Supporting copy ("Why it matters",
/// "Available", "How points work", optional "Rules") sits below the rail, and a
/// single primary CTA is pinned to the bottom.
///
/// Presentation-only: all content arrives via constructor parameters. The
/// feature screen resolves challenge data, formats the strings, and wires the
/// back / CTA callbacks.
class AtomicChallengeDetailPage extends StatelessWidget {
  const AtomicChallengeDetailPage({
    super.key,
    required this.title,
    required this.description,
    this.task,
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
    this.progressHelperText,
    this.heroCard,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
  });

  /// Challenge goal/title.
  final String title;

  /// "Why it matters" body copy. Hidden when empty.
  final String description;

  /// Concrete challenge task copy. Hidden when null/empty.
  final String? task;

  /// Progress rail left text (mirrors the card).
  final String leftText;

  /// Progress rail right text (mirrors the card).
  final String rightText;

  /// Optional read-layer progress/evidence copy shown directly under the rail.
  final String? progressHelperText;

  /// Optional rich hero surface for technical details such as block production.
  final AtomicChallengeTechnicalHeroCardData? heroCard;

  final AtomicChallengePhase phase;
  final double? fill;
  final AtomicChallengeRailTreatment railTreatment;

  /// "Available" body, e.g. "Jun 4 - Jun 17" or "Ends in 4d".
  final String dateText;

  /// "How points work" body (expandable).
  final String pointsLogic;

  /// Bottom CTA label, e.g. "Join the challenge".
  final String ctaLabel;

  /// Optional "Rules" body (expandable). Hidden when null/empty.
  final String? rules;

  final VoidCallback onBackTap;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final horizontalInset = spacing.space32;
    final listHorizontalInset = heroCard == null ? horizontalInset : 0.0;
    final descriptionText = description.trim();
    final taskText = task?.trim();
    Widget inset(Widget child) => heroCard == null
        ? child
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: child,
          );

    // No Scaffold here — the page is presentation-only and the bottom CTA is
    // pinned via an Expanded scroll area above a fixed CTA bar.
    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  listHorizontalInset,
                  spacing.space8,
                  listHorizontalInset,
                  spacing.space24,
                ),
                children: [
                  inset(_DetailBackButton(onTap: onBackTap)),
                  SizedBox(height: spacing.space32),
                  _DetailHero(
                    title: title,
                    leftText: leftText,
                    rightText: rightText,
                    progressHelperText: progressHelperText,
                    heroCard: heroCard,
                    phase: phase,
                    fill: fill,
                    railTreatment: railTreatment,
                  ),
                  SizedBox(
                    height:
                        heroCard == null ? spacing.space32 : spacing.space24,
                  ),
                  if (descriptionText.isNotEmpty) ...[
                    inset(
                      _DetailSection(
                        title: 'Why it matters',
                        body: descriptionText,
                      ),
                    ),
                    SizedBox(height: spacing.space24),
                  ],
                  if (taskText != null && taskText.isNotEmpty) ...[
                    inset(_DetailSection(title: 'Task', body: taskText)),
                    SizedBox(height: spacing.space24),
                  ],
                  inset(_DetailSection(title: 'Available', body: dateText)),
                  SizedBox(height: spacing.space24),
                  inset(
                    _DetailExpansion(
                      title: 'How points work',
                      body: pointsLogic,
                    ),
                  ),
                  if (rules != null && rules!.isNotEmpty) ...[
                    SizedBox(height: spacing.space8),
                    inset(_DetailExpansion(title: 'Rules', body: rules!)),
                  ],
                ],
              ),
            ),
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
    this.progressHelperText,
    this.heroCard,
    required this.phase,
    required this.fill,
    required this.railTreatment,
  });

  final String title;
  final String leftText;
  final String rightText;
  final String? progressHelperText;
  final AtomicChallengeTechnicalHeroCardData? heroCard;
  final AtomicChallengePhase phase;
  final double? fill;
  final AtomicChallengeRailTreatment railTreatment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final helperText = progressHelperText?.trim();
    final titleStyle =
        heroCard == null ? textTheme.displaySmall : textTheme.headlineLarge;

    if (heroCard != null) {
      return Column(
        spacing: spacing.space24,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space24),
            child: Text(
              title,
              style: titleStyle?.copyWith(
                color: colors.onSurface,
                fontFamily: kMonoFontFamily,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: _AtomicChallengeTechnicalHeroCard(
              data: heroCard!,
              leftText: leftText,
              rightText: rightText,
              progressHelperText: helperText,
            ),
          ),
          if (heroCard!.overview.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space24),
              child: _HeroOverviewGroup(
                title: heroCard!.overviewTitle,
                overview: heroCard!.overview,
              ),
            ),
        ],
      );
    }

    return Column(
      spacing: spacing.space24,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: titleStyle?.copyWith(
            color: colors.onSurface,
            fontFamily: kMonoFontFamily,
          ),
        ),
        Column(
          spacing: spacing.space8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AtomicChallengeRail(
              leftText: leftText,
              rightText: rightText,
              phase: phase,
              fill: fill,
              featured: false,
              treatment: railTreatment,
            ),
            if (helperText != null && helperText.isNotEmpty)
              Text(
                helperText,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AtomicChallengeTechnicalHeroCard extends StatelessWidget {
  const _AtomicChallengeTechnicalHeroCard({
    required this.data,
    required this.leftText,
    required this.rightText,
    this.progressHelperText,
  });

  final AtomicChallengeTechnicalHeroCardData data;
  final String leftText;
  final String rightText;
  final String? progressHelperText;

  @override
  Widget build(BuildContext context) {
    final borders = Theme.of(context).extension<AppBorders>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final onColor = semantic.technical.onColor;
    final secondaryColor = onColor.withValues(alpha: 0.72);
    final helperText = progressHelperText?.trim();
    final epochLabel = data.epochLabel?.trim();

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
              spacing: spacing.space16,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  spacing: spacing.space4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.totalLabel,
                      style: textTheme.labelLarge?.copyWith(
                        color: secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            data.totalEarned,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.displaySmall?.copyWith(
                              color: onColor,
                              fontFamily: kMonoFontFamily,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (data.totalUnit != null &&
                            data.totalUnit!.trim().isNotEmpty) ...[
                          SizedBox(width: spacing.space8),
                          Text(
                            data.totalUnit!,
                            style: textTheme.titleMedium?.copyWith(
                              color: secondaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                _TechnicalHeroRail(
                  leftText: leftText,
                  rightText: rightText,
                  color: onColor,
                ),
                if (helperText != null && helperText.isNotEmpty)
                  Text(
                    helperText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: secondaryColor,
                    ),
                  ),
                if (data.formula != null)
                  _HeroFormulaRow(formula: data.formula!, onColor: onColor),
                if (data.formula == null && data.stats.isNotEmpty)
                  _HeroStatsGrid(stats: data.stats, onColor: onColor),
                if (data.rewardLines.isNotEmpty)
                  Column(
                    spacing: spacing.space8,
                    children: data.rewardLines
                        .map(
                          (line) => _HeroRewardLine(
                            line: line,
                            onColor: onColor,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          if (epochLabel != null &&
              epochLabel.isNotEmpty &&
              data.onEpochTap != null) ...[
            Divider(
              height: borders.width,
              thickness: borders.width,
              color: onColor.withValues(alpha: 0.18),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: Button(
                label: epochLabel,
                onTap: data.onEpochTap,
                variant: ButtonVariant.surface,
                size: ButtonSize.regular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TechnicalHeroRail extends StatelessWidget {
  const _TechnicalHeroRail({
    required this.leftText,
    required this.rightText,
    required this.color,
  });

  final String leftText;
  final String rightText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final borders = Theme.of(context).extension<AppBorders>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return OngoingRailFrame(
      color: color.withValues(alpha: 0.62),
      borderRadius: radii.largeIncreased,
      strokeWidth: borders.width * 2,
      child: SizedBox(
        height: sizing.buttonHeightLarge,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: spacing.space16),
              Expanded(
                child: Text(
                  rightText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.titleSmall?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
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

class _HeroFormulaRow extends StatelessWidget {
  const _HeroFormulaRow({required this.formula, required this.onColor});

  final AtomicChallengeHeroFormula formula;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final operatorStyle = textTheme.titleSmall?.copyWith(
      color: onColor.withValues(alpha: 0.68),
      fontWeight: FontWeight.w700,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _HeroFormulaTerm(
            label: formula.rateLabel,
            value: formula.rateValue,
            onColor: onColor,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space8),
          child: Text('x', style: operatorStyle),
        ),
        Expanded(
          child: _HeroFormulaTerm(
            label: formula.maxLabel,
            value: formula.maxValue,
            onColor: onColor,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space8),
          child: Text('=', style: operatorStyle),
        ),
        Expanded(
          child: _HeroFormulaTerm(
            label: formula.totalLabel,
            value: formula.totalValue,
            onColor: onColor,
            alignment: CrossAxisAlignment.end,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _HeroFormulaTerm extends StatelessWidget {
  const _HeroFormulaTerm({
    required this.label,
    required this.value,
    required this.onColor,
    this.alignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final String value;
  final Color onColor;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: textTheme.labelSmall?.copyWith(
            color: onColor.withValues(alpha: 0.68),
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: textTheme.titleSmall?.copyWith(
            color: onColor,
            fontFamily: kMonoFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroRewardLine extends StatelessWidget {
  const _HeroRewardLine({required this.line, required this.onColor});

  final AtomicChallengeHeroRewardLine line;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final badge = line.badge?.trim();

    return Row(
      children: [
        Expanded(
          child: Text(
            line.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: onColor.withValues(alpha: 0.78),
            ),
          ),
        ),
        if (badge != null && badge.isNotEmpty) ...[
          StatusBadge(
            label: badge,
            variant: StatusBadgeVariant.info,
          ),
          SizedBox(width: spacing.space8),
        ],
        Text(
          line.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: onColor,
            fontFamily: kMonoFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroStatsGrid extends StatelessWidget {
  const _HeroStatsGrid({required this.stats, required this.onColor});

  final List<AtomicChallengeHeroStat> stats;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing.space8) / 2;
        return Wrap(
          spacing: spacing.space8,
          runSpacing: spacing.space12,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: itemWidth,
                  child: _HeroStat(stat: stat, onColor: onColor),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.stat, required this.onColor});

  final AtomicChallengeHeroStat stat;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: spacing.space4,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: onColor.withValues(alpha: 0.68),
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: onColor,
            fontFamily: kMonoFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroOverviewGroup extends StatelessWidget {
  const _HeroOverviewGroup({
    required this.title,
    required this.overview,
  });

  final String title;
  final List<AtomicChallengeHeroOverviewItem> overview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      spacing: spacing.space12,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        Column(
          spacing: spacing.space4,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              overview.map((item) => _HeroOverviewRow(item: item)).toList(),
        ),
      ],
    );
  }
}

class _HeroOverviewRow extends StatelessWidget {
  const _HeroOverviewRow({required this.item});

  final AtomicChallengeHeroOverviewItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final (Color iconBackground, Color iconForeground) = switch (item.tone) {
      AtomicChallengeHeroOverviewTone.success => (
          semantic.success.colorContainer,
          semantic.success.onColorContainer,
        ),
      AtomicChallengeHeroOverviewTone.warning => (
          semantic.warning.colorContainer,
          semantic.warning.onColorContainer,
        ),
      AtomicChallengeHeroOverviewTone.error => (
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      AtomicChallengeHeroOverviewTone.info => (
          semantic.technical.colorContainer,
          semantic.technical.onColorContainer,
        ),
      AtomicChallengeHeroOverviewTone.neutral => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
        ),
    };
    final trailing = item.tone == AtomicChallengeHeroOverviewTone.info
        ? Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          )
        : StatusTextTrailing(
            text: item.value,
            variant: _statusVariant(item.tone),
          );

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.space4),
      child: Row(
        children: [
          IconBadge(
            icon: item.icon,
            size: sizing.iconContainerSmall,
            surfaceSize: sizing.iconContainerSmall,
            backgroundColor: iconBackground,
            iconColor: iconForeground,
          ),
          SizedBox(width: spacing.space12),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: spacing.space12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
          if (item.onTap != null) ...[
            SizedBox(width: spacing.space4),
            Icon(
              Symbols.chevron_right_sharp,
              color: colors.onSurfaceVariant,
              size: sizing.iconRegular,
            ),
          ],
        ],
      ),
    );

    if (item.onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: radii.borderRadiusMedium,
        child: row,
      ),
    );
  }
}

StatusBadgeVariant _statusVariant(AtomicChallengeHeroOverviewTone tone) =>
    switch (tone) {
      AtomicChallengeHeroOverviewTone.success => StatusBadgeVariant.success,
      AtomicChallengeHeroOverviewTone.warning => StatusBadgeVariant.warning,
      AtomicChallengeHeroOverviewTone.error => StatusBadgeVariant.error,
      AtomicChallengeHeroOverviewTone.info => StatusBadgeVariant.info,
      AtomicChallengeHeroOverviewTone.neutral => StatusBadgeVariant.neutral,
    };

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
          style: textTheme.bodyMedium?.copyWith(
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
      shape: const Border(),
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
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
