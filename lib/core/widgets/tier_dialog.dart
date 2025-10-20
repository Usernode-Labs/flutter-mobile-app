import 'package:flutter/material.dart';

/// Dialog that displays all available tiers and their benefits
/// Shows Basic, Bronze, Gold, and Platinum tiers with expected slots and rewards
class TierDialog extends StatelessWidget {
  const TierDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              icon: Icons.star_outline,
              iconColor: const Color(0xFF4FC3F7),
              iconBackgroundColor: const Color(0xFFE1F5FE),
              title: 'Basic - Your Tier',
              subtitle: '~100 Slots Expected',
              reward: 'Reward ~2000 TKN',
              isCurrentTier: true,
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              icon: Icons.emoji_events,
              iconColor: const Color(0xFFFFB74D),
              iconBackgroundColor: const Color(0xFFFFF3E0),
              title: 'Bronze',
              subtitle: '~130 Slots Expected',
              reward: '~2200 TKN',
              isCurrentTier: false,
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              icon: Icons.star,
              iconColor: const Color(0xFFFFD54F),
              iconBackgroundColor: const Color(0xFFFFFDE7),
              title: 'Gold',
              subtitle: '~140 Slots Expected',
              reward: '~2600 TKN',
              isCurrentTier: false,
            ),
            const SizedBox(height: 16),
            _buildTierItem(
              context: context,
              icon: Icons.diamond,
              iconColor: const Color(0xFF9575CD),
              iconBackgroundColor: const Color(0xFFF3E5F5),
              title: 'Platinum',
              subtitle: '~140 Slots Expected',
              reward: '~3200 TKN',
              isCurrentTier: false,
              hasEliteTag: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    required String subtitle,
    required String reward,
    required bool isCurrentTier,
    bool hasEliteTag = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                      title,
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
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          reward,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
