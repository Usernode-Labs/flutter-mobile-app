import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';

// TODO use translation file to replace hard coded strings

class ProducedBlocksScreen extends ConsumerStatefulWidget {
  const ProducedBlocksScreen({super.key});

  @override
  ConsumerState<ProducedBlocksScreen> createState() =>
      _ProducedBlocksScreenState();
}

class _ProducedBlocksScreenState extends ConsumerState<ProducedBlocksScreen>
    with WidgetsBindingObserver {
  int? _viewedEpoch;

  Timer? _refreshTimer;
  bool _refreshingSummary = false;
  Timer? _nodeStatusRefreshTimer;
  bool _refreshingNodeStatus = false;
  bool _showSyncingLabel = true;
  bool _notificationsEnabled = true;
  bool _notificationsChecked = false;
  bool _batteryOptimizationDisabled = true;
  bool _batteryStatusChecked = false;

  void _startAutoRefreshTimer() {
    // Avoid creating multiple timers on repeated hot reloads.
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      // Avoid overlapping refreshes; if a refresh is in progress, skip.
      _refreshSummary();
    });
  }

  void _updateSyncingLabel({
    ProducedBlocksSummary? summary,
    NodeStatusState? status,
  }) {
    final effectiveSummary = summary ??
        ref.read(producedBlocksSummaryProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );
    final effectiveStatus = status ?? ref.read(nodeStatusProvider).value;

    final bool noEpochsWithData =
        effectiveSummary == null ? true : !effectiveSummary.hasEpochsWithData;

    final sync = effectiveStatus?.syncStatus;
    final bool isConnecting = sync?.isConnecting ?? true;
    final bool isSynced = sync?.isSynced ?? false;

    final bool shouldShow = noEpochsWithData && (isConnecting || !isSynced);

    if (mounted && shouldShow != _showSyncingLabel) {
      setState(() {
        _showSyncingLabel = shouldShow;
      });
    }
  }

  void _startNodeStatusRefreshTimer() {
    // Avoid creating multiple timers on repeated hot reloads.
    _nodeStatusRefreshTimer?.cancel();
    _nodeStatusRefreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _refreshingNodeStatus) return;
      _refreshingNodeStatus = true;
      try {
        await ref.read(nodeStatusProvider.notifier).refresh();
        _updateSyncingLabel(
          status: ref.read(nodeStatusProvider).value,
        );
      } finally {
        if (mounted) {
          _refreshingNodeStatus = false;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodically refresh the produced blocks summary so slot progress
    // and related metrics stay up to date while this screen is visible.
    _startAutoRefreshTimer();
    // Also periodically refresh node status so slot timing and progress
    // reflect the latest backend state.
    _startNodeStatusRefreshTimer();
    _checkNotificationStatus();
    _checkBatteryOptimizationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final status = await Permission.notification.status;
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = status.isGranted;
        _notificationsChecked = true;
      });
    } catch (_) {
      // If we can't determine status, default to treating notifications
      // as enabled so we don't show a misleading warning panel.
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = true;
        _notificationsChecked = true;
      });
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      await PlatformAlarmService.instance.initialize();
      final disabled =
          await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
      if (!mounted) return;
      setState(() {
        _batteryOptimizationDisabled = disabled;
        _batteryStatusChecked = true;
      });
    } catch (_) {
      // If status can't be determined, assume it's fine and avoid warning.
      if (!mounted) return;
      setState(() {
        _batteryOptimizationDisabled = true;
        _batteryStatusChecked = true;
      });
    }
  }

  Future<void> _showNotificationPermissionSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  l10n.permNotificationsBlockBackgroundTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.permNotificationsBlockBackgroundBody,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final status = await Permission.notification.request();
                      if (!mounted) return;
                      setState(() {
                        _notificationsEnabled = status.isGranted;
                        _notificationsChecked = true;
                      });
                      if (Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.permAllowNotifications),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBatteryOptimizationSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.permBatteryTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.permBatteryAndroidExplanation,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.onboardingBatteryStepAppUsage,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.onboardingBatteryStepAllowBackground,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.onboardingBatteryStepTapText,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '4.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.onboardingBatteryStepSelectUnrestricted,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '5.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.onboardingBatteryStepReturnToApp,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await PlatformAlarmService.instance
                          .openBatteryOptimizationSettings();
                      await _checkBatteryOptimizationStatus();
                      if (Navigator.of(sheetContext).canPop()) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.permOpenBatterySettings),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    // Force provider to recompute on hot reload
    ref.invalidate(producedBlocksSummaryProvider);
    // Ensure the periodic refresh is (re)started after hot reload.
    _startAutoRefreshTimer();
    _startNodeStatusRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nodeStatusRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check battery optimization status when returning from Settings
      _checkBatteryOptimizationStatus();
    }
  }

  Future<void> _refreshSummary() async {
    if (_refreshingSummary || !mounted) return;
    _refreshingSummary = true;
    try {
      final summary = await ref.refresh(producedBlocksSummaryProvider.future);
      _updateSyncingLabel(summary: summary);
    } finally {
      if (mounted) {
        _refreshingSummary = false;
      }
    }
  }

  double totalScoreLastN(summary, int n) {
    double score = 0.0;
    int total = 0;
    // TODO: need to decide how to handle the current epoch; should probably calculate the partial results
    for (var i = summary.currentEpoch;
        i > summary.currentEpoch - n && i >= 0;
        i--) {
      total += 1;
      if (i >= summary.epochScores.length) {
        continue;
      }
      final evaluatedPercent = summary.epochScores[i].evaluatedPercent;
      final producedOfEvaluatedPercent =
          summary.epochScores[i].producedOfEvaluatedPercent;
      //print('Epoch $i: Evaluated: $evaluatedPercent, Produced: $producedOfEvaluatedPercent');
      score += (evaluatedPercent * producedOfEvaluatedPercent).clamp(0.0, 1.0);
    }
    return score / total;
  }

  (double earned, double possible) totalTokensLastN(summary, int n) {
    final rewardsPerBlock = summary.rewardsPerBlock.toDouble();
    double earned = 0.0;
    double possible = 0.0;
    for (var i = summary.currentEpoch;
        i > summary.currentEpoch - n && i >= 0;
        i--) {
      final produced = summary.epochScores[i].produced ?? 0;
      final missed = summary.epochScores[i].missed ?? 0;
      earned += produced * rewardsPerBlock;
      possible += (produced + missed) * rewardsPerBlock;
    }
    return (earned, possible);
  }

  double? scoreEpochI(dynamic summary, int i) {
    // print('Epoch $i: Summary: $summary');
    if (summary == null) return 0.0;
    final scores = summary.epochScores;
    if (scores == null || i < 0 || i >= scores.length) return null;
    final s = scores[i];
    // print('Epoch $i: Evaluated: ${s.evaluatedPercent}, Produced: ${s.producedOfEvaluatedPercent}');
    final value = (s.evaluatedPercent * s.producedOfEvaluatedPercent);
    if (value.isNaN || value.isInfinite) {
      return null;
    } else {
      return value.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(producedBlocksSummaryProvider);
    final nodeStatus = ref.watch(nodeStatusProvider).value;
    final sync = nodeStatus?.syncStatus;
    final syncPercentage = sync?.progress ?? 0.0;
    final colorScheme = theme.colorScheme;
    final bool isSynced = sync?.isSynced ?? false;
    final bool isConnecting = sync == null || sync.isConnecting;
    final Color syncAccentColor = isConnecting
        ? colorScheme.outline
        : (isSynced ? colorScheme.tertiary : colorScheme.primary);
    final dataValue = summary.asData?.value;
    final currentEpoch = dataValue?.currentEpoch ?? 0;
    final maxEpochWithData = dataValue?.maxEpochWithData ?? currentEpoch;
    final viewedEpoch = (_viewedEpoch != null)
        ? _viewedEpoch!.clamp(0, maxEpochWithData)
        : currentEpoch;

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh node status first so slot progress is up to date,
        // then recompute the produced blocks summary.
        // await ref.read(nodeStatusProvider.notifier).refresh();
        // Ensure the summary recomputes with fresh node status.
        await _refreshSummary();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: _showSyncingLabel
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Performing Initial Sync',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 260,
                              child: AppProgressBar(
                                value: syncPercentage,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: syncAccentColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top KPI centered within the top area
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.producedBlocksSuccessRateLast10Epochs,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  summary.when(
                                    data: (value) => Text(
                                      '${(totalScoreLastN(value, 10) * 100).toStringAsFixed(1)}%',
                                      style: theme.textTheme.displaySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    loading: () => const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    ),
                                    error: (e, _) => Text(
                                      l10n.commonNoValuePlaceholder,
                                      style: theme.textTheme.displaySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Builder(
                                    builder: (_) {
                                      return Column(
                                        children: [
                                          summary.when(
                                            data: (value) {
                                              final (earned, possible) =
                                                  totalTokensLastN(value, 10);
                                              return IntrinsicWidth(
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                    minHeight: 48,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme
                                                        .secondaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      l10n.producedBlocksTokensEarnedSummary(
                                                        earned
                                                            .toStringAsFixed(0),
                                                        possible
                                                            .toStringAsFixed(0),
                                                      ),
                                                      style: theme.textTheme
                                                          .titleMedium,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            loading: () => const SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5),
                                            ),
                                            error: (e, _) => Text(
                                              '${l10n.commonNoValuePlaceholder} / ${l10n.commonNoValuePlaceholder}',
                                              style:
                                                  theme.textTheme.titleMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom group: epoch + block production, hugged to bottom
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_notificationsChecked &&
                                  !_notificationsEnabled) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceBright,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_off_outlined,
                                        color: theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Notifications Disabled',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Background block production impacted',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        onPressed:
                                            _showNotificationPermissionSheet,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('Enable'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ] else if (_batteryStatusChecked &&
                                  !_batteryOptimizationDisabled) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceBright,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Icon(
                                              Icons.battery_0_bar,
                                              color: theme.colorScheme.error,
                                              size: 24,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.surface,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(1.5),
                                                child: Icon(
                                                  Icons.settings,
                                                  color:
                                                      theme.colorScheme.error,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Battery optimization enabled',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Background block production impacted',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton(
                                        onPressed:
                                            _showBatteryOptimizationSheet,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('Enable'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Builder(builder: (context) {
                                final currEpochSlot =
                                    summary.asData?.value.currentEpochSlot;
                                final totalSlots =
                                    summary.asData?.value.slotsInEpoch;
                                final isCurrentViewed =
                                    viewedEpoch == currentEpoch;
                                final isFutureViewed =
                                    viewedEpoch > currentEpoch;

                                int curr;
                                double progressValue;
                                if (totalSlots == null || totalSlots <= 0) {
                                  curr = 0;
                                  progressValue = 0.0;
                                } else if (isCurrentViewed) {
                                  curr = currEpochSlot ?? 0;
                                  progressValue = curr / totalSlots;
                                } else if (isFutureViewed) {
                                  // Future epoch: no progress yet
                                  curr = 0;
                                  progressValue = 0.0;
                                } else {
                                  // Past epoch: treat as fully complete
                                  curr = totalSlots;
                                  progressValue = 1.0;
                                }

                                final leftLabel =
                                    l10n.producedBlocksEpochSlotProgress(
                                  curr,
                                  totalSlots ?? 0,
                                );
                                // Compute time left in epoch only for current epoch
                                final nodeStatus =
                                    ref.watch(nodeStatusProvider).value;
                                String rightLabel;
                                if (isCurrentViewed) {
                                  final slotMs =
                                      nodeStatus?.slotDurationMs ?? 0;
                                  final remainingSlots = (totalSlots != null
                                      ? (totalSlots - (currEpochSlot ?? 0))
                                      : 0);
                                  final clampedRemaining =
                                      remainingSlots < 0 ? 0 : remainingSlots;
                                  final timeLeft = slotMs > 0
                                      ? Duration(
                                          milliseconds:
                                              clampedRemaining * slotMs)
                                      : Duration.zero;
                                  final hours = timeLeft.inHours;
                                  final minutes =
                                      timeLeft.inMinutes.remainder(60);
                                  rightLabel = timeLeft == Duration.zero
                                      ? l10n.producedBlocksZeroMinutesLeft
                                      : (hours > 0
                                          ? l10n.producedBlocksHoursMinutesLeft(
                                              hours, minutes)
                                          : l10n.producedBlocksMinutesLeft(
                                              minutes));
                                } else {
                                  rightLabel = l10n.commonEmDash;
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceBright,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _EpochPanel(
                                        epochLabel:
                                            l10n.statsEpoch(viewedEpoch),
                                        progress: progressValue,
                                        progressLeftLabel: leftLabel,
                                        progressRightLabel: rightLabel,
                                        onPrev: viewedEpoch > 0
                                            ? () {
                                                setState(() {
                                                  _viewedEpoch =
                                                      viewedEpoch - 1;
                                                });
                                              }
                                            : null,
                                        onNext: viewedEpoch < maxEpochWithData
                                            ? () {
                                                setState(() {
                                                  _viewedEpoch =
                                                      viewedEpoch + 1;
                                                });
                                              }
                                            : null,
                                        maxEpoch: maxEpochWithData,
                                        selectedEpoch: viewedEpoch,
                                        onPickEpoch: (e) {
                                          setState(() {
                                            _viewedEpoch = e;
                                          });
                                        },
                                        summaryData: summary.asData?.value,
                                      ),
                                      const SizedBox(height: 30),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              l10n.producedBlocksEpochPerformance,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500),
                                            ),
                                          ),
                                          Builder(
                                            builder: (_) {
                                              final epochScore =
                                                  scoreEpochI(
                                                      summary.asData?.value,
                                                      viewedEpoch);
                                              final text = epochScore == null
                                                  ? '--'
                                                  : '${(epochScore * 100).toStringAsFixed(1)}%';
                                              return Text(
                                                text,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Builder(builder: (_) {
                                        final data = summary.asData?.value;
                                        final scores =
                                            data?.epochScores ?? const [];
                                        final idxCandidate = viewedEpoch;
                                        final idx = (scores.isNotEmpty &&
                                                idxCandidate < scores.length)
                                            ? idxCandidate
                                            : (scores.isNotEmpty
                                                ? scores.length - 1
                                                : -1);
                                        final score =
                                            idx >= 0 ? scores[idx] : null;
                                        final slotsInEpoch =
                                            data?.slotsInEpoch ?? 0;
                                        final evaluated =
                                            score?.calculated ?? 0;
                                        final evaluatedPct = slotsInEpoch > 0
                                            ? (evaluated / slotsInEpoch) * 100.0
                                            : 0.0;

                                        return _MetricTile(
                                          leading: const _IconBadge(
                                              icon: Icons.search_outlined),
                                          title:
                                              l10n.producedBlocksCheckedSlots,
                                          subtitle: l10n
                                              .producedBlocksEvaluatedOfSlots(
                                            evaluated,
                                            slotsInEpoch,
                                          ),
                                          trailingPrimary:
                                              '${evaluatedPct.toStringAsFixed(0)}%',
                                          onTap: () {
                                            final epoch = viewedEpoch;
                                            final epochScore = score;
                                            final epochData =
                                                epochScore?.epochData.slotData;
                                            final results = epochData == null
                                                ? <int>[]
                                                : epochData
                                                    .map((s) => s.result.index)
                                                    .toList();
                                            final slotTimesMs =
                                                epochData == null
                                                    ? <int?>[]
                                                    : epochData
                                                        .map((s) =>
                                                            s.slotTimeMs == null
                                                                ? null
                                                                : (s.slotTimeMs!
                                                                    .toInt()))
                                                        .toList();
                                            final producedMeta = epochData ==
                                                    null
                                                ? const <Map<String,
                                                    dynamic>?>[]
                                                : epochData
                                                    .map((s) =>
                                                        s.producedBlockMetadata ==
                                                                null
                                                            ? null
                                                            : <String, dynamic>{
                                                                'blockHash': s
                                                                    .producedBlockMetadata!
                                                                    .blockHash
                                                                    .toString(),
                                                                'canonical': s
                                                                    .producedBlockMetadata!
                                                                    .canonical,
                                                                'timestampMs': s
                                                                    .producedBlockMetadata!
                                                                    .timestampMs
                                                                    .toString(),
                                                                'tokensWon': s
                                                                    .producedBlockMetadata!
                                                                    .tokensWon
                                                                    .toString(),
                                                              })
                                                    .toList();
                                            context.push(
                                              AppRoutes.slotAssignments,
                                              extra: {
                                                'epoch': epoch,
                                                'slotsInEpoch': slotsInEpoch,
                                                'results': results,
                                                'slotTimesMs': slotTimesMs,
                                                'producedMeta': producedMeta,
                                                'filters': ['all'],
                                              },
                                            );
                                          },
                                          showChevron: true,
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      Builder(builder: (_) {
                                        final data = summary.asData?.value;
                                        final scores =
                                            data?.epochScores ?? const [];
                                        final idxCandidate = viewedEpoch;
                                        final idx = (scores.isNotEmpty &&
                                                idxCandidate < scores.length)
                                            ? idxCandidate
                                            : (scores.isNotEmpty
                                                ? scores.length - 1
                                                : -1);
                                        final score =
                                            idx >= 0 ? scores[idx] : null;
                                        final produced = score?.produced ?? 0;
                                        final won = score?.won ?? '?';
                                        return _MetricTile(
                                          leading: const _IconBadge(
                                              icon: Icons.check_box_outlined),
                                          title: l10n.producedBlocksTitle,
                                          subtitle:
                                              l10n.producedBlocksProducedOfWon(
                                            produced.toString(),
                                            won.toString(),
                                          ),
                                          trailingPrimary: '${produced}',
                                          onTap: produced > 0
                                              ? () {
                                                  final epoch = viewedEpoch;
                                                  final epochScore = score;
                                                  final slotsInEpoch =
                                                      data?.slotsInEpoch ?? 0;
                                                  final epochData = epochScore
                                                      ?.epochData.slotData;
                                                  final results = epochData ==
                                                          null
                                                      ? <int>[]
                                                      : epochData
                                                          .map((s) =>
                                                              s.result.index)
                                                          .toList();
                                                  final slotTimesMs = epochData ==
                                                          null
                                                      ? <int?>[]
                                                      : epochData
                                                          .map((s) =>
                                                              s.slotTimeMs ==
                                                                      null
                                                                  ? null
                                                                  : (s.slotTimeMs!
                                                                      .toInt()))
                                                          .toList();
                                                  final producedMeta = epochData ==
                                                          null
                                                      ? const <Map<String,
                                                          dynamic>?>[]
                                                      : epochData
                                                          .map((s) =>
                                                              s.producedBlockMetadata ==
                                                                      null
                                                                  ? null
                                                                  : <String,
                                                                      dynamic>{
                                                                      'blockHash': s
                                                                          .producedBlockMetadata!
                                                                          .blockHash
                                                                          .toString(),
                                                                      'canonical': s
                                                                          .producedBlockMetadata!
                                                                          .canonical,
                                                                      'timestampMs': s
                                                                          .producedBlockMetadata!
                                                                          .timestampMs
                                                                          .toString(),
                                                                      'tokensWon': s
                                                                          .producedBlockMetadata!
                                                                          .tokensWon
                                                                          .toString(),
                                                                    })
                                                          .toList();
                                                  context.push(
                                                    AppRoutes.slotAssignments,
                                                    extra: {
                                                      'epoch': epoch,
                                                      'slotsInEpoch':
                                                          slotsInEpoch,
                                                      'results': results,
                                                      'slotTimesMs':
                                                          slotTimesMs,
                                                      'producedMeta':
                                                          producedMeta,
                                                      'filters': ['produced'],
                                                    },
                                                  );
                                                }
                                              : null,
                                          showChevron: produced > 0,
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      Builder(builder: (_) {
                                        final data = summary.asData?.value;
                                        final scores =
                                            data?.epochScores ?? const [];
                                        final idxCandidate = viewedEpoch;
                                        final idx = (scores.isNotEmpty &&
                                                idxCandidate < scores.length)
                                            ? idxCandidate
                                            : (scores.isNotEmpty
                                                ? scores.length - 1
                                                : -1);
                                        final score =
                                            idx >= 0 ? scores[idx] : null;
                                        final missed = score?.missed ?? 0;
                                        final won = score?.won ?? '?';
                                        return _MetricTile(
                                          leading: const _IconBadge(
                                              icon: Icons
                                                  .disabled_by_default_outlined),
                                          title: l10n
                                              .producedBlocksMissedBlocksTitle,
                                          subtitle:
                                              l10n.producedBlocksMissedOfWon(
                                            missed.toString(),
                                            won.toString(),
                                          ),
                                          trailingPrimary: '$missed',
                                          onTap: missed > 0
                                              ? () {
                                                  final epoch = viewedEpoch;
                                                  final epochScore = score;
                                                  final slotsInEpoch =
                                                      data?.slotsInEpoch ?? 0;
                                                  final epochData = epochScore
                                                      ?.epochData.slotData;
                                                  final results = epochData ==
                                                          null
                                                      ? <int>[]
                                                      : epochData
                                                          .map((s) =>
                                                              s.result.index)
                                                          .toList();
                                                  final slotTimesMs = epochData ==
                                                          null
                                                      ? <int?>[]
                                                      : epochData
                                                          .map((s) =>
                                                              s.slotTimeMs ==
                                                                      null
                                                                  ? null
                                                                  : (s.slotTimeMs!
                                                                      .toInt()))
                                                          .toList();
                                                  context.push(
                                                    AppRoutes.slotAssignments,
                                                    extra: {
                                                      'epoch': epoch,
                                                      'slotsInEpoch':
                                                          slotsInEpoch,
                                                      'results': results,
                                                      'slotTimesMs':
                                                          slotTimesMs,
                                                      'producedMeta':
                                                          const <Map<String,
                                                              dynamic>?>[],
                                                      'filters': ['missed'],
                                                    },
                                                  );
                                                }
                                              : null,
                                          showChevron: missed > 0,
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      (viewedEpoch >= currentEpoch &&
                                              viewedEpoch <= maxEpochWithData)
                                          ? Builder(builder: (_) {
                                              final data =
                                                  summary.asData?.value;
                                              final scores =
                                                  data?.epochScores ?? const [];
                                              final idxCandidate = viewedEpoch;
                                              final idx = (scores.isNotEmpty &&
                                                      idxCandidate <
                                                          scores.length)
                                                  ? idxCandidate
                                                  : (scores.isNotEmpty
                                                      ? scores.length - 1
                                                      : -1);
                                              final score =
                                                  idx >= 0 ? scores[idx] : null;
                                              final upcoming =
                                                  score?.upcoming ?? 0;
                                              return _MetricTile(
                                                leading: const _IconBadge(
                                                    icon: Icons
                                                        .schedule_outlined),
                                                title: l10n
                                                    .producedBlocksUpcomingBlocksTitle,
                                                subtitle: l10n
                                                    .producedBlocksUpcomingThisEpoch(
                                                  upcoming.toString(),
                                                ),
                                                trailingPrimary: '$upcoming',
                                                onTap: upcoming > 0
                                                    ? () {
                                                        final epoch =
                                                            viewedEpoch;
                                                        final epochScore =
                                                            score;
                                                        final slotsInEpoch =
                                                            data?.slotsInEpoch ??
                                                                0;
                                                        final epochData =
                                                            epochScore
                                                                ?.epochData
                                                                .slotData;
                                                        final results =
                                                            epochData == null
                                                                ? <int>[]
                                                                : epochData
                                                                    .map((s) => s
                                                                        .result
                                                                        .index)
                                                                    .toList();
                                                        final slotTimesMs = epochData ==
                                                                null
                                                            ? <int?>[]
                                                            : epochData
                                                                .map((s) => s
                                                                            .slotTimeMs ==
                                                                        null
                                                                    ? null
                                                                    : (s.slotTimeMs!
                                                                        .toInt()))
                                                                .toList();
                                                        context.push(
                                                          AppRoutes
                                                              .slotAssignments,
                                                          extra: {
                                                            'epoch': epoch,
                                                            'slotsInEpoch':
                                                                slotsInEpoch,
                                                            'results': results,
                                                            'slotTimesMs':
                                                                slotTimesMs,
                                                            'producedMeta':
                                                                const <Map<
                                                                    String,
                                                                    dynamic>?>[],
                                                            'filters': [
                                                              'upcoming'
                                                            ],
                                                          },
                                                        );
                                                      }
                                                    : null,
                                                showChevron: upcoming > 0,
                                              );
                                            })
                                          : const SizedBox.shrink(),
                                    ],
                                  ),
                                );
                              }),
                              (viewedEpoch >= currentEpoch &&
                                      viewedEpoch <= maxEpochWithData)
                                  ? const SizedBox.shrink()
                                  : const SizedBox(height: 64),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpochPanel extends StatelessWidget {
  const _EpochPanel({
    required this.epochLabel,
    required this.progress,
    required this.progressLeftLabel,
    required this.progressRightLabel,
    this.onPrev,
    this.onNext,
    required this.maxEpoch,
    required this.selectedEpoch,
    required this.onPickEpoch,
    this.summaryData,
  });

  final String epochLabel;
  final double progress;
  final String progressLeftLabel;
  final String progressRightLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final int maxEpoch;
  final int selectedEpoch;
  final ValueChanged<int> onPickEpoch;
  final dynamic summaryData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Keep light-mode behavior; improve dark-mode colors
    final trackColor =
        isDark ? colorScheme.surfaceVariant : Colors.grey.shade300;
    final activeColor = isDark ? colorScheme.primary : Colors.black87;

    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) {
                      final height = MediaQuery.of(ctx).size.height * 0.6;
                      return SizedBox(
                        height: height,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.producedBlocksSelectEpoch,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.builder(
                                itemCount: maxEpoch + 1,
                                itemBuilder: (_, index) {
                                  // index 0 corresponds to maxEpoch (highest at top)
                                  final epoch = maxEpoch - index;
                                  final selected = epoch == selectedEpoch;

                                  // Calculate epoch performance
                                  double performance = 0.0;
                                  if (summaryData != null) {
                                    final scores = summaryData.epochScores;
                                    if (scores != null &&
                                        epoch >= 0 &&
                                        epoch < scores.length) {
                                      final s = scores[epoch];
                                      final value = (s.evaluatedPercent *
                                          s.producedOfEvaluatedPercent);
                                      if (!value.isNaN && !value.isInfinite) {
                                        performance = value.clamp(0.0, 1.0);
                                      }
                                    }
                                  }
                                  final performanceStr =
                                      '${(performance * 100).toStringAsFixed(0)}%';

                                  return ListTile(
                                    title: Text(
                                        '${l10n.statsEpoch(epoch)} · $performanceStr'),
                                    trailing: selected
                                        ? const Icon(Icons.check,
                                            color: Colors.black87)
                                        : null,
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      onPickEpoch(epoch);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    Text(
                      epochLabel,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
            // Prev / Next circle buttons
            IconButton.filledTonal(
              onPressed: onPrev,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onNext,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        AppProgressBar(
          value: progress,
          backgroundColor: trackColor,
          valueColor: activeColor,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                progressLeftLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            Text(
              progressRightLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailingPrimary,
    this.onTap,
    this.showChevron = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String trailingPrimary;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingPrimary,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, color: theme.colorScheme.onSurface),
      ),
    );
  }
}
