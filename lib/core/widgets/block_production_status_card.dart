import 'package:flutter/material.dart';

class BlockProductionStatusCard extends StatelessWidget {
  final int blockNumber;
  final String timeAgo;
  final String timestamp;
  final int tknAmount;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? blockIconColor;
  final Color? tknColor;

  const BlockProductionStatusCard({
    super.key,
    required this.blockNumber,
    required this.timeAgo,
    required this.timestamp,
    required this.tknAmount,
    this.backgroundColor,
    this.borderColor,
    this.blockIconColor,
    this.tknColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        border: Border.all(
          color:
              borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Block icon
          Icon(
            Icons.auto_awesome_motion,
            size: 16,
            color: blockIconColor ?? colorScheme.tertiary,
          ),
          const SizedBox(width: 12),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Block number and "Produced" text
                Text(
                  '#$blockNumber Produced',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // Time ago and timestamp
                Row(
                  children: [
                    Text(
                      'Produced $timeAgo ago',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ',
                      style: TextStyle(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TKN amount
          Text(
            '+$tknAmount TKN',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: tknColor ?? colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
