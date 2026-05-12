import 'dart:async';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/metrics/data/slot_outcome_buffer_repository.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = LoggingService.instance.withTag('usernode/SlotOutcomeDrain');

/// Drain terminal per-slot outcomes from the embedded node into the metrics
/// buffer.
///
/// **Why this exists**: the node already persists a comprehensive per-slot
/// lifecycle row (status + canonical block hash + per-stage timings + flow
/// outcome) for every produced/missed/orphaned slot via the
/// `epoch_slot_details` RPC. The dashboard's `slot_outcome_reports` table
/// wants exactly that, augmented with client context. So instead of trying
/// to actively monitor each slot in real time on the phone (and missing the
/// ones that fire while the app is killed), we periodically poll what the
/// node has already recorded, dedup against what we've already shipped, and
/// piggyback the deltas on the next metrics POST.
///
/// **Scope**: only slots in the current and previous epoch are drained. As
/// long as the app phones home at least once every two full epochs, no slot
/// is missed. Staleness beyond that is acceptable — analytics is best-effort
/// and the node still has the data if we ever want a full backfill.
///
/// **Dedup**: each shipped report is keyed by `"<epoch>:<globalSlot>:<status>"`.
/// The status component lets a slot that transitioned `orphaned → produced`
/// (deep reorg) emit a fresh report; analytics joins them by `global_slot`
/// to reconstruct the lineage. Keys are persisted in `SharedPreferences`
/// (network-prefixed, so chain switches reset the set) and pruned each
/// drain to keys whose epoch is within `_kPruneWindow` of the current epoch.
///
/// **Concurrency**: `drain()` is serialized so back-to-back calls (e.g.
/// `MetricsReportingService.reportNow()` racing the periodic tick) don't
/// double-ship the same outcome.
///
/// **Statuses drained**: `produced`, `missed`, `orphaned`. The other variants
/// (`scheduled`, `notWon`, `notCalculated`) are non-terminal or carry no
/// lifecycle information, so they're ignored — they'll get re-evaluated on
/// the next drain once they reach a terminal state.
class SlotOutcomeDrainService {
  SlotOutcomeDrainService._();
  static final SlotOutcomeDrainService instance = SlotOutcomeDrainService._();

  /// Test-only: swap dependencies. Call without arguments to restore real
  /// instances.
  void debugSetDependencies({
    SlotOutcomeBufferRepository? buffer,
    MetricsCollectorService? collector,
    RustBackendService? backend,
  }) {
    _buffer = buffer ?? SlotOutcomeBufferRepository.instance;
    _collector = collector ?? MetricsCollectorService.instance;
    _backend = backend ?? RustBackendService.instance;
  }

  SlotOutcomeBufferRepository _buffer = SlotOutcomeBufferRepository.instance;
  MetricsCollectorService _collector = MetricsCollectorService.instance;
  RustBackendService _backend = RustBackendService.instance;

  /// Hard ceiling on each per-epoch RPC call. Local RPC, so should be fast,
  /// but never block the periodic metrics tick on a slow node.
  static const Duration _kRpcTimeout = Duration(seconds: 5);

  /// Drain `[currentEpoch, currentEpoch - 1]`. Older epochs are pruned from
  /// the dedup set so the persisted shipped-keys list stays bounded.
  static const int _kEpochsBack = 1;

  /// Drop dedup keys older than this many epochs behind the current epoch.
  /// One epoch of headroom past `_kEpochsBack` so a key persists long enough
  /// to suppress duplicate ships across the boundary.
  static const int _kPruneWindow = _kEpochsBack + 1;

  static const String _shippedKeyPrefsBase = 'slot_outcome_drain_shipped';
  static String get _shippedKeyPrefs =>
      NetworkPrefs.prefixKey(_shippedKeyPrefsBase);

  bool _initialized = false;
  SharedPreferences? _prefs;
  Future<SharedPreferences>? _prefsFuture;

  /// In-memory shadow of the persisted shipped-key set. Mutated under
  /// [_drainLock]; flushed back to prefs at the end of each drain.
  final Set<String> _shipped = <String>{};

  /// Serialises [drain] calls.
  Future<void> _drainLock = Future<void>.value();

  /// Pull terminal slot outcomes from the node and append any not-yet-shipped
  /// ones to the buffer. Returns the number of new reports appended (0 on
  /// no-op or any failure that prevents progress). Never throws.
  Future<int> drain() {
    final completer = Completer<int>();
    final previous = _drainLock;
    _drainLock = completer.future.then<void>((_) {}, onError: (_) {});
    previous.whenComplete(() async {
      try {
        final n = await _drainOnce();
        completer.complete(n);
      } catch (e, st) {
        _log.warn('drain() failed: $e', context: {'stack': st.toString()});
        completer.complete(0);
      }
    });
    return completer.future;
  }

