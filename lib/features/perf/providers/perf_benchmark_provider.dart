import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/perf/data/repositories/perf_benchmark_repository.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as perf_types;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _log = LoggingService.instance.withTag('usernode/PerfBenchmark');

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
  SessionFeatureAccess? _session;

  static const _repository = PerfBenchmarkRepository();

  @override
  PerfBenchmarkState build() {
    ref.onDispose(() {
      _stopPolling();
    });
    return const PerfBenchmarkState();
  }

  void bindSession(SessionFeatureAccess session) {
    final previous = _session;
    if (previous?.identity.nativeRevision == session.identity.nativeRevision &&
        previous?.identity.status == session.identity.status) {
      return;
    }
    _stopPolling();
    _session = session;
    _catalogRequested = false;
    state = PerfBenchmarkState(
      isLoadingCatalog:
          session.identity.status == SessionProjectionStatus.ready,
    );
    if (session.identity.status == SessionProjectionStatus.ready) {
      unawaited(loadCatalog());
    }
  }

  SessionFeatureAccess? _readySession() {
    final session = _session;
    if (session == null ||
        session.identity.status != SessionProjectionStatus.ready) {
      return null;
    }
    return session;
  }

  Future<void> loadCatalog({bool force = false}) async {
    if (_catalogRequested && !force) {
      return;
    }
    final session = _readySession();
    if (session == null) return;

    _catalogRequested = true;
    try {
      await session.operations.run((operation) async {
        state = state.copyWith(
          isLoadingCatalog: true,
          clearErrorMessage: true,
          clearUiError: true,
        );
        try {
          _log.info('Loading perf catalog');
          final catalog = await _repository.catalog(operation);
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
        } on SessionAdmissionClosedException {
          rethrow;
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
      });
    } on SessionAdmissionClosedException {
      // The replacement session owns all subsequent UI publication.
    }
  }

  Future<void> startRun(perf_types.PerfRunProfile profile) async {
    if (state.isRunning || state.isStartingRun) {
      return;
    }
    final session = _readySession();
    if (session == null) return;

    int? startedRunId;
    try {
      await session.operations.run((operation) async {
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
          final handle = await _repository.startRun(operation, profile);
          final runId = handle.runId.toInt();
          startedRunId = runId;
          state = state.copyWith(
            activeRunId: runId,
            isStartingRun: false,
          );
          _startPolling(runId, session);
        } on SessionAdmissionClosedException {
          rethrow;
        } catch (error, stackTrace) {
          _log.error(
            'Failed to start perf benchmark run',
            error: error,
            stackTrace: stackTrace,
          );
          state = state.copyWith(
            isStartingRun: false,
            clearRequestedProfile: true,
            errorMessage: _cleanErrorMessage(error),
          );
        }
      });
    } on SessionAdmissionClosedException {
      return;
    }
    final runId = startedRunId;
    if (runId != null) await _refreshRun(runId, session);
  }

  Future<void> cancelRun() async {
    final runId = state.activeRunId;
    if (runId == null || !state.isRunning || state.isCancelling) {
      return;
    }
    final session = _readySession();
    if (session == null) return;

    try {
      await session.operations.run((operation) async {
        state = state.copyWith(
          isCancelling: true,
          clearErrorMessage: true,
          clearUiError: true,
        );
        try {
          final cancelled = await _repository.cancel(operation, runId);
          if (!cancelled) {
            state = state.copyWith(
              isCancelling: false,
              uiError: PerfBenchmarkUiError.cancelFailed,
            );
          }
        } on SessionAdmissionClosedException {
          rethrow;
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
      });
    } on SessionAdmissionClosedException {
      // The replacement session owns all subsequent UI publication.
    }
  }

  Future<void> refreshCurrentRun() async {
    final runId = state.activeRunId;
    final session = _readySession();
    if (runId == null || session == null) return;
    await _refreshRun(runId, session);
  }

  void _startPolling(int runId, SessionFeatureAccess session) {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshRun(runId, session));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshRun(
    int runId,
    SessionFeatureAccess session,
  ) async {
    if (_refreshInFlight) {
      return;
    }

    _refreshInFlight = true;
    try {
      await session.operations.run((operation) async {
        try {
          final status = await _repository.status(operation, runId);
          if (status == null) {
            _stopPolling();
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

          if (status.state == perf_types.PerfRunState.running) return;

          _stopPolling();
          final report = await _repository.result(operation, runId);
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
        } on SessionAdmissionClosedException {
          rethrow;
        } catch (error, stackTrace) {
          _log.error(
            'Failed to refresh perf benchmark run',
            error: error,
            stackTrace: stackTrace,
          );
          state = state.copyWith(
            errorMessage: _cleanErrorMessage(error),
          );
        }
      });
    } on SessionAdmissionClosedException {
      // The captured runner closed; never retry the run id through B.
    } catch (error, stackTrace) {
      _log.error(
        'Perf benchmark session runner failed',
        error: error,
        stackTrace: stackTrace,
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
}
