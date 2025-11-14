import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

enum BlockCardVariant {
  compact, // Home Screen - minimal info
  standard, // Produced Blocks Screen - detailed
  detailed, // Node Status Screen - most detailed
}

class ProducedBlockCard extends StatelessWidget {
  final RpcStatusBlockInfo block;
  final BigInt rewardPerBlock;
  final bool isBestTip;
  final BlockCardVariant variant;

  // Optional overrides for pre-formatted data
  final String? customHash;
  final String? customProducer;

  const ProducedBlockCard({
    super.key,
    required this.block,
    required this.rewardPerBlock,
    this.isBestTip = false,
    this.variant = BlockCardVariant.standard,
    this.customHash,
    this.customProducer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get hash and producer
    String blockHash;
    try {
      blockHash = customHash ?? block.hash.toString();
    } catch (_) {
      blockHash = 'N/A';
    }

    String producerPubkey;
    try {
      producerPubkey = customProducer ?? block.producerPubkey;
    } catch (_) {
      producerPubkey = '';
    }

    return InkWell(
      onTap: () {
        context.push('/main/node/block-details', extra: block);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: variant == BlockCardVariant.detailed
            ? const EdgeInsets.only(bottom: 4)
            : EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBestTip && variant != BlockCardVariant.compact
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : (variant == BlockCardVariant.compact
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerLow),
          border: isBestTip && variant == BlockCardVariant.detailed
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Icon(
              Icons.auto_awesome_motion,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: _buildContent(
                  context, theme, colorScheme, blockHash, producerPubkey),
            ),

            // TKN amount
            Text(
              '+${_formatTokenAmount(rewardPerBlock)} TKN',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String blockHash,
    String producerPubkey,
  ) {
    switch (variant) {
      case BlockCardVariant.compact:
        return _buildCompactContent(theme, colorScheme);
      case BlockCardVariant.standard:
        return _buildStandardContent(theme, colorScheme, blockHash);
      case BlockCardVariant.detailed:
        return _buildDetailedContent(
            theme, colorScheme, blockHash, producerPubkey);
    }
  }

  Widget _buildCompactContent(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Block number and "Produced" text
        Text(
          '#${block.height} Produced',
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
              'Produced ${_formatTimeAgo(block.timestamp)} ago',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• ',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTimestamp(block.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardContent(
    ThemeData theme,
    ColorScheme colorScheme,
    String blockHash,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block number with best tip badge
        Row(
          children: [
            Text(
              'Block #${block.height}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isBestTip) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BEST TIP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 4),

        // Epoch and Slot
        Text(
          'Epoch ${block.epoch} • Slot ${block.globalSlot}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),

        // Timestamp
        Text(
          _formatTimestampDetailed(block.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),

        // Hash
        Text(
          'Hash: ${_shortenHash(blockHash)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedContent(
    ThemeData theme,
    ColorScheme colorScheme,
    String blockHash,
    String producerPubkey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block number with best tip badge
        Row(
          children: [
            Text(
              'Block #${block.height}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isBestTip) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BEST TIP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),

        // Slot and batches
        Text(
          'Slot #${block.globalSlot} • ${block.batches.length == 1 ? '1 batch' : '${block.batches.length} batches'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),

        // Hash
        Text(
          'Hash: ${_shortenHash(blockHash)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),

        // Producer if available
        if (producerPubkey.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Producer: ${_shortenHash(producerPubkey, head: 8, tail: 8)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  // Helper methods for formatting

  String _formatTokenAmount(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }

  String _formatTimeAgo(BigInt timestampMs) {
    try {
      final millis = timestampMs.toInt();
      final blockTime =
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      final now = DateTime.now();
      final diff = now.difference(blockTime);

      if (diff.inMinutes < 1) {
        return 'just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'}';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
      } else {
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
      }
    } catch (e) {
      return 'unknown';
    }
  }

  String _formatTimestamp(BigInt timestampMs) {
    try {
      final millis = timestampMs.toInt();
      final blockTime =
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      final hour = blockTime.hour.toString().padLeft(2, '0');
      final minute = blockTime.minute.toString().padLeft(2, '0');
      final second = blockTime.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    } catch (e) {
      return 'Invalid time';
    }
  }

  String _formatTimestampDetailed(BigInt timestampMs) {
    try {
      final millis = timestampMs.toInt();
      final blockTime =
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      final now = DateTime.now();
      final diff = now.difference(blockTime);

      // Calculate relative time
      String relativeTime;
      if (diff.inMinutes < 1) {
        relativeTime = 'just now';
      } else if (diff.inMinutes < 60) {
        relativeTime =
            '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
      } else if (diff.inHours < 24) {
        relativeTime =
            '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      } else if (diff.inDays < 7) {
        relativeTime = '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      } else {
        relativeTime =
            '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';
      }

      // Format absolute time
      final hour = blockTime.hour.toString().padLeft(2, '0');
      final minute = blockTime.minute.toString().padLeft(2, '0');
      final second = blockTime.second.toString().padLeft(2, '0');
      final absoluteTime = '$hour:$minute:$second';

      return '$relativeTime • $absoluteTime';
    } catch (e) {
      return 'Invalid time';
    }
  }

  String _shortenHash(String hash, {int head = 6, int tail = 6}) {
    if (hash == 'N/A' || hash.isEmpty) return hash;
    if (hash.length <= head + tail + 3) return hash;
    return '${hash.substring(0, head)}...${hash.substring(hash.length - tail)}';
  }
}
