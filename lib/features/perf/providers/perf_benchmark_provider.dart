import 'dart:async';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/perf/data/repositories/perf_benchmark_repository.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = LoggingService.instance.withTag('usernode/PerfBenchmark');

final perfBenchmarkRepositoryProvider = Provider<PerfBenchmarkRepository>(
  (ref) => const PerfBenchmarkRepository(),
);

final perfBenchmarkProvider =
    NotifierProvider<PerfBenchmarkController, PerfBenchmarkState>(
  PerfBenchmarkController.new,
);

enum PerfBenchmarkUiError {
  cancelFailed,
  runUnavailable,
}

class PerfBenchmarkState {
  const PerfBenchmarkState({
    this.catalog,
    this.status,
    this.report,
    this.activeRunId,
    this.requestedProfile,
    this.errorMessage,
    this.uiError,
    this.isLoadingCatalog = false,
    this.isStartingRun = false,
    this.isCancelling = false,
  });

  final perf_types.PerfCatalog? catalog;
  final perf_types.PerfRunStatus? status;
  final perf_types.PerfRunReport? report;
  final int? activeRunId;
  final perf_types.PerfRunProfile? requestedProfile;
  final String? errorMessage;
  final PerfBenchmarkUiError? uiError;
  final bool isLoadingCatalog;
  final bool isStartingRun;
  final bool isCancelling;

  bool get isRunning => status?.state == perf_types.PerfRunState.running;

  bool get hasFinishedRun {
    final runState = status?.state;
    return runState == perf_types.PerfRunState.completed ||
        runState == perf_types.PerfRunState.failed ||
        runState == perf_types.PerfRunState.cancelled;
  }

  PerfBenchmarkState copyWith({
    perf_types.PerfCatalog? catalog,
    perf_types.PerfRunStatus? status,
    perf_types.PerfRunReport? report,
    int? activeRunId,
    perf_types.PerfRunProfile? requestedProfile,
    String? errorMessage,
    PerfBenchmarkUiError? uiError,
    bool? isLoadingCatalog,
    bool? isStartingRun,
    bool? isCancelling,
    bool clearStatus = false,
    bool clearReport = false,
    bool clearActiveRunId = false,
    bool clearRequestedProfile = false,
    bool clearErrorMessage = false,
    bool clearUiError = false,
  }) {
    return PerfBenchmarkState(
      catalog: catalog ?? this.catalog,
      status: clearStatus ? null : status ?? this.status,
      report: clearReport ? null : report ?? this.report,
      activeRunId: clearActiveRunId ? null : activeRunId ?? this.activeRunId,
      requestedProfile: clearRequestedProfile
          ? null
          : requestedProfile ?? this.requestedProfile,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      uiError: clearUiError ? null : uiError ?? this.uiError,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      isStartingRun: isStartingRun ?? this.isStartingRun,
      isCancelling: isCancelling ?? this.isCancelling,
    );
  }
}

class PerfBenchmarkController extends Notifier<PerfBenchmarkState> {
  Timer? _pollTimer;
  bool _catalogRequested = false;
  bool _refreshInFlight = false;
  bool _pausedNodeForRun = false;

  PerfBenchmarkRepository get _repository =>
      ref.read(perfBenchmarkRepositoryProvider);

  @override
  PerfBenchmarkState build() {
    ref.onDispose(() {
      _stopPolling();
      unawaited(_resumeNodeIfNeeded());
    });
    Future<void>(() async {
      await loadCatalog();
    });
    return const PerfBenchmarkState(isLoadingCatalog: true);
  }

  Future<void> loadCatalog({bool force = false}) async {
    if (_catalogRequested && !force) {
      return;
    }

    _catalogRequested = true;
    state = state.copyWith(
      isLoadingCatalog: true,
      clearErrorMessage: true,
      clearUiError: true,
    );

    try {
      _log.info('Loading perf catalog');
      final catalog = await _repository.catalog();
      _log.info(
        'Loaded perf catalog',
        context: {
          'profiles': catalog.profiles.length,
          'measurements': catalog.measurements.length,
        },
      );
      state = state.copyWith(
        catalog: catalog,
        isLoadingCatalog: false,
      );
    } catch (error, stackTrace) {
      _log.error(
        'Failed to load perf catalog',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoadingCatalog: false,
        errorMessage: _cleanErrorMessage(error),
      );
    }
  }

