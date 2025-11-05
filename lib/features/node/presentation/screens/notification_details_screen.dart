import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/models/notification_payload.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';

class NotificationDetailsScreen extends ConsumerStatefulWidget {
  final NotificationPayload payload;

  const NotificationDetailsScreen({
    super.key,
    required this.payload,
  });

  @override
  ConsumerState<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState
    extends ConsumerState<NotificationDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;

    // Watch node data providers
    final epochRewardsAsync = ref.watch(nodeEpochRewardsProvider);
    final blockchainAsync = ref.watch(nodeBlockchainProvider);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Notification Details',
        showNotifications: false,
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: epochRewardsAsync.when(
          data: (epochRewards) {
            if (epochRewards == null) {
              return _buildEmptyState(context, 'No epoch data available');
            }

            // Handle different notification types
            switch (payload.type) {
              case NotificationPayloadType.grouped:
                return _buildGroupedSlotsView(
                  context,
                  payload.groupedSlots!,
                  epochRewards,
                  blockchainAsync.value,
                );

              case NotificationPayloadType.upcoming:
                return _buildUpcomingSlotView(
                  context,
                  payload.singleSlot!,
                  epochRewards,
                );

              case NotificationPayloadType.produced:
                return _buildProducedSlotView(
                  context,
                  payload.singleSlot!,
                  epochRewards,
                  blockchainAsync.value,
                );

              case NotificationPayloadType.missed:
                return _buildMissedSlotView(
                  context,
                  payload.singleSlot!,
                  epochRewards,
                );
            }
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(context, error.toString()),
        ),
      ),
    );
  }

  /// Build view for grouped slots notification
  Widget _buildGroupedSlotsView(
    BuildContext context,
    List<int> slots,
    RpcEpochRewardsResp epochRewards,
    RpcListBlockchainResp? blockchain,
  ) {
    final theme = Theme.of(context);
    final wonSlots = epochRewards.wonSlots ?? [];
    final producedSlots =
        blockchain?.items.map((b) => b.globalSlot).toSet() ?? {};

    // Find all slots in the group
    final groupSlots = wonSlots.where((s) => slots.contains(s.globalSlot));

    // Calculate stats
    final produced = slots.where((s) => producedSlots.contains(s)).length;
    final pending = slots.length - produced;

    // Find time range
    DateTime? startTime;
    DateTime? endTime;
    if (groupSlots.isNotEmpty) {
      final times = groupSlots.map((s) => DateTime.fromMillisecondsSinceEpoch(
            s.expectedTimeMs.toInt(),
            isUtc: true,
          ).toLocal());
      startTime = times.reduce((a, b) => a.isBefore(b) ? a : b);
      endTime = times.reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final timeFormatter = DateFormat('h:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.rocket_launch,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '${slots.length} Earning Opportunities',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (startTime != null && endTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${timeFormatter.format(startTime)} - ${timeFormatter.format(endTime)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Produced',
                value: '$produced',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Pending',
                value: '$pending',
                icon: Icons.schedule,
                color: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Slots list
        Text(
          'Slots in Group',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ...groupSlots.map((slot) {
          final isProduced = producedSlots.contains(slot.globalSlot);
          final slotTime = DateTime.fromMillisecondsSinceEpoch(
            slot.expectedTimeMs.toInt(),
            isUtc: true,
          ).toLocal();

          return _SlotListItem(
            slotNumber: slot.globalSlot,
            time: timeFormatter.format(slotTime),
            isProduced: isProduced,
            rewardAmount: epochRewards.rewardPerBlock,
          );
        }),
      ],
    );
  }

  /// Build view for upcoming slot notification
  Widget _buildUpcomingSlotView(
    BuildContext context,
    int slotNumber,
    RpcEpochRewardsResp epochRewards,
  ) {
    final theme = Theme.of(context);
    final wonSlot = epochRewards.wonSlots?.cast<RpcEpochWonSlot?>()
        .firstWhere((s) => s?.globalSlot == slotNumber, orElse: () => null);

    if (wonSlot == null) {
      return _buildEmptyState(context, 'Slot #$slotNumber not found');
    }

    final slotTime = DateTime.fromMillisecondsSinceEpoch(
      wonSlot.expectedTimeMs.toInt(),
      isUtc: true,
    ).toLocal();
    final now = DateTime.now();
    final timeUntil = slotTime.difference(now);

    final timeFormatter = DateFormat('h:mm a, MMM d');
    final rewardAmount = epochRewards.rewardPerBlock != null
        ? _formatReward(epochRewards.rewardPerBlock!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade100,
                Colors.orange.shade100,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.monetization_on,
                size: 64,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Upcoming Slot',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot #$slotNumber',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              if (rewardAmount != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Potential: $rewardAmount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Countdown or time info
        _InfoCard(
          icon: Icons.schedule,
          title: timeUntil.isNegative ? 'Slot Time Passed' : 'Time Until Slot',
          value: timeUntil.isNegative
              ? timeFormatter.format(slotTime)
              : _formatDuration(timeUntil),
          subtitle: timeFormatter.format(slotTime),
        ),

        const SizedBox(height: 16),

        // Epoch info
        _InfoCard(
          icon: Icons.layers,
          title: 'Epoch',
          value: '${epochRewards.epoch}',
        ),

        const SizedBox(height: 24),

        // Tips card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep App Open',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Make sure your app stays open and your node is running to produce this block and earn rewards.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build view for produced slot notification
  Widget _buildProducedSlotView(
    BuildContext context,
    int slotNumber,
    RpcEpochRewardsResp epochRewards,
    RpcListBlockchainResp? blockchain,
  ) {
    final theme = Theme.of(context);
    final block = blockchain?.items.cast<RpcStatusBlockInfo?>()
        .firstWhere((b) => b?.globalSlot == slotNumber, orElse: () => null);

    if (block == null) {
      return _buildEmptyState(context, 'Block #$slotNumber not found');
    }

    final rewardAmount = epochRewards.rewardPerBlock != null
        ? _formatReward(epochRewards.rewardPerBlock!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Success header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade100,
                Colors.teal.shade100,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.celebration,
                size: 64,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Block Produced!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot #$slotNumber',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
              if (rewardAmount != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'You earned $rewardAmount!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Block info cards
        _InfoCard(
          icon: Icons.tag,
          title: 'Block Height',
          value: '${block.height}',
        ),

        const SizedBox(height: 12),

        _InfoCard(
          icon: Icons.layers,
          title: 'Epoch',
          value: '${block.epoch}',
        ),

        const SizedBox(height: 12),

        _InfoCard(
          icon: Icons.receipt,
          title: 'Transactions',
          value: '${block.transactions}',
        ),

        const SizedBox(height: 12),

        _InfoCard(
          icon: Icons.folder,
          title: 'Batches',
          value: '${block.batches.length}',
        ),

        const SizedBox(height: 12),

        // Block hash
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Block Hash',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                block.hash.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build view for missed slot notification
  Widget _buildMissedSlotView(
    BuildContext context,
    int slotNumber,
    RpcEpochRewardsResp epochRewards,
  ) {
    final theme = Theme.of(context);
    final wonSlot = epochRewards.wonSlots?.cast<RpcEpochWonSlot?>()
        .firstWhere((s) => s?.globalSlot == slotNumber, orElse: () => null);

    if (wonSlot == null) {
      return _buildEmptyState(context, 'Slot #$slotNumber not found');
    }

    final slotTime = DateTime.fromMillisecondsSinceEpoch(
      wonSlot.expectedTimeMs.toInt(),
      isUtc: true,
    ).toLocal();
    final timeFormatter = DateFormat('h:mm a, MMM d');

    // Find next upcoming slots
    final now = DateTime.now();
    final upcomingSlots = (epochRewards.wonSlots ?? [])
        .where((s) {
          final time = DateTime.fromMillisecondsSinceEpoch(
            s.expectedTimeMs.toInt(),
            isUtc: true,
          ).toLocal();
          return time.isAfter(now);
        })
        .take(3)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade100,
                Colors.amber.shade100,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Slot Missed',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot #$slotNumber',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                timeFormatter.format(slotTime),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Why it happened section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Common Reasons',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _TipRow(icon: Icons.phone_android, text: 'App was not running'),
              const SizedBox(height: 8),
              _TipRow(icon: Icons.signal_wifi_off, text: 'Network connection issue'),
              const SizedBox(height: 8),
              _TipRow(icon: Icons.cloud_off, text: 'Node was not synced'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Next opportunities
        if (upcomingSlots.isNotEmpty) ...[
          Text(
            'Next Opportunities',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Keep app open for:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...upcomingSlots.map((slot) {
                  final time = DateTime.fromMillisecondsSinceEpoch(
                    slot.expectedTimeMs.toInt(),
                    isUtc: true,
                  ).toLocal();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slot #${slot.globalSlot}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          timeFormatter.format(time),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatReward(BigInt rewardInSmallestUnit) {
    final divisor = BigInt.from(1000000000);
    if (rewardInSmallestUnit == BigInt.zero) return '0 TKN';

    final mainUnits = rewardInSmallestUnit ~/ divisor;
    final remainder = rewardInSmallestUnit % divisor;

    if (remainder == BigInt.zero) {
      return '$mainUnits TKN';
    } else {
      final decimal = remainder.toDouble() / divisor.toDouble();
      final totalValue = mainUnits.toDouble() + decimal;

      if (totalValue < 0.01) {
        return '~${totalValue.toStringAsFixed(4)} TKN';
      } else if (totalValue < 1) {
        return '~${totalValue.toStringAsFixed(3)} TKN';
      } else {
        return '~${totalValue.toStringAsFixed(2)} TKN';
      }
    }
  }
}

// Helper widgets

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotListItem extends StatelessWidget {
  final int slotNumber;
  final String time;
  final bool isProduced;
  final BigInt? rewardAmount;

  const _SlotListItem({
    required this.slotNumber,
    required this.time,
    required this.isProduced,
    this.rewardAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isProduced
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isProduced ? Icons.check : Icons.schedule,
              color: isProduced ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot #$slotNumber',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isProduced)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Produced',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
