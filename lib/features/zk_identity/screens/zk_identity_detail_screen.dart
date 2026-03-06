import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';

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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

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
              )
            : null,
        sections: [
          (title: l10n.challengeSectionTheWhy, body: config.goal),
          (title: l10n.challengeSectionTask, body: config.task),
        ],
        extraCard: isComplete
            ? registration.whenOrNull(
                data: (reg) => _VerificationResultCard(
                  registration: reg,
                  colors: colors,
                  textTheme: textTheme,
                  spacing: spacing,
                  radii: radii,
                ),
              )
            : null,
        totalRewardHeading: l10n.challengeTotalReward('${config.reward} pts'),
        totalRewardBody: '',
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
                child: FilledButton(
                  onPressed: () => context.push(AppRoutes.zkIdentityFlow),
                  child: Text(isActive ? 'Continue' : 'Start Verification'),
                ),
              ),
            ),
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  const _VerificationResultCard({
    required this.registration,
    required this.colors,
    required this.textTheme,
    required this.spacing,
    required this.radii,
  });

  final ZkPassportLocalRegistration registration;
  final ColorScheme colors;
  final TextTheme textTheme;
  final AppSpacing spacing;
  final AppRadii radii;

  @override
  Widget build(BuildContext context) {
    final date = registration.registeredAtMs != null
        ? DateFormat.yMMMd().format(
            DateTime.fromMillisecondsSinceEpoch(registration.registeredAtMs!),
          )
        : null;

    String? truncatedNullifier;
    if (registration.nullifierHex != null &&
        registration.nullifierHex!.length >= 12) {
      final hex = registration.nullifierHex!;
      truncatedNullifier =
          '${hex.substring(0, 8)}...${hex.substring(hex.length - 4)}';
    }

    return AppCard(
      color: colors.surfaceContainerLowest,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.verified_sharp, color: colors.primary, size: 20),
              SizedBox(width: spacing.space8),
              Text(
                'Verification Result',
                style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          SizedBox(height: spacing.space12),
          Text(
            'Your passport identity was verified using a zero-knowledge '
            'proof. No personal data was shared or stored.',
            style:
                textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (date != null) ...[
            SizedBox(height: spacing.space12),
            _ResultRow(
              label: 'Verified on',
              value: date,
              textTheme: textTheme,
              colors: colors,
            ),
          ],
          if (truncatedNullifier != null) ...[
            SizedBox(height: spacing.space8),
            _ResultRow(
              label: 'Identifier',
              value: truncatedNullifier,
              textTheme: textTheme,
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.textTheme,
    required this.colors,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }
}
