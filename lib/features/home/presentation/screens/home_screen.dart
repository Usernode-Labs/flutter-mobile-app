import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:crypto_mobile_app/core/widgets/activity_list_item.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/core/widgets/hero_action_card.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/controllers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/sync_status_provider.dart';
import 'package:crypto_mobile_app/core/widgets/won_slot_item.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh epoch rewards when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Log.d('HOME_SCREEN',
          'Invalidating epochRewardsUiProvider to trigger refresh');
      ref.invalidate(epochRewardsUiProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppAppBar(
        title: 'Home',
      ),
      drawer: const AppDrawer(),
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
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.4)),
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

              // Hero action cards - horizontal scroll
              SizedBox(
                height: 140,
                child: FutureBuilder<List<dynamic>>(
                  future:
                      AccountsRepository.create().then((repo) => repo.list()),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    final activeAccount =
                        accounts.isNotEmpty ? accounts.first : null;
                    final isIdentityVerified =
                        activeAccount?.identityVerified ?? false;
                    final cardWidth = MediaQuery.of(context).size.width * 0.8;

                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      children: [
                        // Identity verification card - dynamic based on status
                        HeroActionCard(
                          width: cardWidth,
                          icon: isIdentityVerified
                              ? Icons.verified_user
                              : Icons.badge,
                          title: isIdentityVerified
                              ? 'Identity Verified ✓'
                              : 'Boost Your Tier',
                          subtitle: isIdentityVerified
                              ? 'Update your verification to maintain benefits'
                              : 'Verify your identity to unlock premium features',
                          gradientColors: [
                            Color.lerp(colorScheme.primary, Colors.white, 0.4)!,
                            Color.lerp(colorScheme.primary, Colors.white, 0.1)!,
                          ],
                          onTap: () {
                            if (activeAccount != null) {
                              context.go(
                                  '/identity-verification?accountId=${activeAccount.id}');
                            }
                          },
                        ),

                        // Lock tokens for yield card
                        HeroActionCard(
                          width: cardWidth,
                          icon: Icons.lock,
                          title: 'Lock for Rewards',
                          subtitle:
                              'Lock USDC and tokens for yield and participation bonuses',
                          gradientColors: [
                            Color.lerp(
                                colorScheme.tertiary, Colors.white, 0.4)!,
                            Color.lerp(
                                colorScheme.tertiary, Colors.white, 0.1)!,
                          ],
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Token locking coming soon')),
                            );
                          },
                        ),

                        // Invite friends card
                        HeroActionCard(
                          width: cardWidth,
                          icon: Icons.people,
                          title: 'Invite Friends',
                          subtitle:
                              'Share the app and earn rewards for each referral',
                          gradientColors: [
                            Color.lerp(
                                colorScheme.secondary, Colors.white, 0.4)!,
                            Color.lerp(
                                colorScheme.secondary, Colors.white, 0.1)!,
                          ],
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Referral program coming soon')),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Rewards and projection card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Consumer(builder: (ctx, ref, _) {
                    final syncStatus = ref.watch(syncStatusProvider);
                    final rewardsAsync = ref.watch(epochRewardsUiProvider);

                    // If node is not synced, show skeleton with sync message
                    if (!syncStatus.isSynced) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sync,
                                    size: 16, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Node syncing... Rewards data will display when fully synced',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Skeleton placeholders
                          Skeletonizer(
                            enabled: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildRewardsSection(
                                context,
                                colorScheme,
                                theme,
                                null,
                                true,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Node is synced, show actual data
                    return rewardsAsync.when(
                      loading: () => Skeletonizer(
                        enabled: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildRewardsSection(
                            context,
                            colorScheme,
                            theme,
                            null,
                            true,
                          ),
                        ),
                      ),
                      error: (e, st) => Skeletonizer(
                        enabled: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildRewardsSection(
                            context,
                            colorScheme,
                            theme,
                            null,
                            true,
                          ),
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
                            false,
                          ),
                          if (ui?.isCached == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.5)),
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

              const SizedBox(height: 24),

              // Scheduled Activity (Upcoming Won Slots)
              Consumer(builder: (ctx, ref, _) {
                final rewardsUiAsync = ref.watch(epochRewardsUiProvider);
                return rewardsUiAsync.when(
                  loading: () =>
                      _buildSkeletonSlots(context, theme, colorScheme),
                  error: (e, st) =>
                      _buildSkeletonSlots(context, theme, colorScheme),
                  data: (ui) {
                    final wonSlots = ui?.snapshot?.wonSlots;
                    if (wonSlots == null || wonSlots.isEmpty) {
                      return _buildSkeletonSlots(context, theme, colorScheme);
                    }
                    final now = DateTime.now().toUtc();
                    final upcoming = wonSlots
                        .where((slot) => DateTime.fromMillisecondsSinceEpoch(
                                slot.expectedTimeMs.toInt(),
                                isUtc: true)
                            .isAfter(now))
                        .take(1)
                        .toList();
                    if (upcoming.isEmpty) {
                      return _buildSkeletonSlots(context, theme, colorScheme);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Scheduled Activity',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...upcoming.map((slot) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                  trailing: '+1x bonus',
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

  String _formatTokenAmount(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }

  List<Widget> _buildRewardsSection(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    dynamic snapshot, // EpochRewardsSnapshot? but avoid import type bleed here
    bool isLoading,
  ) {
    Log.d('HOME_SCREEN', 'Building rewards section with snapshot: $snapshot');
    BigInt? earned;
    BigInt? expected;
    int? epoch;
    int? produced;
    int? wins;
    BigInt? rewardPerBlock;
    if (snapshot != null) {
      try {
        Log.d(
            'HOME_SCREEN', 'Snapshot earnedSoFar raw: ${snapshot.earnedSoFar}');
        Log.d('HOME_SCREEN',
            'Snapshot expectedTotal raw: ${snapshot.expectedTotal}');
        earned = BigInt.parse(snapshot.earnedSoFar as String);
        expected = BigInt.parse(snapshot.expectedTotal as String);
        epoch = snapshot.epoch as int;
        produced = snapshot.producedInEpoch as int;
        wins = snapshot.winsInEpoch as int;
        rewardPerBlock = BigInt.parse(snapshot.rewardPerBlock as String);
        Log.d('HOME_SCREEN',
            'Parsed earned: $earned, expected: $expected, epoch: $epoch');
      } catch (e) {
        Log.e('HOME_SCREEN', 'Error parsing snapshot', e, StackTrace.current);
      }
    } else {
      Log.d('HOME_SCREEN', 'Snapshot is null');
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
            onPressed: () => context.push('/rewards'),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Rewards amount
      earned != null
          ? Text(
              '${_formatTokenAmount(earned)} TKN',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            )
          : Bone.text(
              words: 2,
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
          epoch != null
              ? Text(
                  'Epoch $epoch',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : Bone.text(
                  words: 2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          Flexible(
            child: (produced != null && wins != null)
                ? Text(
                    '$produced / $wins blocks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : Bone.text(
                    words: 3,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
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
      expected != null
          ? Text(
              '~${_formatTokenAmount(expected)} TKN',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            )
          : Bone.text(
              words: 2,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
      const SizedBox(height: 4),
      (wins != null && rewardPerBlock != null)
          ? Text(
              'Based on $wins won slots at ${_formatTokenAmount(rewardPerBlock)} per block',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : Bone.text(
              words: 8,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    ];
  }

  Widget _buildSkeletonSlots(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scheduled Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: null,
                child: Text('View All',
                    style: TextStyle(color: colorScheme.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Skeletonizer(
          enabled: true,
          child: Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Bone.text(
                              words: 2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Bone.text(
                              words: 3,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Bone.text(
                          words: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
