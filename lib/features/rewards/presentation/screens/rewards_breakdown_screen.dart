import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/won_slot_item.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

class RewardsBreakdownScreen extends StatefulWidget {
  const RewardsBreakdownScreen({super.key});

  @override
  State<RewardsBreakdownScreen> createState() => _RewardsBreakdownScreenState();
}

class _RewardsBreakdownScreenState extends State<RewardsBreakdownScreen> {
  RpcEpochRewardsResp? _epochRewards;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEpochRewards();
  }

  Future<void> _loadEpochRewards() async {
    try {
      Log.d('REWARDS', 'Loading epoch rewards');
      final rewards = await RustBackendService.instance.epochRewards();
      if (!mounted) return;
      setState(() {
        _epochRewards = rewards;
        _isLoading = false;
      });
      Log.d('REWARDS', 'Epoch rewards loaded: ${rewards != null}');
    } catch (e, st) {
      Log.e('REWARDS', 'Failed to load epoch rewards', e, st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Rewards Breakdown',
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _epochRewards == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load rewards data',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadEpochRewards,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadEpochRewards,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current epoch section
                          _buildCurrentEpochSection(theme, colorScheme),
                          const SizedBox(height: 20),

                          // Reward breakdown
                          _buildRewardSource(
                            theme,
                            colorScheme,
                            'Blocks Produced',
                            '${_epochRewards!.producedInEpoch} blocks produced this epoch',
                            '${_epochRewards!.earnedSoFar} TKN',
                            Icons.check_circle,
                          ),
                          const SizedBox(height: 8),
                          _buildRewardSource(
                            theme,
                            colorScheme,
                            'Won Slots',
                            '${_epochRewards!.winsInEpoch} slots won this epoch',
                            '${_epochRewards!.winsInEpoch - _epochRewards!.producedInEpoch} remaining',
                            Icons.emoji_events,
                          ),
                          const SizedBox(height: 8),
                          _buildRewardSource(
                            theme,
                            colorScheme,
                            'Reward per Block',
                            'Each produced block earns',
                            '${_epochRewards!.rewardPerBlock} TKN',
                            Icons.attach_money,
                          ),

                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Expected total section
                          _buildExpectedTotalSection(theme, colorScheme),

                          // Won slots timeline
                          if (_epochRewards!.wonSlots != null && _epochRewards!.wonSlots!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _buildWonSlotsSection(theme, colorScheme),
                          ],

                          // Explanatory text
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          _buildExplanatoryText(theme, colorScheme),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildCurrentEpochSection(ThemeData theme, ColorScheme colorScheme) {
    final progress = _epochRewards!.expectedTotal > BigInt.zero
        ? _epochRewards!.earnedSoFar.toDouble() / _epochRewards!.expectedTotal.toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Epoch ${_epochRewards!.epoch}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
            if (_epochRewards!.producerPubkey != null)
              Text(
                'Producer: ${_shortenMid(_epochRewards!.producerPubkey!, head: 6, tail: 6)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_epochRewards!.earnedSoFar} TKN',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Earned so far',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_epochRewards!.producedInEpoch} / ${_epochRewards!.winsInEpoch} blocks produced',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
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
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 24),
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
                      fontSize: 14,
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
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedTotalSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expected total for epoch',
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
          '${_epochRewards!.expectedTotal} TKN',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on ${_epochRewards!.winsInEpoch} won slots at ${_epochRewards!.rewardPerBlock} TKN per block',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildWonSlotsSection(ThemeData theme, ColorScheme colorScheme) {
    final wonSlots = _epochRewards!.wonSlots!;
    final now = DateTime.now().toUtc();

    // Separate into upcoming and past slots
    final upcomingSlots = wonSlots.where((slot) {
      final slotTime = DateTime.fromMillisecondsSinceEpoch(
        slot.expectedTimeMs.toInt(),
        isUtc: true,
      );
      return slotTime.isAfter(now);
    }).toList();

    final pastSlots = wonSlots.where((slot) {
      final slotTime = DateTime.fromMillisecondsSinceEpoch(
        slot.expectedTimeMs.toInt(),
        isUtc: true,
      );
      return !slotTime.isAfter(now);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Won Slots Timeline',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // Summary
        Text(
          '${wonSlots.length} total slots • ${upcomingSlots.length} upcoming • ${pastSlots.length} past',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Display upcoming slots first
        if (upcomingSlots.isNotEmpty) ...[
          Text(
            'Upcoming Slots',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...upcomingSlots.map((slot) => WonSlotItem(
                slot: slot,
                status: SlotStatus.pending,
              )),
        ],

        // Display past slots
        if (pastSlots.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Past Slots',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...pastSlots.map((slot) {
            // Determine if produced or missed
            // For now, assume produced (would need blockchain data to verify)
            return WonSlotItem(
              slot: slot,
              status: SlotStatus.produced,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildExplanatoryText(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About These Rewards',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rewards are earned by producing blocks during your won slots. Each epoch, you are assigned slots based on your stake and VRF selection. The total rewards depend on successfully producing blocks in those slots.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The "Expected Total" is calculated based on all your won slots. Your actual earnings may vary if any blocks are missed.',
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

  String _shortenMid(String s, {int head = 6, int tail = 6}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
  }
}
