import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/core/design/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/activity_list_item.dart';
import 'package:crypto_mobile_app/core/widgets/app_action_button.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/screens/rewards_breakdown_screen.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/controllers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/widgets/won_slot_item.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/receive_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppAppBar(
        title: 'Home',
        actions: [
          Consumer(builder: (ctx, ref, _) {
            return IconButton(
              icon: const Icon(Icons.brightness_6_outlined),
              tooltip: 'Cycle Theme',
              onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
            );
          }),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
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
              const SizedBox(height: 16),

              // Quick Actions Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.arrow_upward,
                            label: 'Send',
                            color: colorScheme.primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SendScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.arrow_downward,
                            label: 'Receive',
                            color: colorScheme.tertiary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReceiveScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.swap_horiz,
                            label: 'Swap',
                            color: colorScheme.secondary,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Swap coming soon')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.account_balance,
                            label: 'Bridge',
                            color: colorScheme.primary,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bridge coming soon')),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.lock,
                            label: 'Stake',
                            color: colorScheme.tertiary,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Staking coming soon')),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: AppActionButton(
                            icon: Icons.card_giftcard,
                            label: 'Rewards',
                            color: colorScheme.secondary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RewardsBreakdownScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Rewards and projection card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Consumer(builder: (ctx, ref, _) {
                    final rewardsAsync = ref.watch(epochRewardsUiProvider);
                    return rewardsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, st) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildRewardsSection(
                          context,
                          colorScheme,
                          theme,
                          null,
                        ),
                      ),
                      data: (ui) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._buildRewardsSection(
                            context,
                            colorScheme,
                            theme,
                            ui?.snapshot,
                          ),
                          if (ui?.isCached == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    ui!.isStale ? 'Cached (stale)' : 'Cached',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 28),

              // Upcoming Won Slots (live-only)
              Consumer(builder: (ctx, ref, _) {
                final liveAsync = ref.watch(_liveEpochRewardsProvider);
                return liveAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (rewards) {
                    if (rewards == null || rewards.wonSlots == null || rewards.wonSlots!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final now = DateTime.now().toUtc();
                    final upcoming = rewards.wonSlots!
                        .where((slot) => DateTime.fromMillisecondsSinceEpoch(slot.expectedTimeMs.toInt(), isUtc: true).isAfter(now))
                        .take(3)
                        .toList();
                    if (upcoming.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Upcoming Slots',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const RewardsBreakdownScreen(),
                                    ),
                                  );
                                },
                                child: Text('View All', style: TextStyle(color: colorScheme.primary)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...upcoming.map((slot) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: WonSlotItem(
                                slot: slot,
                                status: SlotStatus.pending,
                                isCompact: true,
                              ),
                            )),
                        const SizedBox(height: 28),
                      ],
                    );
                  },
                );
              }),

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

  List<Widget> _buildRewardsSection(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    dynamic snapshot, // EpochRewardsSnapshot? but avoid import type bleed here
  ) {
    BigInt? earned;
    BigInt? expected;
    int? epoch;
    int? produced;
    int? wins;
    BigInt? rewardPerBlock;
    if (snapshot != null) {
      try {
        earned = BigInt.parse(snapshot.earnedSoFar as String);
        expected = BigInt.parse(snapshot.expectedTotal as String);
        epoch = snapshot.epoch as int;
        produced = snapshot.producedInEpoch as int;
        wins = snapshot.winsInEpoch as int;
        rewardPerBlock = BigInt.parse(snapshot.rewardPerBlock as String);
      } catch (_) {}
    }

    return [
      // This epoch's rewards section
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'This epoch\'s rewards',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Breakdown',
            icon: Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RewardsBreakdownScreen()),
              );
            },
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Rewards amount
      Text(
        earned != null ? '$earned TKN' : '— TKN',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      const SizedBox(height: 12),

      // Progress bar and epoch info
      ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        child: LinearProgressIndicator(
          value: (earned != null && expected != null && expected > BigInt.zero)
              ? (earned.toDouble() / expected.toDouble())
              : 0.0,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          minHeight: 6,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            epoch != null ? 'Epoch $epoch' : 'Epoch —',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            (produced != null && wins != null) ? '$produced / $wins blocks' : '—',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Next epoch projection
      Text(
        'Next epoch projection',
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        expected != null ? '~$expected TKN' : '— TKN',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        (wins != null && rewardPerBlock != null)
            ? 'Based on $wins won slots at $rewardPerBlock per block'
            : 'Loading projection...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}

// Live-only provider for upcoming slots section
final _liveEpochRewardsProvider = FutureProvider<RpcEpochRewardsResp?>((ref) async {
  try {
    return await RustBackendService.instance.epochRewards();
  } catch (_) {
    return null;
  }
});
