import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:intl/intl.dart';

final _log =
    LoggingService.instance.withTag('usernode/SlotProductionStatsScreen');

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
      _log.debug('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh_sharp),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const FullPageLoadingState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.all(spacing.space16),
                children: [
                  // Overview Stats Card
                  _buildOverviewCard(theme, colorScheme, l10n, spacing),
                  SizedBox(height: spacing.space16),

                  // Success Rate Card
                  _buildSuccessRateCard(theme, colorScheme, l10n, spacing),
                  SizedBox(height: spacing.space16),

                  // Recent Records by Epoch
                  _buildRecentRecordsSection(theme, colorScheme, l10n, spacing),
                  SizedBox(height: spacing.space32),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme, ColorScheme colorScheme,
      AppLocalizations l10n, AppSpacing spacing) {
    if (_stats == null) {
      return const SizedBox.shrink();
    }

    final semantic = theme.extension<AppSemanticColors>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.analytics_sharp, color: colorScheme.primary),
                SizedBox(width: spacing.space12),
                Text(
                  l10n.statsOverall,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space24),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    l10n.statsWonSlots,
                    _stats!.totalWonSlots.toString(),
                    Symbols.star_sharp,
                    semantic.warning.color,
                    theme,
                    spacing,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    l10n.statsAttempted,
                    _stats!.totalAttempted.toString(),
                    Symbols.play_arrow_sharp,
                    semantic.technical.color,
                    theme,
                    spacing,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space16),
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    l10n.statsProduced,
                    _stats!.totalProduced.toString(),
                    Symbols.check_circle_sharp,
                    semantic.success.color,
                    theme,
                    spacing,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    l10n.statsFailed,
                    _stats!.totalFailed.toString(),
                    Symbols.error_sharp,
                    colorScheme.error,
                    theme,
                    spacing,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space16),
            const Divider(),
            SizedBox(height: spacing.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.statsLastUpdated,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  _formatDateTime(_stats!.lastUpdated, l10n),
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
    AppSpacing spacing,
  ) {
    final sizing = theme.extension<AppSizing>()!;
    return Column(
      children: [
        Icon(icon, color: color, size: sizing.iconXLarge),
        SizedBox(height: spacing.space8),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: spacing.space4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessRateCard(ThemeData theme, ColorScheme colorScheme,
      AppLocalizations l10n, AppSpacing spacing) {
    if (_stats == null || _stats!.totalAttempted == 0) {
      return const SizedBox.shrink();
    }

    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final successRate = _stats!.successRate;
    final color = successRate >= 90
        ? semantic.success.color
        : successRate >= 70
            ? semantic.warning.color
            : colorScheme.error;

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.statsSuccessRate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  successRate >= 90
                      ? Symbols.sentiment_very_satisfied_sharp
                      : successRate >= 70
                          ? Symbols.sentiment_satisfied_sharp
                          : Symbols.sentiment_dissatisfied_sharp,
                  color: color,
                  size: sizing.iconXLarge,
                ),
              ],
            ),
            SizedBox(height: spacing.space16),
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
            SizedBox(height: spacing.space8),
            LinearProgressIndicator(
              value: successRate / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: radii.borderRadiusXSmall,
            ),
            SizedBox(height: spacing.space12),
            Text(
              l10n.statsSuccessfulOf(
                  _stats!.totalProduced, _stats!.totalAttempted),
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

  Widget _buildRecentRecordsSection(ThemeData theme, ColorScheme colorScheme,
      AppLocalizations l10n, AppSpacing spacing) {
    if (_recentRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.space24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Symbols.inbox_sharp,
                  size: Theme.of(context)
                      .extension<AppSizing>()!
                      .iconDisplayLarge,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                SizedBox(height: spacing.space16),
                Text(
                  l10n.statsNoRecords,
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
          padding:
              EdgeInsets.only(left: spacing.space8, bottom: spacing.space12),
          child: Text(
            l10n.statsRecentRecords,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._recordsByEpoch.entries.map((entry) {
          return _buildEpochSection(
              entry.key, entry.value, theme, colorScheme, l10n, spacing);
        }),
      ],
    );
  }

  Widget _buildEpochSection(
    int epoch,
    List<SlotProductionRecord> records,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    AppSpacing spacing,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: spacing.space12),
      child: ExpansionTile(
        leading: Icon(Symbols.calendar_today_sharp, color: colorScheme.primary),
        title: Text(
          l10n.statsEpoch(epoch),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${records.length} slot${records.length != 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        children: records.map((record) {
          return _buildRecordTile(record, theme, colorScheme, l10n);
        }).toList(),
      ),
    );
  }

  Widget _buildRecordTile(
    SlotProductionRecord record,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final sizing = theme.extension<AppSizing>()!;
    final statusColor = _getStatusColor(record.status, colorScheme);
    final statusIcon = _getStatusIcon(record.status);
    final statusText = _getStatusText(record.status, l10n);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(statusIcon, color: statusColor, size: sizing.iconSmall),
      ),
      title: Text(l10n.statsSlot(record.slotNumber)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText),
          if (record.producedTime != null)
            Text(
              'Produced: ${_formatDateTime(record.producedTime!, l10n)}',
              style: theme.textTheme.bodySmall,
            ),
          if (record.failureReason != null)
            Text(
              'Reason: ${record.failureReason}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
        ],
      ),
      trailing: record.blockHeight != null
          ? Chip(
              label: Text(l10n.statsBlock(record.blockHeight!)),
              backgroundColor: colorScheme.tertiary.withValues(alpha: 0.2),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Color _getStatusColor(SlotProductionStatus status, ColorScheme colorScheme) {
    switch (status) {
      case SlotProductionStatus.won:
        return colorScheme.secondary;
      case SlotProductionStatus.attempting:
        return colorScheme.primary;
      case SlotProductionStatus.produced:
        return colorScheme.tertiary;
      case SlotProductionStatus.failed:
        return colorScheme.error;
    }
  }

  IconData _getStatusIcon(SlotProductionStatus status) {
    switch (status) {
      case SlotProductionStatus.won:
        return Symbols.star_sharp;
      case SlotProductionStatus.attempting:
        return Symbols.play_arrow_sharp;
      case SlotProductionStatus.produced:
        return Symbols.check_circle_sharp;
      case SlotProductionStatus.failed:
        return Symbols.error_sharp;
    }
  }

  String _getStatusText(SlotProductionStatus status, AppLocalizations l10n) {
    switch (status) {
      case SlotProductionStatus.won:
        return l10n.statsStatusWon;
      case SlotProductionStatus.attempting:
        return l10n.statsStatusAttempting;
      case SlotProductionStatus.produced:
        return l10n.statsStatusProduced;
      case SlotProductionStatus.failed:
        return l10n.statsStatusFailed;
    }
  }

  String _formatDateTime(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.timeJustNow;
    } else if (difference.inHours < 1) {
      return l10n.timeMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.timeHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.timeDaysAgo(difference.inDays);
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }
}
