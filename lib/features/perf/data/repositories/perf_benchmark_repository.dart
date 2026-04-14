import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:crypto_mobile_app/src/rust/perf.dart' as perf_api;

class PerfBenchmarkRepository {
  const PerfBenchmarkRepository();

  Future<perf_types.PerfCatalog> catalog() async {
    await RustBackendService.instance.init();
    return perf_api.catalog();
  }

  Future<perf_types.PerfRunHandle> startRun(
      perf_types.PerfRunProfile profile) async {
    await RustBackendService.instance.init();
    return perf_api.startRun(
      request: perf_types.PerfRunRequest(profile: profile),
    );
  }

  Future<perf_types.PerfRunStatus?> status(int runId) async {
    await RustBackendService.instance.init();
    return perf_api.status(runId: BigInt.from(runId));
  }

  Future<perf_types.PerfRunReport?> result(int runId) async {
    await RustBackendService.instance.init();
    return perf_api.result(runId: BigInt.from(runId));
  }

  Future<bool> cancel(int runId) async {
    await RustBackendService.instance.init();
    return perf_api.cancel(runId: BigInt.from(runId));
  }
}
