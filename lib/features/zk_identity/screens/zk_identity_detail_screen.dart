import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
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

    const config = ZkIdentityChallengeConfig.instance;
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

    return Scaffold(
      body: ChallengeDetailPage(
        title: config.title,
        category: ChallengeCategory.community,
        dateRange: 'Community \u00b7 Ongoing',
        rewardCard: isComplete
            ? ChallengeRewardCard(
                category: ChallengeCategory.community,
                totalEarned: config.reward,
                data: const SimpleRewardData(),
                footer: proofFooter,
              )
            : null,
        sections: [
          (title: l10n.challengeSectionTheWhy, body: config.goal),
          (title: l10n.challengeSectionTask, body: config.task),
        ],
        totalRewardHeading: isComplete
            ? null
            : l10n.challengeTotalReward('${config.reward} pts'),
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
