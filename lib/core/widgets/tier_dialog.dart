import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/profile/presentation/controllers/user_tier_provider.dart';
import 'package:crypto_mobile_app/features/profile/domain/entities/user_tier.dart';

/// Dialog that displays all available tiers and their benefits
/// Shows Basic, Bronze, Gold, and Platinum tiers with slot multipliers
class TierDialog extends ConsumerWidget {
  const TierDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tierState = ref.watch(userTierProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiers',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            _buildTierItem(
              context: context,
              tier: TierLevel.basic,
              currentTier: tierState.currentTier,
              icon: Icons.star_outline,
              iconColor: const Color(0xFF4FC3F7),
              iconBackgroundColor: const Color(0xFFE1F5FE),
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              tier: TierLevel.bronze,
              currentTier: tierState.currentTier,
              icon: Icons.emoji_events,
              iconColor: const Color(0xFFFFB74D),
              iconBackgroundColor: const Color(0xFFFFF3E0),
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              tier: TierLevel.gold,
              currentTier: tierState.currentTier,
              icon: Icons.star,
              iconColor: const Color(0xFFFFD54F),
              iconBackgroundColor: const Color(0xFFFFFDE7),
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              tier: TierLevel.platinum,
              currentTier: tierState.currentTier,
              icon: Icons.diamond,
              iconColor: const Color(0xFF9575CD),
              iconBackgroundColor: const Color(0xFFF3E5F5),
              hasEliteTag: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierItem({
    required BuildContext context,
    required TierLevel tier,
    required TierLevel currentTier,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    bool hasEliteTag = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentTier = tier == currentTier;

    // Calculate point range text
    final pointRange = tier.maxPoints != null
        ? '${tier.minPoints}-${tier.maxPoints} points'
        : '${tier.minPoints}+ points';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      isCurrentTier ? '${tier.name} - Your Tier' : tier.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (hasEliteTag) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9575CD).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✨ Elite',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9575CD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pointRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${tier.slotMultiplier}x slots',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
