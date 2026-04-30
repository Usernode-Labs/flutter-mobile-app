import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';

final _log = LoggingService.instance.withTag('usernode/SlotOutcomeRecorder');

/// Hard ceiling on the embedded-node RPC call we make to fetch lifecycle
/// details. Local RPC, so should be fast — but we never want a slow node to
/// block the slot-monitor cleanup path. On timeout the report ships with
/// client-side context only (node-side fields stay `null`).
const _kNodeFetchTimeout = Duration(seconds: 3);

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
/// **Node-side enrichment**: if a producer-side flow summary has been
/// persisted (via the `feat/per-slot-lifecycle-rpc` SQLite columns), the
/// recorder pulls it via the `epoch_slot_details` RPC and merges the
/// flattened fields (`flow_outcome`, `discard_reason`, per-stage timings,
/// …) into the report. Failures here are logged and degrade to `null` so a
/// client-only report still ships.
class SlotOutcomeRecorder {
  SlotOutcomeRecorder._();
  static final SlotOutcomeRecorder instance = SlotOutcomeRecorder._();

  /// Optional dependency overrides for testing.
  SlotOutcomeBufferRepository _buffer = SlotOutcomeBufferRepository.instance;
  MetricsCollectorService _collector = MetricsCollectorService.instance;
  RustBackendService _backend = RustBackendService.instance;

  /// Test-only: swap dependencies. Call without arguments to restore the
  /// real instances.
  void debugSetDependencies({
    SlotOutcomeBufferRepository? buffer,
    MetricsCollectorService? collector,
    RustBackendService? backend,
  }) {
    _buffer = buffer ?? SlotOutcomeBufferRepository.instance;
    _collector = collector ?? MetricsCollectorService.instance;
    _backend = backend ?? RustBackendService.instance;
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
    final clientFuture = _safeCollectClientContext();
    final nodeFuture = epoch != null
        ? _safeFetchNodeDetail(epoch: epoch, globalSlot: globalSlot)
        : Future<_NodeSlotSnapshot?>.value(null);

    // Fan out both fetches concurrently. The node-side call is local but we
    // still don't want a stuck RPC to delay client-context capture.
    final results = await Future.wait([clientFuture, nodeFuture]);
    final context = results[0] as ClientContextSnapshot;
    final node = results[1] as _NodeSlotSnapshot?;

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
      // Client-observed `blockHeight`/`producedAt` win when present (already
      // verified on canonical chain); node-side fields fill the gaps.
      blockHash: node?.blockHash,
      blockHeight: blockHeight ?? node?.blockHeight,
      canonical: node?.canonical,
      producedAtMs:
          producedAt?.millisecondsSinceEpoch ?? node?.blockInjectedAtMs,
      discardedAtMs: node?.discardedAtMs,
      nodeSlotStatus: node?.nodeSlotStatus,
      flowOutcome: node?.flowOutcome,
      flowOutcomeDetail: node?.flowOutcomeDetail,
      discardReason: node?.discardReason,
      emptyReason: node?.emptyReason,
      blockInjectedAtMs: node?.blockInjectedAtMs,
      flowSummaryAtMs: node?.flowSummaryAtMs,
      buildMs: node?.buildMs,
      dbDiffMs: node?.dbDiffMs,
      signMs: node?.signMs,
      injectMs: node?.injectMs,
      batchFetchMs: node?.batchFetchMs,
      hydrationVisibleMs: node?.hydrationVisibleMs,
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
          'flow_outcome': node?.flowOutcome,
          'node_slot_status': node?.nodeSlotStatus,
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

  Future<ClientContextSnapshot> _safeCollectClientContext() async {
    try {
      return await _collector.collectClientContextSnapshot();
    } catch (e) {
      _log.warn('client-context snapshot failed: $e');
      return const ClientContextSnapshot.empty();
    }
  }

  /// Pull the per-slot lifecycle row from the embedded node. Best-effort:
  /// any failure (RPC unavailable, slot not yet persisted, timeout) returns
  /// `null` and the report ships without node-side fields.
  Future<_NodeSlotSnapshot?> _safeFetchNodeDetail({
    required int epoch,
    required int globalSlot,
  }) async {
    try {
      final resp = await _backend
          .getEpochSlotDetails(epoch: epoch)
          .timeout(_kNodeFetchTimeout);
      if (resp == null) return null;

      RpcSlotDetail? detail;
      for (final d in resp.details) {
        if (d.globalSlot == globalSlot) {
          detail = d;
          break;
        }
      }
      if (detail == null) {
        _log.debug(
          'No slot detail for slot $globalSlot in epoch $epoch '
          '(${resp.details.length} details returned)',
        );
        return null;
      }
      return _NodeSlotSnapshot.fromDetail(detail);
    } catch (e) {
      _log.debug('node-side slot detail fetch failed: $e');
      return null;
    }
  }
}

/// Internal value-object: subset of [RpcSlotDetail] we need to inject into
/// [SlotOutcomeReport]. Keeps the FRB-opaque [BlockHash] resolved to a
/// `String` and the `BigInt` timing fields normalized to `int` so the
/// recorder doesn't deal in two numeric types.
class _NodeSlotSnapshot {
  final String? blockHash;
  final int? blockHeight;
  final bool? canonical;
  final int? blockInjectedAtMs;
  final int? discardedAtMs;
  final String? nodeSlotStatus;
  final String? flowOutcome;
  final String? flowOutcomeDetail;
  final String? discardReason;
  final String? emptyReason;
  final int? flowSummaryAtMs;
  final int? buildMs;
  final int? dbDiffMs;
  final int? signMs;
  final int? injectMs;
  final int? batchFetchMs;
  final int? hydrationVisibleMs;

  _NodeSlotSnapshot._({
    this.blockHash,
    this.blockHeight,
    this.canonical,
    this.blockInjectedAtMs,
    this.discardedAtMs,
    this.nodeSlotStatus,
    this.flowOutcome,
    this.flowOutcomeDetail,
    this.discardReason,
    this.emptyReason,
    this.flowSummaryAtMs,
    this.buildMs,
    this.dbDiffMs,
    this.signMs,
    this.injectMs,
    this.batchFetchMs,
    this.hydrationVisibleMs,
  });

  factory _NodeSlotSnapshot.fromDetail(RpcSlotDetail d) => _NodeSlotSnapshot._(
        blockHash: d.blockHash?.toString(),
        // The current RPC schema doesn't surface block height directly on
        // RpcSlotDetail (use `produced_block_metadata` for that); leave null
        // and let the client-supplied `blockHeight` win on `recordProduced`.
        blockHeight: null,
        canonical: d.canonical,
        blockInjectedAtMs: d.blockInjectedAtMs?.toInt(),
        discardedAtMs: d.discardedAtMs?.toInt(),
        nodeSlotStatus: d.status.name,
        flowOutcome: d.flowOutcome,
        flowOutcomeDetail: d.flowOutcomeDetail,
        discardReason: d.discardReason,
        emptyReason: d.emptyReason,
        flowSummaryAtMs: d.flowSummaryAtMs?.toInt(),
        buildMs: d.buildMs?.toInt(),
        dbDiffMs: d.dbDiffMs?.toInt(),
        signMs: d.signMs?.toInt(),
        injectMs: d.injectMs?.toInt(),
        batchFetchMs: d.batchFetchMs?.toInt(),
        hydrationVisibleMs: d.hydrationVisibleMs?.toInt(),
      );
}
