import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

enum SlotHeatmapStatus {
  produced,
  pending,
  missed,
}

class SlotHeatmapData {
  final RpcEpochWonSlot slot;
  final SlotHeatmapStatus status;

  const SlotHeatmapData({
    required this.slot,
    required this.status,
  });
}

class SlotHeatmap extends StatelessWidget {
  final List<SlotHeatmapData> slots;
  final int slotsPerRow;
  final double cellSize;
  final double cellSpacing;
  final VoidCallback? onSlotTap;

  const SlotHeatmap({
    super.key,
    required this.slots,
    this.slotsPerRow = 20,
    this.cellSize = 12,
    this.cellSpacing = 6,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate statistics
    final produced =
        slots.where((s) => s.status == SlotHeatmapStatus.produced).length;
    final pending =
        slots.where((s) => s.status == SlotHeatmapStatus.pending).length;
    final missed =
        slots.where((s) => s.status == SlotHeatmapStatus.missed).length;
    final total = slots.length;
    final successRate = total > 0 ? (produced / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary statistics

        // Heatmap grid
        _buildHeatmapGrid(context, colorScheme),

        const SizedBox(height: 16),

        // Legend
        _buildLegend(context, colorScheme, produced, pending, missed),
      ],
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid(BuildContext context, ColorScheme colorScheme) {
    // Split slots into rows
    final rows = <List<SlotHeatmapData>>[];
    for (var i = 0; i < slots.length; i += slotsPerRow) {
      final end =
          (i + slotsPerRow < slots.length) ? i + slotsPerRow : slots.length;
      rows.add(slots.sublist(i, end));
    }

    return Column(
      children:
          rows.map((row) => _buildRow(context, colorScheme, row)).toList(),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ColorScheme colorScheme,
    List<SlotHeatmapData> rowSlots,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: cellSpacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: rowSlots.map((slotData) {
          return Padding(
            padding: EdgeInsets.only(right: cellSpacing),
            child: _buildCell(context, colorScheme, slotData),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    ColorScheme colorScheme,
    SlotHeatmapData slotData,
  ) {
    final Color cellColor;
    final Color borderColor;

    switch (slotData.status) {
      case SlotHeatmapStatus.produced:
        cellColor = Colors.green.shade400;
        borderColor = Colors.green.shade700;
        break;
      case SlotHeatmapStatus.pending:
        cellColor = Colors.blue.shade400;
        borderColor = Colors.blue.shade700;
        break;
      case SlotHeatmapStatus.missed:
        cellColor = Colors.red.shade400;
        borderColor = Colors.red.shade700;
        break;
    }

    return GestureDetector(
      onTap: () => _showSlotDetails(context, slotData),
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    ColorScheme colorScheme,
    int produced,
    int pending,
    int missed,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                context,
                color: Colors.green.shade400,
                label: 'Produced',
                count: produced,
              ),
              _buildLegendItem(
                context,
                color: Colors.blue.shade400,
                label: 'Pending',
                count: pending,
              ),
              _buildLegendItem(
                context,
                color: Colors.red.shade400,
                label: 'Missed',
                count: missed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
    required int count,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: color.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showSlotDetails(BuildContext context, SlotHeatmapData slotData) {
    final theme = Theme.of(context);
    final slot = slotData.slot;

    // Format time
    final slotTime = DateTime.fromMillisecondsSinceEpoch(
      slot.expectedTimeMs.toInt(),
      isUtc: true,
    ).toLocal();

    final now = DateTime.now();
    final isToday = now.year == slotTime.year &&
        now.month == slotTime.month &&
        now.day == slotTime.day;

    final timeStr = isToday
        ? 'Today at ${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}'
        : '${slotTime.year}-${slotTime.month.toString().padLeft(2, '0')}-${slotTime.day.toString().padLeft(2, '0')} ${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}';

    final statusStr = slotData.status == SlotHeatmapStatus.produced
        ? 'Produced'
        : slotData.status == SlotHeatmapStatus.pending
            ? 'Pending'
            : 'Missed';

    final Color statusColor = slotData.status == SlotHeatmapStatus.produced
        ? Colors.green
        : slotData.status == SlotHeatmapStatus.pending
            ? Colors.blue
            : Colors.red;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Slot #${slot.globalSlot}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeStr,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Text(
                    statusStr.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
