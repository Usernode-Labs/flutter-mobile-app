import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';

class RewardsBreakdownScreen extends StatelessWidget {
  const RewardsBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Rewards Breakdown',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current epoch section
            _buildCurrentEpochSection(theme, colorScheme),
            const SizedBox(height: 20),

            // Reward sources
            _buildRewardSource(
              theme,
              colorScheme,
              'Basic Tier',
              'Tiers unlock block production rights',
              '120 Slots',
              null,
            ),
            const SizedBox(height: 8),
            _buildRewardSource(
              theme,
              colorScheme,
              '100 Blocks Produced',
              '20 Slots remaining',
              '1221 TKN',
              null,
            ),
            const SizedBox(height: 8),
            _buildRewardSource(
              theme,
              colorScheme,
              '1 Missed Block',
              null,
              '0 TKN',
              null,
            ),

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Next epoch projections
            _buildNextEpochSection(theme, colorScheme),
            const SizedBox(height: 20),

            // Tier options
            _buildTierOption(
              theme,
              colorScheme,
              'Bronze +2.5% - Your Tier',
              '~130 Slots Expected',
              '~3200 TKN',
              true,
            ),
            const SizedBox(height: 8),
            _buildTierOption(
              theme,
              colorScheme,
              'Gold +5%',
              '~140 Slots Expected',
              '~4200 TKN',
              false,
            ),
            const SizedBox(height: 8),
            _buildTierOption(
              theme,
              colorScheme,
              'Platinum +10%',
              '~140 Slots Expected',
              '~5200 TKN',
              false,
            ),

            const SizedBox(height: 24),

            // Explanatory text
            _buildExplanatoryText(theme, colorScheme),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ));
  }

  Widget _buildCurrentEpochSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'This Epoch\'s Calculation',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
            Text(
              '600,000 Tokens staked',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '2200 TKN',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),

        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: const Color(0xFFE8E8E8),
          ),
          child: FractionallySizedBox(
            widthFactor: 0.8,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFF4A90E2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Epoch 1',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            Text(
              '12h left',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardSource(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String? subtitle,
    String amount,
    String? badge,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFD6D9FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w400,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextEpochSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Projected to earn in next epoch',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
            Text(
              '600,000 Tokens staked',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '~3200 TKN',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildTierOption(
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
    String subtitle,
    String amount,
    bool isCurrentTier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFD6D9FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanatoryText(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A quick heads-up on these projections',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Think of these numbers as a close estimate. Since final rewards depend on {VRF EXPLAINED}, the exact total can change a little by the time the next epoch begins. Also, to keep everything running smoothly, your tier for the next epoch gets locked in when the current one is about two-thirds complete. For you, it\'s already set to Bronze—nice work!',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
