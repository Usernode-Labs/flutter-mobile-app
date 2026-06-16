import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'atomic_challenge_card.dart';
import 'button.dart';

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

  /// Challenge goal/title.
  final String title;

  /// "Why it matters" body copy.
  final String description;

  /// Progress rail left text (mirrors the card).
  final String leftText;

  /// Progress rail right text (mirrors the card).
  final String rightText;

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
                  horizontalInset,
                  spacing.space8,
                  horizontalInset,
                  spacing.space24,
                ),
                children: [
                  _DetailBackButton(onTap: onBackTap),
                  SizedBox(height: spacing.space32),
                  _DetailHero(
                    title: title,
                    leftText: leftText,
                    rightText: rightText,
                    phase: phase,
                    fill: fill,
                    railTreatment: railTreatment,
                  ),
                  SizedBox(height: spacing.space32),
                  _DetailSection(title: 'Why it matters', body: description),
                  SizedBox(height: spacing.space24),
                  _DetailSection(title: 'Available', body: dateText),
                  SizedBox(height: spacing.space24),
                  _DetailExpansion(title: 'How points work', body: pointsLogic),
                  if (rules != null && rules!.isNotEmpty) ...[
                    SizedBox(height: spacing.space8),
                    _DetailExpansion(title: 'Rules', body: rules!),
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
    required this.phase,
    required this.fill,
    required this.railTreatment,
  });

  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final AtomicChallengeRailTreatment railTreatment;

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
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
