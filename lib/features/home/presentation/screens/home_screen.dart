import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/horizontal_card_scroll.dart';
import 'package:crypto_mobile_app/core/widgets/activity_list_item.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/screens/rewards_breakdown_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Use scaffold defaults from theme for proper light/dark support
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              centerTitle: false,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with tier and points
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star_outline,
                            color: colorScheme.onSecondaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Basic Tier',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '0 points',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Horizontal action cards (kept as requested)
              const SizedBox(height: 196, child: HorizontalCardScroll()),

              const SizedBox(height: 20),

              // Rewards and projection card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // This epoch's rewards section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'This epoch\'s rewards (Basic Tier)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Breakdown',
                            icon: Icon(Icons.bar_chart_rounded,
                                color: colorScheme.primary),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RewardsBreakdownScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Rewards amount
                      Text(
                        '2200 TKN',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Progress bar and epoch info
                      ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(3)),
                        child: LinearProgressIndicator(
                          value: 0.8,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary),
                          minHeight: 6,
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
                            ),
                          ),
                          Text(
                            '12h left',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Next epoch projection
                      Text(
                        'Next epoch projection (Bronze Tier)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '~2450 TKN',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your next epoch\'s rate is higher. Well done!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Recent Activity section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Recent Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Activity item
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ActivityListItem(
                  icon: Icons.verified_user,
                  title: 'Identity verified',
                  trailing: '+50 points',
                ),
              ),
              const SizedBox(height: 12),

              // Second activity item for visual balance
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ActivityListItem(
                  key: const ValueKey('activity-bridge'),
                  icon: Icons.swap_horiz,
                  title: 'Bridge deposit completed',
                  trailing: '+1.5x bonus',
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
