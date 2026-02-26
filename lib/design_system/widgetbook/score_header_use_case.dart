import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/score_header.dart';

WidgetbookComponent scoreHeaderComponent() {
  return WidgetbookComponent(
    name: 'ScoreHeader',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final variant = context.knobs.object.dropdown<ScoreHeaderVariant>(
            label: 'Variant',
            options: ScoreHeaderVariant.values,
            initialOption: ScoreHeaderVariant.standard,
            labelBuilder: (v) => v.name,
          );

          final score = context.knobs.string(
            label: 'Score',
            initialValue: '8,000',
          );

          final scoreLabel = context.knobs.string(
            label: 'Score Label',
            initialValue: 'points',
          );

          final rankLabel = context.knobs.stringOrNull(
            label: 'Rank Label',
            initialValue: 'Rank 44',
          );

          final progress = context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.75,
            min: 0,
            max: 1,
          );

          final countdownTime = context.knobs.stringOrNull(
            label: 'Countdown Time',
            initialValue: '12 DAYS 5H 3M',
          );

          final ctaLabel = context.knobs.stringOrNull(
            label: 'CTA Label',
            initialValue: 'View in Leaderboard',
          );

          final glowIntensity = context.knobs.double.slider(
            label: 'Glow Intensity',
            initialValue: 1.0,
            min: 0,
            max: 1,
          );

          final technicalGlow = context.knobs.double.slider(
            label: 'Technical Lobe',
            initialValue: 0,
            min: 0,
            max: 1,
          );

          final flashGlow = context.knobs.double.slider(
            label: 'Flash Lobe',
            initialValue: 0,
            min: 0,
            max: 1,
          );

          final communityGlow = context.knobs.double.slider(
            label: 'Community Lobe',
            initialValue: 0,
            min: 0,
            max: 1,
          );

          final countdownOpacity = context.knobs.double.slider(
            label: 'Countdown Opacity',
            initialValue: 1.0,
            min: 0,
            max: 1,
          );

          final countdownTextMode =
              context.knobs.object.dropdown<CountdownTextMode>(
            label: 'Countdown Text Mode',
            options: CountdownTextMode.values,
            initialOption: CountdownTextMode.normal,
            labelBuilder: (v) => v.name,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ScoreHeader(
              score: score,
              scoreLabel: scoreLabel,
              rankLabel: rankLabel,
              progress: progress,
              countdownTime: countdownTime,
              ctaLabel: ctaLabel,
              variant: variant,
              glowIntensity: glowIntensity,
              technicalGlowIntensity: technicalGlow > 0 ? technicalGlow : null,
              flashGlowIntensity: flashGlow > 0 ? flashGlow : null,
              communityGlowIntensity: communityGlow > 0 ? communityGlow : null,
              countdownOpacity: countdownOpacity,
              countdownTextMode: countdownTextMode,
              onCtaTap: () {},
            ),
          );
        },
      ),
    ],
  );
}
