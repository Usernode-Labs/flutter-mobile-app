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

class DeviceBenchmarkScreen extends ConsumerWidget {
  const DeviceBenchmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(perfBenchmarkProvider);
    final controller = ref.read(perfBenchmarkProvider.notifier);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final hasCurrentRun = _hasCurrentRun(state);
    final hasLatestResults = state.report != null && state.hasFinishedRun;
    final currentProfile = state.status?.profile ??
        state.requestedProfile ??
        state.report?.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.perfTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(spacing.space16),
          children: [
            _InfoCard(
              title: l10n.perfIntroTitle,
              description: l10n.perfIntroDescription,
              note: l10n.perfIntroNote,
            ),
            SizedBox(height: spacing.space24),
            if (hasCurrentRun)
              _ActionCard(
                title: l10n.perfRunInProgressTitle,
                description: currentProfile == null
                    ? l10n.perfRunInProgressDescriptionUnknown
                    : l10n.perfRunInProgressDescription(
                        profileLabel(l10n, currentProfile),
                      ),
                buttonLabel: l10n.perfOpenCurrentRun,
                onTap: () => context.push(AppRoutes.deviceBenchmarkRun),
              )
            else if (state.catalog != null &&
                state.catalog!.profiles.isNotEmpty)
              ..._buildProfileCards(
                context,
                l10n,
                state,
                catalog: state.catalog!,
                onRun: (profile) {
                  unawaited(controller.startRun(profile));
                  context.push(AppRoutes.deviceBenchmarkRun);
                },
              )
            else if (state.isLoadingCatalog)
              _LoadingCard(
                title: l10n.perfCatalogLoading,
              )
            else
              _ErrorCard(
                message:
                    _errorMessage(l10n, state) ?? l10n.perfCatalogLoadError,
                actionLabel: l10n.commonRetry,
                onTap: () => controller.loadCatalog(force: true),
              ),
            if (_shouldShowErrorCard(state, hasCurrentRun)) ...[
              SizedBox(height: spacing.space24),
              _ErrorCard(
                message: _errorMessage(l10n, state)!,
                actionLabel: state.catalog == null ? l10n.commonRetry : null,
                onTap: state.catalog == null
                    ? () => controller.loadCatalog(force: true)
                    : null,
              ),
            ],
            if (hasLatestResults && !hasCurrentRun) ...[
              SizedBox(height: spacing.space24),
              _ActionCard(
                title: l10n.perfLatestResultsTitle,
                description: currentProfile == null
                    ? l10n.perfLatestResultsDescriptionUnknown
                    : l10n.perfLatestResultsDescription(
                        profileLabel(l10n, currentProfile),
                      ),
                buttonLabel: l10n.perfViewLatestResults,
                onTap: () => context.push(AppRoutes.deviceBenchmarkRun),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProfileCards(
    BuildContext context,
    AppLocalizations l10n,
    PerfBenchmarkState state, {
    required perf_types.PerfCatalog catalog,
    required void Function(perf_types.PerfRunProfile profile) onRun,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final profiles = catalog.profiles
        .map(
          (profile) => _ProfileCardData(
            profile: profile.profile,
            title: profileLabel(l10n, profile.profile),
            description: profile.description,
            totalSteps: profile.totalSteps,
          ),
        )
        .toList(growable: false);
    return [
      for (var i = 0; i < profiles.length; i++) ...[
        _ProfileCard(
          title: profiles[i].title,
          description: profiles[i].description,
          stepCountLabel: l10n.perfStepCount(profiles[i].totalSteps),
          buttonLabel:
              l10n.perfRunProfile(profileLabel(l10n, profiles[i].profile)),
          isBusy: state.isStartingRun &&
              state.requestedProfile == profiles[i].profile,
          isEnabled: !state.isStartingRun && !state.isCancelling,
          onTap: () => onRun(profiles[i].profile),
        ),
        if (i < profiles.length - 1) SizedBox(height: spacing.space16),
      ],
    ];
  }
}

class _ProfileCardData {
  const _ProfileCardData({
    required this.profile,
    required this.title,
    required this.description,
    required this.totalSteps,
  });

  final perf_types.PerfRunProfile profile;
  final String title;
  final String description;
  final int totalSteps;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.description,
    required this.note,
  });

  final String title;
  final String description;
  final String note;

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
            SizedBox(height: spacing.space12),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.description,
    required this.stepCountLabel,
    required this.buttonLabel,
    required this.isBusy,
    required this.isEnabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final String stepCountLabel;
  final String buttonLabel;
  final bool isBusy;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colorScheme = theme.colorScheme;

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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.space12),
            Text(
              stepCountLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.space16),
            SizedBox(
              width: double.infinity,
              child: Button(
                label: buttonLabel,
                variant: ButtonVariant.primary,
                isLoading: isBusy,
                onTap: isEnabled ? onTap : null,
              ),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: spacing.space12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium,
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
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

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
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (actionLabel != null && onTap != null) ...[
              SizedBox(height: spacing.space16),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: actionLabel!,
                  variant: ButtonVariant.outlined,
                  onTap: onTap,
                ),
              ),
            ],
          ],
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
  bool hasCurrentRun,
) {
  if (hasCurrentRun || (state.catalog == null && !state.isLoadingCatalog)) {
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