  Future<int> _drainOnce() async {
    if (!await _ensureReady()) return 0;

    // Discover the current epoch + slotsInEpoch from a single status call.
    final RpcStatusResp? status;
    try {
      status = await _backend.getStatus().timeout(_kRpcTimeout);
    } catch (e) {
      _log.debug('getStatus failed during drain: $e');
      return 0;
    }
    if (status == null) {
      _log.debug('getStatus returned null; node not ready, skipping drain');
      return 0;
    }
    final node = status.node;
    final currentEpoch = node.curEpoch;
    final slotsInEpoch = node.slotsInEpoch;
    if (currentEpoch == null || slotsInEpoch <= 0) {
      _log.debug(
        'Skipping drain: incomplete status',
        context: {
          'cur_epoch': currentEpoch,
          'slots_in_epoch': slotsInEpoch,
        },
      );
      return 0;
    }

    // Snapshot client context once so every report appended in this drain
    // shares the same battery/network/app-state values. This is "context at
    // the time of shipping", which is the best we can do — the slot itself
    // may have been produced hours ago.
    final ClientContextSnapshot context = await _safeCollectContext();

    // Prune keys for epochs that have aged out before we add new ones, so the
    // persisted set stays bounded by ~`_kPruneWindow` epochs of activity.
    _pruneOldKeys(currentEpoch);

    var totalAppended = 0;
    for (var i = 0; i <= _kEpochsBack; i++) {
      final epoch = currentEpoch - i;
      if (epoch < 0) continue;
      totalAppended += await _drainEpoch(
        epoch: epoch,
        slotsInEpoch: slotsInEpoch,
        context: context,
      );
    }

    if (totalAppended > 0 || _shippedDirty) {
      await _persistShipped();
    }

    // Both branches log at INFO so we can distinguish "drain ran but found
    // nothing" from "drain never ran" without having to bump the global log
    // level. Cheap: at most one line per metrics tick (~25s).
    if (totalAppended > 0) {
      _log.info(
        'Drained terminal slot outcomes',
        context: {
          'current_epoch': currentEpoch,
          'epochs_back': _kEpochsBack,
          'appended': totalAppended,
          'shipped_keys_total': _shipped.length,
        },
      );
    } else {
      _log.info(
        'Drain pass found no new terminal outcomes',
        context: {
          'current_epoch': currentEpoch,
          'shipped_keys_total': _shipped.length,
        },
      );
    }
    return totalAppended;
  }

  Future<int> _drainEpoch({
    required int epoch,
    required int slotsInEpoch,
    required ClientContextSnapshot context,
  }) async {
    final RpcEpochSlotDetailsResp? resp;
    try {
      resp = await _backend
          .getEpochSlotDetails(epoch: epoch)
          .timeout(_kRpcTimeout);
    } catch (e) {
      _log.debug('getEpochSlotDetails(epoch=$epoch) failed: $e');
      return 0;
    }
    if (resp == null) {
      _log.debug('No slot details for epoch $epoch (RPC unavailable)');
      return 0;
    }

    var appended = 0;
    for (final detail in resp.details) {
      if (!_isTerminalStatus(detail.status)) continue;
      final key = _shippedKey(epoch: epoch, detail: detail);
      if (_shipped.contains(key)) continue;

      final report = _buildReport(
        epoch: epoch,
        slotsInEpoch: slotsInEpoch,
        detail: detail,
        context: context,
      );

      try {
        await _buffer.append(report);
        _shipped.add(key);
        _shippedDirty = true;
        appended++;
      } catch (e) {
        // Don't add to dedup set on failure — try again next drain.
        _log.warn(
          'Failed to buffer drained slot outcome',
          context: {
            'epoch': epoch,
            'global_slot': detail.globalSlot,
            'status': detail.status.name,
            'error': e.toString(),
          },
        );
      }
    }
    if (appended > 0) {
      _log.debug(
        'Drained epoch $epoch',
        context: {
          'epoch': epoch,
          'appended': appended,
          'details_seen': resp.details.length,
        },
      );
    }
    return appended;
  }

  bool _shippedDirty = false;

  bool _isTerminalStatus(RpcSlotResult s) =>
      s == RpcSlotResult.produced ||
      s == RpcSlotResult.missed ||
      s == RpcSlotResult.orphaned;

  String _shippedKey({required int epoch, required RpcSlotDetail detail}) =>
      '$epoch:${detail.globalSlot}:${detail.status.name}';

  /// Map node-side terminal classification to the client-side outcome
  /// taxonomy. The detailed truth (canonical, flow_outcome, …) still ships
  /// in dedicated fields; this just buckets for the dashboard's
  /// "produced vs not-produced" view:
  ///   - produced  → produced (canonical block landed)
  ///   - orphaned  → produced (block existed; `canonical: false` disambiguates)
  ///   - missed    → monitoringTimeout (no block on chain)
  SlotOutcomeKind _outcomeFor(RpcSlotResult s) {
    switch (s) {
      case RpcSlotResult.produced:
      case RpcSlotResult.orphaned:
        return SlotOutcomeKind.produced;
      case RpcSlotResult.missed:
        return SlotOutcomeKind.monitoringTimeout;
      case RpcSlotResult.scheduled:
      case RpcSlotResult.notWon:
      case RpcSlotResult.notCalculated:
        return SlotOutcomeKind.unknown;
    }
  }