  Future<void> startRun(perf_types.PerfRunProfile profile) async {
    if (state.isRunning || state.isStartingRun) {
      return;
    }

    state = state.copyWith(
      isStartingRun: true,
      isCancelling: false,
      clearErrorMessage: true,
      clearUiError: true,
      clearReport: true,
      clearStatus: true,
      clearActiveRunId: true,
      requestedProfile: profile,
    );

    try {
      await _pauseNodeIfNeeded();
      final handle = await _repository.startRun(profile);
      final runId = handle.runId.toInt();
      state = state.copyWith(
        activeRunId: runId,
        isStartingRun: false,
      );
      _startPolling(runId);
      await _refreshRun(runId);
    } catch (error, stackTrace) {
      _log.error(
        'Failed to start perf benchmark run',
        error: error,
        stackTrace: stackTrace,
      );
      await _resumeNodeIfNeeded();
      state = state.copyWith(
        isStartingRun: false,
        clearRequestedProfile: true,
        errorMessage: _cleanErrorMessage(error),
      );
    }
  }

  Future<void> cancelRun() async {
    final runId = state.activeRunId;
    if (runId == null || !state.isRunning || state.isCancelling) {
      return;
    }

    state = state.copyWith(
      isCancelling: true,
      clearErrorMessage: true,
      clearUiError: true,
    );

    try {
      final cancelled = await _repository.cancel(runId);
      if (!cancelled) {
        state = state.copyWith(
          isCancelling: false,
          uiError: PerfBenchmarkUiError.cancelFailed,
        );
      }
    } catch (error, stackTrace) {
      _log.error(
        'Failed to cancel perf benchmark run',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isCancelling: false,
        errorMessage: _cleanErrorMessage(error),
      );
    }
  }

  Future<void> refreshCurrentRun() async {
    final runId = state.activeRunId;
    if (runId == null) {
      return;
    }
    await _refreshRun(runId);
  }

  void _startPolling(int runId) {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshRun(runId));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshRun(int runId) async {
    if (_refreshInFlight) {
      return;
    }

    _refreshInFlight = true;
    try {
      final status = await _repository.status(runId);
      if (status == null) {
        _stopPolling();
        await _resumeNodeIfNeeded();
        state = state.copyWith(
          isCancelling: false,
          clearStatus: true,
          clearActiveRunId: true,
          clearRequestedProfile: true,
          uiError: PerfBenchmarkUiError.runUnavailable,
        );
        return;
      }

      state = state.copyWith(
        status: status,
        activeRunId: runId,
        isCancelling: false,
        clearRequestedProfile: true,
        clearErrorMessage: true,
        clearUiError: true,
      );

      if (status.state == perf_types.PerfRunState.running) {
        return;
      }

      _stopPolling();
      final report = await _repository.result(runId);
      await _resumeNodeIfNeeded();
      state = state.copyWith(
        status: status,
        report: report,
        activeRunId: runId,
        isCancelling: false,
        errorMessage: status.state == perf_types.PerfRunState.failed
            ? status.error
            : null,
        clearErrorMessage: status.state != perf_types.PerfRunState.failed,
      );
    } catch (error, stackTrace) {
      _log.error(
        'Failed to refresh perf benchmark run',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        errorMessage: _cleanErrorMessage(error),
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString();
    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('AnyhowException: ', '')
        .trim();
  }

  Future<void> _pauseNodeIfNeeded() async {
    if (_pausedNodeForRun) {
      return;
    }

    final backend = RustBackendService.instance;
    if (!backend.isRunning) {
      return;
    }

    _log.info('Pausing background node for benchmark run');
    await backend.pauseNode();
    _pausedNodeForRun = true;
  }

  Future<void> _resumeNodeIfNeeded() async {
    if (!_pausedNodeForRun) {
      return;
    }

    _log.info('Resuming background node after benchmark run');
    await RustBackendService.instance.resumeNode();
    _pausedNodeForRun = false;
  }
}
