import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/services/challenge_api_visual_fixture.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

part 'api_challenge_contract_matrix.stories.g.dart';

const meta = Meta<ApiChallengeContractMatrix>(path: 'prototypes/challenges');

final $Default = _Story(
  name: 'API contract matrix',
  setup: (context, child, args) {
    return SizedBox(width: 430, height: 1200, child: child);
  },
  scenarios: [_Scenario(name: 'Current MobileApiController shapes')],
);

/// Visual contract matrix built from raw current mobile API response shapes.
class ApiChallengeContractMatrix extends StatelessWidget {
  const ApiChallengeContractMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;
    final cases = ChallengeApiVisualFixture.cases;
    final groups = <String>{for (final item in cases) item.group};

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space16,
          children: [
            Text('API challenge contract', style: textTheme.headlineSmall),
            Text(
              'Raw /mobile/challenges + /me/breakdown shapes parsed through production models.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            for (final group in groups) ...[
              Text(
                group,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.space8,
                children: [
                  for (final item in cases.where((item) => item.group == group))
                    _ApiChallengeCaseCard(item: item),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApiChallengeCaseCard extends StatelessWidget {
  const _ApiChallengeCaseCard({required this.item});

  final ChallengeApiVisualCase item;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final challenge = item.challenge;
    final model = mapToAtomicCard(
      EnrichedChallenge(dto: challenge),
      progress: item.progress,
      featured: challenge.featured,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space4,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        AtomicChallengeCard(
          title: model.title,
          leftText: model.leftText,
          rightText: model.rightText,
          phase: model.phase,
          fill: model.fill,
          railTreatment: model.railTreatment,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () {},
        ),
      ],
    );
  }
}
