import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:flutter/material.dart';

class DeviceBenchmarkResultDetailScreen extends StatelessWidget {
  const DeviceBenchmarkResultDetailScreen({
    super.key,
    required this.args,
  });

  final DeviceBenchmarkResultDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final row = args.row;
    final metadataRows = _metadataRows(row, l10n);
    final notes = filteredNotes(row);

    return Scaffold(
      appBar: AppBar(
        title: Text(humanizeSnakeCase(row.measurementId)),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(spacing.space16),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      humanizeSnakeCase(row.measurementId),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (args.description case final description?) ...[
                      SizedBox(height: spacing.space8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: spacing.space16),
                    _SummaryRow(
                      label: l10n.perfDetailScenario,
                      value: primaryContextLabel(row, l10n),
                    ),
                    _SummaryRow(
                      label: l10n.perfDetailAverage,
                      value: formatMicros(row.avgUs),
                    ),
                    _SummaryRow(
                      label: l10n.perfDetailMinMax,
                      value:
                          '${formatMicros(row.minUs)} / ${formatMicros(row.maxUs)}',
                    ),
                    _SummaryRow(
                      label: l10n.perfDetailRuns,
                      value: '${row.runs}',
                    ),
                  ],
                ),
              ),
            ),
            if (metadataRows.isNotEmpty) ...[
              SizedBox(height: spacing.space24),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.perfDetailMetadataTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      SizedBox(height: spacing.space12),
                      for (final metadata in metadataRows)
                        _SummaryRow(
                          label: metadata.label,
                          value: metadata.value,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (row.flow.isNotEmpty || notes.isNotEmpty) ...[
              SizedBox(height: spacing.space24),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.perfDetailImplementationTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      SizedBox(height: spacing.space12),
                      if (row.flow.isNotEmpty)
                        _SummaryRow(
                          label: l10n.perfDetailFlow,
                          value: row.flow,
                        ),
                      if (notes.isNotEmpty) ...[
                        Text(
                          l10n.perfDetailNotesTitle,
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(height: spacing.space8),
                        for (final note in notes)
                          Padding(
                            padding: EdgeInsets.only(bottom: spacing.space8),
                            child: Text(
                              '- $note',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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

class _MetadataRow {
  const _MetadataRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

List<_MetadataRow> _metadataRows(
  perf_types.PerfMeasurementRow row,
  AppLocalizations l10n,
) {
  return [
    if (row.txCount != null)
      _MetadataRow(
        label: l10n.perfDetailTxCount,
        value: '${row.txCount}',
      ),
    if (row.batchLayout != null)
      _MetadataRow(
        label: l10n.perfDetailBatchLayout,
        value: humanizeSnakeCase(row.batchLayout!),
      ),
    if (row.transactionShape != null)
      _MetadataRow(
        label: l10n.perfDetailTransactionShape,
        value: formatTransactionShape(row.transactionShape!),
      ),
    if (row.touchedLeaves case final value? when value > BigInt.zero)
      _MetadataRow(
        label: l10n.perfDetailTouchedLeaves,
        value: value.toString(),
      ),
    if (row.proofNodes case final value? when value > 0)
      _MetadataRow(
        label: l10n.perfDetailProofNodes,
        value: '$value',
      ),
    if (row.proofSizeBytes case final value? when value > BigInt.zero)
      _MetadataRow(
        label: l10n.perfDetailProofSize,
        value: formatBytes(value),
      ),
  ];
}
