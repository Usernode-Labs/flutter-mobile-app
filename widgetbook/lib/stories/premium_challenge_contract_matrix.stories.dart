import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/services/challenge_api_visual_fixture.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

part 'premium_challenge_contract_matrix.stories.g.dart';

const meta = Meta<PremiumChallengeContractMatrix>(
  path: 'prototypes/challenges',
);

final $Default = _Story(
  name: 'Premium API matrix',
  setup: (context, child, args) {
    return SizedBox(width: 430, height: 1200, child: child);
  },
  scenarios: [_Scenario(name: 'Featured surface with API shapes')],
);

/// Premium/featured rendering matrix built from raw mobile API response shapes.
class PremiumChallengeContractMatrix extends StatelessWidget {
  const PremiumChallengeContractMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final cases = ChallengeApiVisualFixture.cases;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space16,
          children: [
            Text('Premium challenge contract', style: textTheme.headlineSmall),
            Text(
              'Same raw API shapes as the contract matrix, forced through the Featured/premium treatment.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            _PremiumFeaturedBand(cases: cases),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeaturedBand extends StatelessWidget {
  const _PremiumFeaturedBand({required this.cases});

  final List<ChallengeApiVisualCase> cases;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final textTheme = Theme.of(context).textTheme;
    final groups = <String>{for (final item in cases) item.group};

    return Material(
      color: semantic.premium.colorSurface,
      borderRadius: radii.borderRadiusLargeIncreased,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space16,
          children: [
            Text(
              'Featured',
              style: textTheme.labelLarge?.copyWith(
                color: semantic.premium.onColorSurface,
              ),
            ),
            for (final group in groups) ...[
              Text(
                group,
                style: textTheme.labelMedium?.copyWith(
                  color: semantic.premium.onColorSurface.withValues(
                    alpha: 0.76,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.space8,
                children: [
                  for (final item in cases.where((item) => item.group == group))
                    _PremiumChallengeCaseCard(item: item),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PremiumChallengeCaseCard extends StatelessWidget {
  const _PremiumChallengeCaseCard({required this.item});

  final ChallengeApiVisualCase item;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final challenge = item.challenge;
    final model = mapToAtomicCard(
      EnrichedChallenge(dto: challenge),
      progress: item.progress,
      featured: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space4,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(
            color: semantic.premium.onColorSurface.withValues(alpha: 0.84),
            fontWeight: FontWeight.w600,
          ),
        ),
        AtomicChallengeCard(
          title: model.title,
          leftText: model.leftText,
          rightText: model.rightText,
          phase: model.phase,
          fill: model.fill,
          featured: model.featured,
          railTreatment: model.railTreatment,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () {},
        ),
      ],
    );
  }
}
