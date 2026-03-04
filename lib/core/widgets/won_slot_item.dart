import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

enum SlotStatus {
  pending,
  produced,
  missed,
  orphaned,
}

class WonSlotItem extends StatelessWidget {
  final RpcEpochWonSlot slot;
  final SlotStatus status;
  final bool isCompact;
  final int? currentSlot;

  const WonSlotItem({
    super.key,
    required this.slot,
    required this.status,
    this.isCompact = false,
    this.currentSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final spacing = theme.extension<AppSpacing>()!;

    // Format expected time
    final expectedTime = _formatExpectedTime(slot.expectedTimeMs);
    final timeRemaining = _calculateTimeRemaining(slot.expectedTimeMs);
    final isPast = timeRemaining.isNegative;

    // Determine colors based on status
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case SlotStatus.produced:
        statusColor = colorScheme.tertiary;
        statusBgColor = colorScheme.tertiary.withValues(alpha: 0.1);
        statusIcon = Symbols.check_circle_sharp;
        statusLabel = 'Produced';
        break;
      case SlotStatus.missed:
        statusColor = colorScheme.error;
        statusBgColor = colorScheme.error.withValues(alpha: 0.1);
        statusIcon = Symbols.cancel_sharp;
        statusLabel = 'Missed';
        break;
      case SlotStatus.orphaned:
        statusColor = semantic.warning.color;
        statusBgColor = semantic.warning.colorContainer;
        statusIcon = Symbols.warning_amber_sharp;
        statusLabel = 'Orphaned';
        break;
      case SlotStatus.pending:
        if (isPast) {
          statusColor = semantic.warning.color;
          statusBgColor = semantic.warning.colorContainer;
          statusIcon = Symbols.schedule_sharp;
          statusLabel = 'Pending';
        } else {
          statusColor = colorScheme.primary;
          statusBgColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
          statusIcon = Symbols.schedule_sharp;
          statusLabel = 'Upcoming';
        }
        break;
    }

    if (isCompact) {
      return _buildCompactView(
        theme,
        colorScheme,
        radii,
        sizing,
        spacing,
        expectedTime,
        timeRemaining,
        statusColor,
        statusBgColor,
        statusIcon,
        statusLabel,
      );
    }

    return _buildFullView(
      theme,
      colorScheme,
      radii,
      sizing,
      spacing,
      expectedTime,
      timeRemaining,
      isPast,
      statusColor,
      statusBgColor,
      statusIcon,
      statusLabel,
    );
  }

  Widget _buildCompactView(
    ThemeData theme,
    ColorScheme colorScheme,
    AppRadii radii,
    AppSizing sizing,
    AppSpacing spacing,
    String expectedTime,
    Duration timeRemaining,
    Color statusColor,
    Color statusBgColor,
    IconData statusIcon,
    String statusLabel,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: spacing.space8),
      padding: EdgeInsets.symmetric(
          horizontal: spacing.space12, vertical: spacing.space8),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: radii.borderRadiusSmall,
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: sizing.iconXSmall, color: statusColor),
          SizedBox(width: spacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slot #${slot.globalSlot}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  expectedTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: spacing.space8, vertical: spacing.space4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: radii.borderRadiusXSmall,
            ),
            child: Text(
              statusLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView(
    ThemeData theme,
    ColorScheme colorScheme,
    AppRadii radii,
    AppSizing sizing,
    AppSpacing spacing,
    String expectedTime,
    Duration timeRemaining,
    bool isPast,
    Color statusColor,
    Color statusBgColor,
    IconData statusIcon,
    String statusLabel,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: spacing.space12),
      padding: EdgeInsets.all(spacing.space16),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: radii.borderRadiusMedium,
        border:
            Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: sizing.iconRegular),
              SizedBox(width: spacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slot #${slot.globalSlot}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expectedTime,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: spacing.space12, vertical: spacing.space8),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: radii.borderRadiusSmall,
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Time remaining (only for pending/upcoming slots)
          if (status == SlotStatus.pending && !isPast) ...[
            SizedBox(height: spacing.space12),
            const Divider(height: 1),
            SizedBox(height: spacing.space12),
            Row(
              children: [
                Icon(Symbols.timer_sharp,
                    size: sizing.iconXSmall, color: colorScheme.primary),
                SizedBox(width: spacing.space8),
                Text(
                  _formatTimeRemaining(timeRemaining),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpectedTime(BigInt expectedTimeMs) {
    try {
      final millis = expectedTimeMs.toInt();
      final dt =
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      final now = DateTime.now();

      // If it's today, show time only
      if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final second = dt.second.toString().padLeft(2, '0');
        return 'Today at $hour:$minute:$second';
      }

      // If it's tomorrow
      final tomorrow = now.add(const Duration(days: 1));
      if (tomorrow.year == dt.year &&
          tomorrow.month == dt.month &&
          tomorrow.day == dt.day) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return 'Tomorrow at $hour:$minute';
      }

      // Otherwise show full date
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$month-$day $hour:$minute';
    } catch (e) {
      return 'Invalid time';
    }
  }

  Duration _calculateTimeRemaining(BigInt expectedTimeMs) {
    try {
      final millis = expectedTimeMs.toInt();
      final expectedTime =
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      final now = DateTime.now().toUtc();
      return expectedTime.difference(now);
    } catch (e) {
      return Duration.zero;
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return 'In progress';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 24) {
      final days = hours ~/ 24;
      return 'In $days day${days > 1 ? 's' : ''}';
    }

    if (hours > 0) {
      return 'In ${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return 'In ${minutes}m ${seconds}s';
    }

    return 'In ${seconds}s';
  }
}
