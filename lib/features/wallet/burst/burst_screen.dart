import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/wallet/burst/burst_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet_tx.dart';

class BurstScreen extends ConsumerStatefulWidget {
  const BurstScreen({super.key});

  @override
  ConsumerState<BurstScreen> createState() => _BurstScreenState();
}

class _BurstScreenState extends ConsumerState<BurstScreen> {
  @override
  void initState() {
    super.initState();
    // Reset any stale state and kick off the burst immediately.
    Future.microtask(() {
      ref.invalidate(burstProvider);
      ref.read(burstProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(burstProvider);

    return PopScope(
      canPop: state is! BurstRunning,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.burstTitle)),
        body: switch (state) {
          BurstIdle() => const Center(child: CircularProgressIndicator()),
          BurstRunning() =>
            _RunningBody(state: state, spacing: spacing, l10n: l10n),
          BurstComplete() => _CompleteBody(state: state, l10n: l10n),
        },
      ),
    );
  }
}

class _RunningBody extends ConsumerStatefulWidget {
  const _RunningBody({
    required this.state,
    required this.spacing,
    required this.l10n,
  });

  final BurstRunning state;
  final AppSpacing spacing;
  final AppLocalizations l10n;

  @override
  ConsumerState<_RunningBody> createState() => _RunningBodyState();
}

class _RunningBodyState extends ConsumerState<_RunningBody> {
  final List<BurstRingOutcome> _ringOutcomes = [];
  int _lastCompleted = 0;
  int _lastFailed = 0;

  @override
  void initState() {
    super.initState();
    _syncRings(widget.state);
  }

  @override
  void didUpdateWidget(_RunningBody old) {
    super.didUpdateWidget(old);
    _syncRings(widget.state);
  }

  void _syncRings(BurstRunning state) {
    final newSucceeded = state.succeeded - (_lastCompleted - _lastFailed);
    final newFailed = state.failed - _lastFailed;

    // Append new outcomes.
    for (var i = 0; i < newFailed; i++) {
      _ringOutcomes.add(BurstRingOutcome.failed);
    }
    for (var i = 0; i < newSucceeded; i++) {
      _ringOutcomes.add(BurstRingOutcome.succeeded);
    }

    _lastCompleted = state.completed;
    _lastFailed = state.failed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = widget.spacing;
    final l10n = widget.l10n;
    final state = widget.state;
    final elapsed = state.stopwatch.elapsed;
    final elapsedText = '${elapsed.inSeconds}s';
    final latestProof = state.proofStats.isEmpty ? null : state.proofStats.last;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.space24),
      child: Column(
        children: [
          Expanded(
            child: BurstPulseIllustration(
              rings: _ringOutcomes,
              active: true,
            ),
          ),
          SizedBox(height: spacing.space16),
          Text(
            l10n.burstProgress(state.completed, state.total),
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: spacing.space8),
          Text(
            l10n.burstElapsed(elapsedText),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (latestProof != null) ...[
            SizedBox(height: spacing.space8),
            Text(
              '${l10n.burstLastProofTimeLabel}: ${latestProof.durationMs} ms',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.space4),
            Text(
              '${l10n.burstLastDefragInputsLabel}: ${latestProof.extraInputCount}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (state.failed > 0) ...[
            SizedBox(height: spacing.space8),
            Text(
              l10n.burstFailedCount(state.failed),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: spacing.space32),
          Button(
            variant: ButtonVariant.tonal,
            label: l10n.burstCancel,
            onTap: () => ref.read(burstProvider.notifier).cancel(),
          ),
          SizedBox(height: spacing.space24),
        ],
      ),
    );
  }
}

class _CompleteBody extends StatelessWidget {
  const _CompleteBody({required this.state, required this.l10n});

  final BurstComplete state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ResultPageVariant variant;
    final String title;
    String? subtitle;

    final elapsedText = '${state.elapsed.inSeconds}s';

    if (state.succeeded == state.total && state.total > 0) {
      variant = ResultPageVariant.success;
      title = l10n.burstSuccessTitle;
      subtitle = l10n.burstSuccessSubtitle(state.succeeded, elapsedText);
    } else if (state.succeeded == 0) {
      variant = ResultPageVariant.failure;
      title = l10n.burstFailureTitle;
      subtitle = state.errors.isNotEmpty ? state.errors.first : null;
    } else {
      variant = ResultPageVariant.info;
      title = l10n.burstMixedTitle;
      subtitle =
          l10n.burstMixedSubtitle(state.succeeded, state.failed, elapsedText);
    }

    final proofSummary = _buildProofSummary(
      l10n: l10n,
      proofStats: state.proofStats,
    );
    if (proofSummary != null) {
      subtitle = subtitle == null ? proofSummary : '$subtitle\n\n$proofSummary';
    }

    return ResultPage(
      variant: variant,
      title: title,
      subtitle: subtitle,
      primaryAction: Button(
        variant: ButtonVariant.primary,
        label: l10n.burstDone,
        onTap: () => context.pop(),
      ),
    );
  }
}

String? _buildProofSummary({
  required AppLocalizations l10n,
  required List<RpcWalletTxProofStats> proofStats,
}) {
  if (proofStats.isEmpty) {
    return null;
  }

  final totalDurationMs = proofStats.fold<BigInt>(
    BigInt.zero,
    (sum, stats) => sum + stats.durationMs,
  );
  final totalDefragInputs = proofStats.fold<BigInt>(
    BigInt.zero,
    (sum, stats) => sum + stats.extraInputCount,
  );
  final avgDurationMs =
      (totalDurationMs.toDouble() / proofStats.length).round();
  final maxDurationMs = proofStats
      .map((stats) => stats.durationMs)
      .reduce((a, b) => a > b ? a : b);
  final avgDefragInputs = totalDefragInputs.toDouble() / proofStats.length;
  final maxDefragInputs = proofStats
      .map((stats) => stats.extraInputCount)
      .reduce((a, b) => a > b ? a : b);

  final avgDefragText = avgDefragInputs == avgDefragInputs.roundToDouble()
      ? avgDefragInputs.toStringAsFixed(0)
      : avgDefragInputs.toStringAsFixed(1);

  return [
    '${l10n.burstProofTimeSummaryLabel}: $avgDurationMs / $maxDurationMs ms',
    '${l10n.burstDefragInputsSummaryLabel}: $avgDefragText / $maxDefragInputs',
  ].join('\n');
}