  String? _outcomeReasonFor(RpcSlotDetail d) {
    if (d.status == RpcSlotResult.missed) {
      return d.flowOutcome ?? 'Missed (no block on chain)';
    }
    if (d.status == RpcSlotResult.orphaned) {
      return 'Orphaned (block produced, replaced by reorg)';
    }
    return null;
  }

  SlotOutcomeReport _buildReport({
    required int epoch,
    required int slotsInEpoch,
    required RpcSlotDetail detail,
    required ClientContextSnapshot context,
  }) {
    final globalSlot = detail.globalSlot;
    final capturedAtMs = DateTime.now().millisecondsSinceEpoch;
    final slotInEpoch = slotsInEpoch > 0 ? globalSlot % slotsInEpoch : null;
    return SlotOutcomeReport(
      id: SlotOutcomeReport.buildId(globalSlot, capturedAtMs),
      capturedAtMs: capturedAtMs,
      globalSlot: globalSlot,
      epoch: epoch,
      slotInEpoch: slotInEpoch,
      slotTimeMs: detail.flowSlotTimeMs?.toInt(),
      // chainId / walletAddress intentionally omitted: the surrounding
      // metrics POST already carries chain identity, and the recorder path
      // never wired walletAddress through either.
      outcome: _outcomeFor(detail.status),
      outcomeReason: _outcomeReasonFor(detail),
      blockHash: detail.blockHash?.toString(),
      // RpcSlotDetail doesn't surface block_height directly today.
      blockHeight: null,
      canonical: detail.canonical,
      producedAtMs: detail.producedAtMs?.toInt(),
      discardedAtMs: detail.discardedAtMs?.toInt(),
      nodeSlotStatus: detail.status.name,
      flowOutcome: detail.flowOutcome,
      flowOutcomeDetail: detail.flowOutcomeDetail,
      discardReason: detail.discardReason,
      emptyReason: detail.emptyReason,
      blockInjectedAtMs: detail.blockInjectedAtMs?.toInt(),
      flowSummaryAtMs: detail.flowSummaryAtMs?.toInt(),
      buildMs: detail.buildMs?.toInt(),
      dbDiffMs: detail.dbDiffMs?.toInt(),
      signMs: detail.signMs?.toInt(),
      injectMs: detail.injectMs?.toInt(),
      batchFetchMs: detail.batchFetchMs?.toInt(),
      hydrationVisibleMs: detail.hydrationVisibleMs?.toInt(),
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
    );
  }

  Future<ClientContextSnapshot> _safeCollectContext() async {
    try {
      return await _collector.collectClientContextSnapshot();
    } catch (e) {
      _log.debug('client-context snapshot failed: $e');
      return const ClientContextSnapshot.empty();
    }
  }

  void _pruneOldKeys(int currentEpoch) {
    final cutoff = currentEpoch - _kPruneWindow;
    if (cutoff < 0) return;
    final toRemove = <String>[];
    for (final key in _shipped) {
      final colon = key.indexOf(':');
      if (colon <= 0) continue;
      final epoch = int.tryParse(key.substring(0, colon));
      if (epoch != null && epoch < cutoff) toRemove.add(key);
    }
    if (toRemove.isEmpty) return;
    _shipped.removeAll(toRemove);
    _shippedDirty = true;
    _log.debug(
      'Pruned aged-out drain dedup keys',
      context: {
        'cutoff_epoch': cutoff,
        'removed': toRemove.length,
        'remaining': _shipped.length,
      },
    );
  }

  Future<bool> _ensureReady() async {
    if (_initialized) return true;
    try {
      _prefsFuture ??= SharedPreferences.getInstance();
      _prefs = await _prefsFuture!;
    } catch (e) {
      _prefsFuture = null;
      _log.error('SharedPreferences init failed: $e');
      return false;
    }
    final raw = _prefs?.getStringList(_shippedKeyPrefs);
    if (raw != null) _shipped.addAll(raw);
    _shippedDirty = false;
    _initialized = true;
    // INFO so we get a one-shot confirmation per app session that the drain
    // service is wired in and able to read its dedup state. Same reason as
    // the per-tick INFO logs above.
    _log.info(
      'SlotOutcomeDrainService initialized',
      context: {'shipped_keys_loaded': _shipped.length},
    );
    return true;
  }

  Future<void> _persistShipped() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setStringList(_shippedKeyPrefs, _shipped.toList());
      _shippedDirty = false;
    } catch (e) {
      _log.warn('Failed to persist drain dedup set: $e');
    }
  }

  /// Test/maintenance helper: drop the dedup set and the persisted backing.
  /// The next `drain()` will re-ship every terminal outcome it sees in the
  /// active epoch window.
  Future<void> debugClearDedup() async {
    if (!await _ensureReady()) return;
    _shipped.clear();
    _shippedDirty = false;
    await _prefs?.remove(_shippedKeyPrefs);
    _log.info('Cleared slot-outcome drain dedup set');
  }
}
