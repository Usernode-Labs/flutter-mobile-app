import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';

final _log = LoggingService.instance.withTag('usernode/SlotOutcomeRecorder');

/// Captures a [SlotOutcomeReport] at the moment a won slot reaches a terminal
/// state from the Flutter app's perspective and appends it to
/// [SlotOutcomeBufferRepository] for the next metrics POST.
///
/// **Why a recorder rather than wiring directly**: keeps `SlotMonitorService`
/// free of payload-construction logic and makes the chokepoint testable
/// without spinning up the embedded node.
///
/// **Snapshot timing**: the client-context fields (`appState`, `networkType`,
/// `batteryLevel`, …) are captured *now*, not at POST time. That's the whole
/// point of buffering — we want the state during the slot window, not 25
/// seconds later when the next periodic POST happens.
///
/// **Node-side enrichment**: pipeline timings, `flow_outcome`,
/// `discard_reason` etc. are intentionally not populated here. They land in
/// the per-slot SQLite-persisted data in usernode (already shipped under
/// `feat/per-slot-lifecycle-rpc`) and will be pulled via the
/// `epoch_slot_details` RPC once FRB bindings are regenerated. Topochain
/// joins the two sides; missing fields here just mean the node-side
/// timeline isn't available yet for a given slot.
class SlotOutcomeRecorder {
  SlotOutcomeRecorder._();
  static final SlotOutcomeRecorder instance = SlotOutcomeRecorder._();

  /// Optional dependency overrides for testing.
  SlotOutcomeBufferRepository _buffer = SlotOutcomeBufferRepository.instance;
  MetricsCollectorService _collector = MetricsCollectorService.instance;

  /// Test-only: swap dependencies. Call without arguments to restore the
  /// real instances.
  void debugSetDependencies({
    SlotOutcomeBufferRepository? buffer,
    MetricsCollectorService? collector,
  }) {
    _buffer = buffer ?? SlotOutcomeBufferRepository.instance;
    _collector = collector ?? MetricsCollectorService.instance;
  }

  /// Record that the won slot was produced and visible on chain.
  Future<void> recordProduced({
    required int globalSlot,
    int? epoch,
    DateTime? slotTime,
    int? blockHeight,
    DateTime? producedAt,
    String? chainId,
    String? walletAddress,
    DateTime? alarmScheduledAt,
    DateTime? alarmFiredAt,
    DateTime? monitoringStartedAt,
  }) =>
      _record(
        outcome: SlotOutcomeKind.produced,
        outcomeReason: null,
        globalSlot: globalSlot,
        epoch: epoch,
        slotTime: slotTime,
        blockHeight: blockHeight,
        producedAt: producedAt,
        chainId: chainId,
        walletAddress: walletAddress,
        alarmScheduledAt: alarmScheduledAt,
        alarmFiredAt: alarmFiredAt,
        monitoringStartedAt: monitoringStartedAt,
      );

  /// Record that monitoring timed out without seeing a block on chain.
  Future<void> recordMonitoringTimeout({
    required int globalSlot,
    int? epoch,
    DateTime? slotTime,
    String? reason,
    String? chainId,
    String? walletAddress,
    DateTime? alarmScheduledAt,
    DateTime? alarmFiredAt,
    DateTime? monitoringStartedAt,
  }) =>
      _record(
        outcome: SlotOutcomeKind.monitoringTimeout,
        outcomeReason: reason ?? 'Monitoring timeout',
        globalSlot: globalSlot,
        epoch: epoch,
        slotTime: slotTime,
        chainId: chainId,
        walletAddress: walletAddress,
        alarmScheduledAt: alarmScheduledAt,
        alarmFiredAt: alarmFiredAt,
        monitoringStartedAt: monitoringStartedAt,
      );

  Future<void> _record({
    required SlotOutcomeKind outcome,
    required int globalSlot,
    String? outcomeReason,
    int? epoch,
    DateTime? slotTime,
    int? blockHeight,
    DateTime? producedAt,
    String? chainId,
    String? walletAddress,
    DateTime? alarmScheduledAt,
    DateTime? alarmFiredAt,
    DateTime? monitoringStartedAt,
  }) async {
    // Capture context first; do not let context-collection failure prevent
    // the report from being buffered.
    ClientContextSnapshot context;
    try {
      context = await _collector.collectClientContextSnapshot();
    } catch (e) {
      _log.warn('client-context snapshot failed: $e');
      context = const ClientContextSnapshot.empty();
    }

    final capturedAtMs = DateTime.now().millisecondsSinceEpoch;
    final report = SlotOutcomeReport(
      id: SlotOutcomeReport.buildId(globalSlot, capturedAtMs),
      capturedAtMs: capturedAtMs,
      globalSlot: globalSlot,
      epoch: epoch,
      slotTimeMs: slotTime?.millisecondsSinceEpoch,
      chainId: chainId,
      walletAddress: walletAddress,
      outcome: outcome,
      outcomeReason: outcomeReason,
      blockHeight: blockHeight,
      producedAtMs: producedAt?.millisecondsSinceEpoch,
      appState: context.appState,
      networkType: context.networkType,
      networkConnected: context.networkConnected,
      platform: context.platform,
      platformVersion: context.platformVersion,
      appVersion: context.appVersion,
      appBuildNumber: context.appBuildNumber,
      batteryLevel: context.batteryLevel,
      wakelockHeld: context.wakelockHeld,
      foregroundServiceRunning: context.foregroundServiceRunning,
      alarmScheduledAtMs: alarmScheduledAt?.millisecondsSinceEpoch,
      alarmFiredAtMs: alarmFiredAt?.millisecondsSinceEpoch,
      monitoringStartedAtMs: monitoringStartedAt?.millisecondsSinceEpoch,
    );

    try {
      await _buffer.append(report);
      _log.info(
        'Buffered slot outcome',
        context: {
          'global_slot': globalSlot,
          'outcome': outcome.name,
          'app_state': context.appState,
        },
      );
    } catch (e, st) {
      _log.error(
        'Failed to buffer slot outcome',
        error: e,
        stackTrace: st,
        context: {'global_slot': globalSlot, 'outcome': outcome.name},
      );
    }
  }
}
