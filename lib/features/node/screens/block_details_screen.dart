import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class BlockDetailsScreen extends StatefulWidget {
  final RpcStatusBlockInfo block;

  const BlockDetailsScreen({
    super.key,
    required this.block,
  });

  @override
  State<BlockDetailsScreen> createState() => _BlockDetailsScreenState();
}

class _BlockDetailsScreenState extends State<BlockDetailsScreen> {
  late List<int> timings;

  @override
  void initState() {
    super.initState();
    timings = _generateTimings();
  }

  /// Generate random timings for each step with total not exceeding 400ms
  /// Steps 1-6: 5-149ms, Step 7 (Block Confirmed): 150-250ms
  List<int> _generateTimings() {
    final random = Random();
    const int stepCount = 7;
    const int minMs = 5;
    const int maxMs = 149;
    const int lastStepMinMs = 150;
    const int lastStepMaxMs = 250;
    const int maxTotal = 400;

    // First, generate the last step value (Block Confirmed) between 150-250ms
    int lastStepValue =
        lastStepMinMs + random.nextInt(lastStepMaxMs - lastStepMinMs + 1);

    // Calculate remaining budget for first 6 steps
    int remainingBudget = maxTotal - lastStepValue;

    // Generate values for first 6 steps within the remaining budget
    List<int> values = [];

    // Start with random values in the 5-149ms range
    for (int i = 0; i < stepCount - 1; i++) {
      values.add(minMs + random.nextInt(maxMs - minMs + 1));
    }

    // Calculate sum of first 6 steps
    int firstSixSum = values.reduce((a, b) => a + b);

    // If first 6 steps exceed remaining budget, scale them down
    if (firstSixSum > remainingBudget) {
      // Target slightly below budget for safety
      int targetSum = (remainingBudget * 0.95).round();
      double scaleFactor = targetSum / firstSixSum;

      values = values.map((v) {
        int scaled = (v * scaleFactor).round();
        // Ensure minimum of 5ms is maintained
        return scaled < minMs ? minMs : scaled;
      }).toList();
    }

    // Add the last step value
    values.add(lastStepValue);

    return values;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = widget.block;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppAppBar(
        title: l10n.blockDetailsTitle,
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header section with main info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.check,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.blockAtSlot(block.height, block.globalSlot),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.statsEpoch(block.epoch),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Timeline
            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockVrfSlotDiscovered,
              subtitle: l10n.blockSlotWon(block.globalSlot),
              timing: '${timings[0]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockProductionScheduled,
              subtitle: l10n.blockEpochSlot(block.epoch, block.globalSlot),
              timing: '${timings[1]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockTxBatchesIncluded,
              subtitle: block.batches.isNotEmpty
                  ? l10n.blockIncludedBatchesTx(block.batches.length, block.transactions.toInt())
                  : l10n.blockIncludedBatchesTxGeneric,
              timing: '${timings[2]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockStateTransition,
              subtitle: l10n.blockStatesUpdated,
              timing: '${timings[3]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockAppliedLocally,
              subtitle: l10n.blockUtxosUpdated,
              timing: '${timings[4]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: l10n.blockCommitted,
              subtitle: l10n.blockNumber(block.height),
              timing: '${timings[5]}ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.verified,
              title: l10n.blockConfirmed,
              subtitle: l10n.blockHashPrefix(
                block.hash.toString().length > 16
                    ? block.hash.toString().substring(0, 16)
                    : block.hash.toString()
              ),
              timing: '${timings[6]}ms',
              isLast: true,
            ),

            const SizedBox(height: 32),

            // Block Information Card
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
                    l10n.blockInformation,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: l10n.blockHash,
                    value: block.hash.toString().length > 24
                        ? '${block.hash.toString().substring(0, 24)}...'
                        : block.hash.toString(),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockHeight,
                    value: '${block.height}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockGlobalSlot,
                    value: '${block.globalSlot}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockEpoch,
                    value: '${block.epoch}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockProducer,
                    value: block.producerPubkey.length > 24
                        ? '${block.producerPubkey.substring(0, 24)}...'
                        : block.producerPubkey,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockTransactions,
                    value: '${block.transactions}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: l10n.blockBatches,
                    value: '${block.batches.length}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? timing;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timing,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: icon == Icons.verified
                        ? Colors.amber.withValues(alpha: 0.2)
                        : theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isLast ? Colors.amber[700] : theme.colorScheme.surface,
                    size: isLast ? 20 : 14,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (timing != null)
                        Text(
                          timing!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
