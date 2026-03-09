import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/zk_proof_detail_section.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent zkProofDetailSectionComponent() {
  return WidgetbookComponent(
    name: 'ZkProofDetailSection',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final semantic = Theme.of(context).extension<AppSemanticColors>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
          );
          final heading = context.knobs.string(
            label: 'Heading',
            initialValue: 'Your Proof',
          );
          final description = context.knobs.string(
            label: 'Description',
            initialValue:
                'Your passport was verified using a zero-knowledge proof. '
                'No personal data was shared or stored.',
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
                child: DecoratedBox(
                  decoration: BoxDecoration(color: catColors.color),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.space16),
                    child: ZkProofDetailSection(
                      heading: heading,
                      description: description,
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
            ),
          );
        },
      ),
    ],
  );
}
