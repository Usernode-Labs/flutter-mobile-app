import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;

class PerfBenchmarkRepository {
  const PerfBenchmarkRepository();

  Future<perf_types.PerfCatalog> catalog(SessionOperation operation) =>
      operation.readDeviceBenchmarkCatalog();

  Future<perf_types.PerfRunHandle> startRun(
    SessionOperation operation,
    perf_types.PerfRunProfile profile,
  ) =>
      operation.startDeviceBenchmark(profile);

  Future<perf_types.PerfRunStatus?> status(
    SessionOperation operation,
    int runId,
  ) =>
      operation.readDeviceBenchmarkStatus(runId);

  Future<perf_types.PerfRunReport?> result(
    SessionOperation operation,
    int runId,
  ) =>
      operation.readDeviceBenchmarkResult(runId);

  Future<bool> cancel(SessionOperation operation, int runId) =>
      operation.cancelDeviceBenchmark(runId);
}
