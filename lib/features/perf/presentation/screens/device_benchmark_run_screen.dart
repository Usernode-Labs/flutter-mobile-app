import 'dart:async';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/providers/perf_benchmark_provider.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DeviceBenchmarkRunScreen extends ConsumerWidget {
  const DeviceBenchmarkRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(perfBenchmarkProvider);
    final controller = ref.read(perfBenchmarkProvider.notifier);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final showResults = state.report != null;
    final showActiveRun = _hasCurrentRun(state);
    final showTerminalState =
        state.status != null && state.hasFinishedRun && state.report == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            showResults ? l10n.perfResultsTitle : l10n.perfCurrentRunTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(spacing.space16),
          children: [
            if (showActiveRun) ...[
              _RunStatusCard(
                state: state,
                l10n: l10n,
                onCancel: state.isRunning ? controller.cancelRun : null,
              ),
            ] else if (showResults) ...[
              _ResultSummaryCard(report: state.report!, l10n: l10n),
              SizedBox(height: spacing.space24),
              ..._buildSuiteSections(
                context,
                l10n,
                state.report!,
                state.catalog,
              ),
            ] else if (showTerminalState) ...[
              _RunStatusCard(state: state, l10n: l10n),
              SizedBox(height: spacing.space24),
              _ActionCard(
                title: l10n.perfNoRunAvailableTitle,
                description: l10n.perfNoRunAvailableDescription,
                buttonLabel: l10n.perfBackToBenchmarks,
                onTap: () => context.go(AppRoutes.deviceBenchmark),
              ),
            ] else ...[
              _ActionCard(
                title: l10n.perfNoRunAvailableTitle,
                description: l10n.perfNoRunAvailableDescription,
                buttonLabel: l10n.perfBackToBenchmarks,
                onTap: () => context.go(AppRoutes.deviceBenchmark),
              ),
            ],
            if (_shouldShowErrorCard(
                state, showResults, showTerminalState)) ...[
              SizedBox(height: spacing.space24),
              _ErrorCard(message: _errorMessage(l10n, state)!),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSuiteSections(
    BuildContext context,
    AppLocalizations l10n,
    perf_types.PerfRunReport report,
    perf_types.PerfCatalog? catalog,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final groups = <String, List<perf_types.PerfMeasurementRow>>{};

    for (final suite in const [
      'primitives',
      'partial_sync',
      'partial_block_production',
      'wallet_send',
    ]) {
      groups[suite] = <perf_types.PerfMeasurementRow>[];
    }

    for (final row in report.rows) {
      groups.putIfAbsent(row.suite, () => <perf_types.PerfMeasurementRow>[]);
      groups[row.suite]!.add(row);
    }

    final sections = <Widget>[];
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final measurementGroups = groupMeasurementsForSuite(
        entry.key,
        entry.value,
        catalog,
      );
      if (measurementGroups.isEmpty) {
        continue;
      }
      sections.add(
        _SuiteSectionCard(
          title: suiteLabel(l10n, entry.key),
          groups: measurementGroups,
          l10n: l10n,
        ),
      );
      sections.add(SizedBox(height: spacing.space16));
    }

    if (sections.isNotEmpty) {
      sections.removeLast();
    }
    return sections;
  }
}

class _RunStatusCard extends StatelessWidget {
  const _RunStatusCard({
    required this.state,
    required this.l10n,
    this.onCancel,
  });

  final PerfBenchmarkState state;
  final AppLocalizations l10n;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final status = state.status;
    final isStarting = state.isStartingRun && status == null;
    final isActive =
        isStarting || status?.state == perf_types.PerfRunState.running;
    final profile = status?.profile ?? state.requestedProfile;
    final progress = status == null || status.totalSteps == 0
        ? null
        : status.completedSteps / status.totalSteps;
    final elapsed = status == null ? null : elapsedDuration(status);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.perfCurrentRunTitle,
              style: theme.textTheme.titleMedium,
            ),
            if (profile != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                profileLabel(l10n, profile),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            SizedBox(height: spacing.space8),
            Text(
              isStarting
                  ? l10n.perfStateStarting
                  : runStateLabel(l10n, status!.state),
              style: theme.textTheme.bodyMedium,
            ),
            if (isActive) ...[
              SizedBox(height: spacing.space12),
              Text(
                l10n.perfRunPausedNodeNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: spacing.space16),
            LinearProgressIndicator(value: progress),
            SizedBox(height: spacing.space12),
            if (isStarting && profile != null)
              Text(
                l10n.perfPreparingProfile(profileLabel(l10n, profile)),
                style: theme.textTheme.bodyMedium,
              )
            else if (status != null)
              Text(
                l10n.perfProgressValue(
                  status.completedSteps,
                  status.totalSteps,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            if (status?.currentStepLabel != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                l10n.perfCurrentStep(status!.currentStepLabel!),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (elapsed != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                l10n.perfElapsed(formatDuration(elapsed)),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (status?.error != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                status!.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (onCancel != null) ...[
              SizedBox(height: spacing.space16),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l10n.commonCancel,
                  variant: ButtonVariant.outlined,
                  isLoading: state.isCancelling,
                  onTap: () {
                    unawaited(onCancel!());
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.report,
    required this.l10n,
  });

  final perf_types.PerfRunReport report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final device = report.device;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.perfResultsTitle,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: spacing.space12),
            _SummaryRow(
              label: l10n.perfResultProfile,
              value: profileLabel(l10n, report.profile),
            ),
            _SummaryRow(
              label: l10n.perfResultDevice,
              value: device.deviceModel,
            ),
            _SummaryRow(
              label: l10n.perfResultOperatingSystem,
              value: '${device.osName} ${device.osVersion}',
            ),
            _SummaryRow(
              label: l10n.perfResultCpu,
              value: device.cpuArch,
            ),
            _SummaryRow(
              label: l10n.perfResultLogicalCores,
              value: '${device.logicalCores}',
            ),
            _SummaryRow(
              label: l10n.perfResultMeasurements,
              value: '${report.rows.length}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(width: spacing.space16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuiteSectionCard extends StatelessWidget {
  const _SuiteSectionCard({
    required this.title,
    required this.groups,
    required this.l10n,
  });

  final String title;
  final List<PerfMeasurementGroupData> groups;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: spacing.space16),
            for (var i = 0; i < groups.length; i++) ...[
              _MeasurementGroupSection(group: groups[i], l10n: l10n),
              if (i < groups.length - 1) SizedBox(height: spacing.space24),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeasurementGroupSection extends StatelessWidget {
  const _MeasurementGroupSection({
    required this.group,
    required this.l10n,
  });

  final PerfMeasurementGroupData group;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final defaultOnly = group.rows.length == 1 &&
        primaryContextLabel(group.rows.single, l10n) ==
            l10n.perfScenarioDefault;

    if (defaultOnly) {
      return _SingleResultRow(
        title: humanizeSnakeCase(group.measurementId),
        description: group.description,
        row: group.rows.single,
        l10n: l10n,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          humanizeSnakeCase(group.measurementId),
          style: theme.textTheme.titleSmall,
        ),
        if (group.description case final description?) ...[
          SizedBox(height: spacing.space4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: spacing.space12),
        for (var i = 0; i < group.rows.length; i++) ...[
          _ScenarioRowTile(
            row: group.rows[i],
            l10n: l10n,
            description: group.description,
          ),
          if (i < group.rows.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SingleResultRow extends StatelessWidget {
  const _SingleResultRow({
    required this.title,
    required this.description,
    required this.row,
    required this.l10n,
  });

  final String title;
  final String? description;
  final perf_types.PerfMeasurementRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return InkWell(
      borderRadius: radii.borderRadiusSmall,
      onTap: () {
        context.push(
          AppRoutes.deviceBenchmarkResultDetail,
          extra: DeviceBenchmarkResultDetailArgs(
            row: row,
            description: description,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (description != null) ...[
                    SizedBox(height: spacing.space4),
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: spacing.space12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMicros(row.avgUs),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: kMonoFontFamily,
                  ),
                ),
                SizedBox(width: spacing.space4),
                Icon(
                  Icons.chevron_right,
                  size: sizing.iconSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRowTile extends StatelessWidget {
  const _ScenarioRowTile({
    required this.row,
    required this.l10n,
    this.description,
  });

  final perf_types.PerfMeasurementRow row;
  final AppLocalizations l10n;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final spacing = theme.extension<AppSpacing>()!;

    return InkWell(
      borderRadius: radii.borderRadiusSmall,
      onTap: () {
        context.push(
          AppRoutes.deviceBenchmarkResultDetail,
          extra: DeviceBenchmarkResultDetailArgs(
            row: row,
            description: description,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                primaryContextLabel(row, l10n),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            SizedBox(width: spacing.space12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMicros(row.avgUs),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: kMonoFontFamily,
                  ),
                ),
                SizedBox(width: spacing.space4),
                Icon(
                  Icons.chevron_right,
                  size: sizing.iconSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: spacing.space8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.space16),
            SizedBox(
              width: double.infinity,
              child: Button(
                label: buttonLabel,
                variant: ButtonVariant.primary,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

bool _hasCurrentRun(PerfBenchmarkState state) {
  return state.isStartingRun ||
      state.isRunning ||
      (state.activeRunId != null && !state.hasFinishedRun);
}

bool _shouldShowErrorCard(
  PerfBenchmarkState state,
  bool showResults,
  bool showTerminalState,
) {
  if (showResults || showTerminalState) {
    return false;
  }
  return state.errorMessage != null || state.uiError != null;
}

String? _errorMessage(
  AppLocalizations l10n,
  PerfBenchmarkState state,
) {
  switch (state.uiError) {
    case PerfBenchmarkUiError.cancelFailed:
      return l10n.perfCancelFailed;
    case PerfBenchmarkUiError.runUnavailable:
      return l10n.perfRunUnavailable;
    case null:
      return state.errorMessage;
  }
}
