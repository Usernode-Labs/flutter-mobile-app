import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;

class PerfMeasurementGroupData {
  const PerfMeasurementGroupData({
    required this.measurementId,
    required this.rows,
    this.description,
  });

  final String measurementId;
  final String? description;
  final List<perf_types.PerfMeasurementRow> rows;
}

class DeviceBenchmarkResultDetailArgs {
  const DeviceBenchmarkResultDetailArgs({
    required this.row,
    this.description,
  });

  final perf_types.PerfMeasurementRow row;
  final String? description;
}

String profileLabel(
  AppLocalizations l10n,
  perf_types.PerfRunProfile profile,
) {
  switch (profile) {
    case perf_types.PerfRunProfile.quick:
      return l10n.perfProfileQuick;
    case perf_types.PerfRunProfile.standard:
      return l10n.perfProfileStandard;
  }
}

String suiteLabel(AppLocalizations l10n, String suite) {
  switch (suite) {
    case 'primitives':
      return l10n.perfSuitePrimitives;
    case 'partial_sync':
      return l10n.perfSuitePartialSync;
    case 'partial_block_production':
      return l10n.perfSuitePartialBlockProduction;
    case 'wallet_send':
      return l10n.perfSuiteWalletSend;
    default:
      return humanizeSnakeCase(suite);
  }
}

String runStateLabel(
  AppLocalizations l10n,
  perf_types.PerfRunState state,
) {
  switch (state) {
    case perf_types.PerfRunState.running:
      return l10n.perfStateRunning;
    case perf_types.PerfRunState.completed:
      return l10n.perfStateCompleted;
    case perf_types.PerfRunState.failed:
      return l10n.perfStateFailed;
    case perf_types.PerfRunState.cancelled:
      return l10n.perfStateCancelled;
  }
}

Duration elapsedDuration(perf_types.PerfRunStatus status) {
  final finishedAtMs =
      status.finishedAtMs?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
  final startedAtMs = status.startedAtMs.toInt();
  return Duration(milliseconds: finishedAtMs - startedAtMs);
}

String formatDuration(Duration duration) {
  if (duration.inMinutes >= 1) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  if (duration.inSeconds >= 1) {
    return '${duration.inSeconds}s';
  }
  return '${duration.inMilliseconds}ms';
}

String formatMicros(BigInt microseconds) {
  final value = microseconds.toInt();
  if (value >= 1000) {
    final ms = value / 1000;
    return '${ms.toStringAsFixed(ms >= 10 ? 0 : 1)} ms';
  }
  return '$value us';
}

String formatBytes(BigInt bytes) {
  final value = bytes.toInt();
  const kib = 1024;
  const mib = kib * 1024;

  if (value >= mib) {
    final mb = value / mib;
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
  if (value >= kib) {
    final kb = value / kib;
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }
  return '$value B';
}

String humanizeSnakeCase(String value) {
  final words = value.split('_').where((word) => word.isNotEmpty);
  return words
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String formatTransactionShape(String value) {
  return value.replaceAll('_to_', ' -> ');
}

String primaryContextLabel(
  perf_types.PerfMeasurementRow row,
  AppLocalizations l10n,
) {
  final labels = <String>[
    if (row.txCount != null) l10n.perfContextTxCount(row.txCount!),
    if (row.batchLayout != null)
      l10n.perfContextBatchLayout(humanizeSnakeCase(row.batchLayout!)),
    if (row.transactionShape != null)
      l10n.perfContextTransactionShape(
        formatTransactionShape(row.transactionShape!),
      ),
  ];

  if (labels.isEmpty) {
    return l10n.perfScenarioDefault;
  }
  return labels.join(' · ');
}

List<String> filteredNotes(perf_types.PerfMeasurementRow row) {
  final hiddenNotes = <String>{
    if (row.flow.isNotEmpty) 'flow=${row.flow}',
    if (row.transactionShape != null)
      'transaction_shape=${row.transactionShape}',
    if (row.batchLayout != null) 'batch_layout=${row.batchLayout}',
  };

  final seen = <String>{};
  return [
    for (final note in row.notes)
      if (!hiddenNotes.contains(note) && seen.add(note)) note,
  ];
}

List<PerfMeasurementGroupData> groupMeasurementsForSuite(
  String suite,
  List<perf_types.PerfMeasurementRow> rows,
  perf_types.PerfCatalog? catalog,
) {
  final grouped = <String, List<perf_types.PerfMeasurementRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(
        row.measurementId, () => <perf_types.PerfMeasurementRow>[]);
    grouped[row.measurementId]!.add(row);
  }

  final suiteEntries = [
    for (final entry
        in catalog?.measurements ?? const <perf_types.PerfCatalogEntry>[])
      if (entry.suite == suite) entry,
  ];
  final measurementOrder = <String, int>{
    for (var i = 0; i < suiteEntries.length; i++)
      suiteEntries[i].measurementId: i,
  };
  final descriptions = <String, String>{
    for (final entry in suiteEntries)
      if (entry.description.isNotEmpty) entry.measurementId: entry.description,
  };

  final measurementIds = grouped.keys.toList()
    ..sort((left, right) {
      final leftOrder = measurementOrder[left] ?? 1 << 20;
      final rightOrder = measurementOrder[right] ?? 1 << 20;
      if (leftOrder != rightOrder) {
        return leftOrder.compareTo(rightOrder);
      }
      return humanizeSnakeCase(left).compareTo(humanizeSnakeCase(right));
    });

  return [
    for (final measurementId in measurementIds)
      PerfMeasurementGroupData(
        measurementId: measurementId,
        description: descriptions[measurementId],
        rows: [...grouped[measurementId]!]..sort(_compareMeasurementRows),
      ),
  ];
}

int _compareMeasurementRows(
  perf_types.PerfMeasurementRow left,
  perf_types.PerfMeasurementRow right,
) {
  var result = _compareNullableInt(left.txCount, right.txCount);
  if (result != 0) {
    return result;
  }
  result = _compareNullableString(left.batchLayout, right.batchLayout);
  if (result != 0) {
    return result;
  }
  result =
      _compareNullableString(left.transactionShape, right.transactionShape);
  if (result != 0) {
    return result;
  }
  result = _compareNullableInt(left.proofNodes, right.proofNodes);
  if (result != 0) {
    return result;
  }
  result = _compareNullableBigInt(left.proofSizeBytes, right.proofSizeBytes);
  if (result != 0) {
    return result;
  }
  result = _compareNullableBigInt(left.touchedLeaves, right.touchedLeaves);
  if (result != 0) {
    return result;
  }
  return left.avgUs.compareTo(right.avgUs);
}

int _compareNullableInt(int? left, int? right) {
  return (left ?? -1).compareTo(right ?? -1);
}

int _compareNullableString(String? left, String? right) {
  return (left ?? '').compareTo(right ?? '');
}

int _compareNullableBigInt(BigInt? left, BigInt? right) {
  return (left ?? BigInt.from(-1)).compareTo(right ?? BigInt.from(-1));
}
