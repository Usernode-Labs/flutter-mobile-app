import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';

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
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final onColor = semantic.community.onColor;
    final dimOnColor = onColor.withValues(alpha: 0.8);

    Widget? proofFooter;
    if (isComplete) {
      proofFooter = registration.whenOrNull(
        data: (reg) {
          final date = reg.registeredAtMs != null
              ? DateFormat.yMMMd().format(
                  DateTime.fromMillisecondsSinceEpoch(reg.registeredAtMs!),
                )
              : null;

          String? truncatedNullifier;
          if (reg.nullifierHex != null && reg.nullifierHex!.length >= 12) {
            final hex = reg.nullifierHex!;
            truncatedNullifier =
                '${hex.substring(0, 8)}...${hex.substring(hex.length - 4)}';
          }

          return ZkProofDetailSection(
            heading: 'Proof of Humanity',
            description:
                'Your passport was verified using a zero-knowledge proof. '
                'No personal data was shared or stored.',
            onColor: onColor,
            dimOnColor: dimOnColor,
            rows: [
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
              if (date != null)
                (
                  icon: Symbols.calendar_today_sharp,
                  label: 'Verified',
                  value: date,
                  monospace: false,
                  onTap: null,
                ),
              if (truncatedNullifier != null)
                (
                  icon: Symbols.fingerprint_sharp,
                  label: 'Proof ID',
                  value: truncatedNullifier,
                  monospace: true,
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: reg.nullifierHex!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
            ],
          );
        },
      );
    }

    const title = 'ZK Identity Verification';
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
    final whyText = challengeDto?.description ?? challengeDto?.goal ??
        'Verify your identity with ZK Passport';
    if (whyText.isNotEmpty) {
      sections.add((title: l10n.challengeSectionTheWhy, body: whyText));
    }
    final taskText = challengeDto?.task ??
        'Use the ZK Passport app to create a zero-knowledge proof of your passport.';
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
                footer: proofFooter,
              )
            : null,
        sections: sections,
        totalRewardHeading: isComplete ? null : l10n.challengeTotalReward(rewardText),
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
                  label: isActive ? 'Continue' : 'Start Verification',
                  onTap: () => context.push(AppRoutes.zkIdentityFlow),
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                ),
              ),
            ),
    );
  }
}
