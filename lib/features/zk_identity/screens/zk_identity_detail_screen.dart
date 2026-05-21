import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zk_identity/zk_identity_status_mapper.dart';

class ZkIdentityDetailScreen extends ConsumerWidget {
  const ZkIdentityDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = ref.watch(
      zkIdentityIsCompleteProvider.select(
        (v) => v.maybeWhen(data: (d) => d, orElse: () => false),
      ),
    );
    final registration = ref.watch(zkIdentityRegistrationProvider);
    final isActive = ref.watch(zkIdentityChallengeActiveProvider);

    final challengeDto = ref.watch(zkIdentityChallengeDtoProvider);
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    Widget? statusCard;
    if (isComplete) {
      statusCard = registration.whenOrNull(
        data: (reg) {
          return ZkIdentityStatusCard(
            data: buildZkIdentityStatusData(
              reg,
              l10n,
              onCopyProofId: reg.nullifierHex != null
                  ? () {
                      Clipboard.setData(
                        ClipboardData(text: reg.nullifierHex!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')),
                      );
                    }
                  : null,
            ),
          );
        },
      );
    }

    final title = l10n.zkIdentityChallengeTitle;
    final reward = challengeDto?.reward ?? '500';
    final rewardText = formatRewardText(reward);

    // ChallengeRewardCard appends "pts" — pass numeric-only value.
    // reward may be "500" (plain) or "Up to 1,500 pts" (pre-formatted).
    final earnedNumeric = int.tryParse(reward) ?? parseRewardCeiling(reward);
    final totalEarned =
        earnedNumeric != null ? formatPoints(earnedNumeric) : '--';

    // Build sections following the generic challenge detail pattern:
    // "The Why" uses description (falls back to goal), "Task" uses task.
    final sections = <({String title, String body})>[];
    final whyText = challengeDto?.description ??
        challengeDto?.goal ??
        l10n.zkIdentityChallengeWhyFallback;
    if (whyText.isNotEmpty) {
      sections.add((title: l10n.challengeSectionTheWhy, body: whyText));
    }
    final taskText = challengeDto?.task ?? l10n.zkIdentityChallengeTaskFallback;
    if (taskText.isNotEmpty) {
      sections.add((title: l10n.challengeSectionTask, body: taskText));
    }
    final requirements = challengeDto?.requirements;
    if (requirements != null && requirements.isNotEmpty) {
      sections.add(
        (title: l10n.challengeSectionRequirements, body: requirements),
      );
    }

    return Scaffold(
      body: ChallengeDetailPage(
        title: title,
        category: ChallengeCategory.community,
        dateRange: 'Community \u00b7 Ongoing',
        rewardCard: isComplete
            ? ChallengeRewardCard(
                category: ChallengeCategory.community,
                totalEarned: totalEarned,
                data: const SimpleRewardData(),
              )
            : null,
        statusSection: statusCard,
        sections: sections,
        totalRewardHeading:
            isComplete ? null : l10n.challengeTotalReward(rewardText),
        totalRewardBody: isComplete ? null : '',
        onBackTap: () => context.pop(),
      ),
      bottomNavigationBar: isComplete
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space12,
                ),
                child: Button(
                  label: isActive
                      ? l10n.zkIdentityDetailContinueCta
                      : l10n.zkIdentityDetailStartCta,
                  onTap: () => context.push(AppRoutes.zkIdentityFlow),
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                ),
              ),
            ),
    );
  }
}
