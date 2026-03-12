import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_reward_card.dart';
import '../src/zk_proof_detail_section.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent challengeRewardCardComponent() {
  return WidgetbookComponent(
    name: 'ChallengeRewardCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Simple',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
          );
          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '10,550.1',
          );

          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: SizedBox(
                width: 360,
                child: ChallengeRewardCard(
                  category: category,
                  totalEarned: totalEarned,
                  data: const SimpleRewardData(),
                ),
              ),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Produce Blocks',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
          );
          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '4,900',
          );
          final progress = context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.85,
            min: 0,
            max: 1,
          );

          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: SizedBox(
                width: 360,
                child: ChallengeRewardCard(
                  category: category,
                  totalEarned: totalEarned,
                  data: ProduceBlocksRewardData(
                    progressFraction: progress,
                    successRate: '98%',
                    maxPoints: '5,000',
                    totalPoints: totalEarned,
                    rankLabel: '1st',
                    rankReward: '+500',
                  ),
                  epochSectionLabel: 'This Epoch Earned',
                  epochEarned: '+50',
                  epochLabel: 'View Epoch 176',
                ),
              ),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Simple + Proof Footer',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final semantic = Theme.of(context).extension<AppSemanticColors>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
            initialOption: ChallengeCategory.community,
          );
          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '500',
          );

          final catColors = switch (category) {
            ChallengeCategory.technical => semantic.technical,
            ChallengeCategory.community => semantic.community,
            ChallengeCategory.flash => semantic.flash,
          };

          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: SizedBox(
                width: 360,
                child: ChallengeRewardCard(
                  category: category,
                  totalEarned: totalEarned,
                  data: const SimpleRewardData(),
                  footer: ZkProofDetailSection(
                    heading: 'Your Proof',
                    description:
                        'Your passport was verified using a zero-knowledge '
                        'proof. No personal data was shared or stored.',
                    onColor: catColors.onColor,
                    dimOnColor: catColors.onColor.withValues(alpha: 0.8),
                    rows: const [
                      (
                        icon: Symbols.check_circle_sharp,
                        label: 'Status',
                        value: 'Valid Passport',
                        monospace: false,
                        onTap: null,
                      ),
                      (
                        icon: Symbols.shield_sharp,
                        label: 'Privacy',
                        value: 'No data shared',
                        monospace: false,
                        onTap: null,
                      ),
                      (
                        icon: Symbols.calendar_today_sharp,
                        label: 'Verified',
                        value: 'Mar 9, 2026',
                        monospace: false,
                        onTap: null,
                      ),
                      (
                        icon: Symbols.fingerprint_sharp,
                        label: 'Proof ID',
                        value: '0x1a2b3c4d...ef01',
                        monospace: true,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
