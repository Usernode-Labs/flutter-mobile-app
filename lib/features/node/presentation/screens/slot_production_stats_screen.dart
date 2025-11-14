import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/slot_production_repository.dart';
import 'package:intl/intl.dart';

class SlotProductionStatsScreen extends ConsumerStatefulWidget {
  const SlotProductionStatsScreen({super.key});

  @override
  ConsumerState<SlotProductionStatsScreen> createState() =>
      _SlotProductionStatsScreenState();
}

class _SlotProductionStatsScreenState
    extends ConsumerState<SlotProductionStatsScreen> {
  bool _isLoading = true;
  SlotProductionStats? _stats;
  List<SlotProductionRecord> _recentRecords = [];
  Map<int, List<SlotProductionRecord>> _recordsByEpoch = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await SlotProductionRepository.instance.initialize();

      final stats = SlotProductionRepository.instance.getStats();
      final recentRecords =
          SlotProductionRepository.instance.getRecentRecords(limit: 20);

      // Group records by epoch
      final recordsByEpoch = <int, List<SlotProductionRecord>>{};
      for (final record in recentRecords) {
        if (!recordsByEpoch.containsKey(record.epoch)) {
          recordsByEpoch[record.epoch] = [];
        }
        recordsByEpoch[record.epoch]!.add(record);
      }

      setState(() {
        _stats = stats;
        _recentRecords = recentRecords;
        _recordsByEpoch = recordsByEpoch;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Statistics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overview Stats Card
                  _buildOverviewCard(theme, colorScheme),
                  const SizedBox(height: 16),

                  // Success Rate Card
                  _buildSuccessRateCard(theme, colorScheme),
                  const SizedBox(height: 16),

                  // Recent Records by Epoch
                  _buildRecentRecordsSection(theme, colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme, ColorScheme colorScheme) {
    if (_stats == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Overall Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    'Won Slots',
                    _stats!.totalWonSlots.toString(),
                    Icons.star,
                    Colors.amber,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    'Attempted',
                    _stats!.totalAttempted.toString(),
                    Icons.play_arrow,
                    Colors.blue,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    'Produced',
                    _stats!.totalProduced.toString(),
                    Icons.check_circle,
                    Colors.green,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    'Failed',
                    _stats!.totalFailed.toString(),
                    Icons.error,
                    Colors.red,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Updated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  _formatDateTime(_stats!.lastUpdated),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessRateCard(ThemeData theme, ColorScheme colorScheme) {
    if (_stats == null || _stats!.totalAttempted == 0) {
      return const SizedBox.shrink();
    }

    final successRate = _stats!.successRate;
    final color = successRate >= 90
        ? Colors.green
        : successRate >= 70
            ? Colors.orange
            : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Success Rate',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  successRate >= 90
                      ? Icons.sentiment_very_satisfied
                      : successRate >= 70
                          ? Icons.sentiment_satisfied
                          : Icons.sentiment_dissatisfied,
                  color: color,
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  '${successRate.toStringAsFixed(1)}%',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: successRate / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              '${_stats!.totalProduced} successful out of ${_stats!.totalAttempted} attempts',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRecordsSection(ThemeData theme, ColorScheme colorScheme) {
    if (_recentRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No production records yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Recent Production Records',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._recordsByEpoch.entries.map((entry) {
          return _buildEpochSection(entry.key, entry.value, theme, colorScheme);
        }),
      ],
    );
  }

  Widget _buildEpochSection(
    int epoch,
    List<SlotProductionRecord> records,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(Icons.calendar_today, color: colorScheme.primary),
        title: Text(
          'Epoch $epoch',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${records.length} slot${records.length != 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        children: records.map((record) {
          return _buildRecordTile(record, theme, colorScheme);
        }).toList(),
      ),
    );
  }

  Widget _buildRecordTile(
    SlotProductionRecord record,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final statusColor = _getStatusColor(record.status);
    final statusIcon = _getStatusIcon(record.status);
    final statusText = _getStatusText(record.status);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Text('Slot ${record.slotNumber}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText),
          if (record.producedTime != null)
            Text(
              'Produced: ${_formatDateTime(record.producedTime!)}',
              style: theme.textTheme.bodySmall,
            ),
          if (record.failureReason != null)
            Text(
              'Reason: ${record.failureReason}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
              ),
            ),
        ],
      ),
      trailing: record.blockHeight != null
          ? Chip(
              label: Text('Block ${record.blockHeight}'),
              backgroundColor: Colors.green.withValues(alpha: 0.2),
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Color _getStatusColor(SlotProductionStatus status) {
    switch (status) {
      case SlotProductionStatus.won:
        return Colors.amber;
      case SlotProductionStatus.attempting:
        return Colors.blue;
      case SlotProductionStatus.produced:
        return Colors.green;
      case SlotProductionStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SlotProductionStatus status) {
    switch (status) {
      case SlotProductionStatus.won:
        return Icons.star;
      case SlotProductionStatus.attempting:
        return Icons.play_arrow;
      case SlotProductionStatus.produced:
        return Icons.check_circle;
      case SlotProductionStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(SlotProductionStatus status) {
    switch (status) {
      case SlotProductionStatus.won:
        return 'Won (not yet attempted)';
      case SlotProductionStatus.attempting:
        return 'Currently attempting production';
      case SlotProductionStatus.produced:
        return 'Successfully produced';
      case SlotProductionStatus.failed:
        return 'Production failed';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }
}
