/// Per-slot lifecycle report for the analytics backend (topochain).
///
/// One report is captured at the moment a won slot reaches a terminal state
/// from the Flutter app's perspective (block produced, monitoring timeout, or
/// any future failure path). Reports are appended to a SharedPreferences
/// buffer and shipped piggybacked on the next metrics POST. The backend joins
/// these client reports with node-side `epoch_slot_details` (RPC added in
/// usernode `feat/per-slot-lifecycle-rpc`) to produce a full per-slot
/// timeline.
///
/// Field naming uses snake_case JSON keys to match the metrics API style.
/// Schema is forward-compatible: the backend is expected to ignore unknown
/// keys, and any field not yet known at capture time is omitted (not null).
library;

/// Outcome buckets visible from the client side.
///
/// These intentionally do NOT mirror the node-side `flow_outcome` taxonomy.
/// The client only sees what `SlotMonitorService` can detect from chain reads
/// (block landed vs. timeout) plus future native paths (alarm missed,
/// app-killed). Topochain joins this with the node-side terminal stage to
/// produce the final classification.
enum SlotOutcomeKind {
  /// Block landed on the canonical chain at this slot.
  produced,

  /// Monitoring window expired without seeing the block on chain. May still
  /// have been produced and orphaned, or never produced — node-side data
  /// disambiguates.
  monitoringTimeout,

  /// Reserved for future use: an alarm was scheduled for this slot but never
  /// fired (or fired late) per native bookkeeping.
  alarmMissed,

  /// Reserved for future use: app was killed/detached during the window.
  appDead,

  /// Anything not yet classified.
  unknown,
}

extension _SlotOutcomeKindWire on SlotOutcomeKind {
  String get wire => switch (this) {
        SlotOutcomeKind.produced => 'produced',
        SlotOutcomeKind.monitoringTimeout => 'monitoring_timeout',
        SlotOutcomeKind.alarmMissed => 'alarm_missed',
        SlotOutcomeKind.appDead => 'app_dead',
        SlotOutcomeKind.unknown => 'unknown',
      };

  static SlotOutcomeKind parse(String? raw) => switch (raw) {
        'produced' => SlotOutcomeKind.produced,
        'monitoring_timeout' => SlotOutcomeKind.monitoringTimeout,
        'alarm_missed' => SlotOutcomeKind.alarmMissed,
        'app_dead' => SlotOutcomeKind.appDead,
        _ => SlotOutcomeKind.unknown,
      };
}

/// Client-captured slot lifecycle report, queued for the next metrics POST.
class SlotOutcomeReport {
  /// Stable id for buffer dedup/discard. Format: `<global_slot>:<captured_at_ms>`.
  final String id;

  /// Wall-clock at capture time (ms since epoch). Persisted so reports
  /// survive an app restart with their original timing intact.
  final int capturedAtMs;

  // ─── Slot identity ──────────────────────────────────────────────────────
  final int globalSlot;
  final int? epoch;
  final int? slotInEpoch;

  /// Slot's expected wall-clock time (ms since epoch), if known. Helps the
  /// backend correlate with node-side `expected_time_ms`.
  final int? slotTimeMs;

  /// The chain id the producer is operating on. Lets topochain partition
  /// reports per chain. Optional — populated when readily available.
  final String? chainId;

  /// Producer wallet (address / pubkey). Optional.
  final String? walletAddress;

  // ─── Client-observed outcome ────────────────────────────────────────────
  final SlotOutcomeKind outcome;

  /// Free-form short tag for the outcome (e.g. `"Monitoring timeout"`,
  /// matches what `SlotProductionRepository` already records).
  final String? outcomeReason;

  // ─── Node-side facts captured at terminal time ──────────────────────────
  /// Block hash if a block landed at this slot (whether canonical or not).
  final String? blockHash;
  final int? blockHeight;
  final bool? canonical;

  /// Producer-local wall-clock the block was injected at (ms since epoch),
  /// from `producedBlockMetadata` if available.
  final int? producedAtMs;

  // ─── Pipeline timings (populated once `epoch_slot_details` is wired) ────
  /// Taxonomy mirrors usernode `BlockProducerFlowOutcome`. Strings, not enum,
  /// so additions on the node side don't require Flutter changes:
  /// `"block_injected" | "won_slot_discarded" | "db_diff_failed" |
  ///  "sign_failed" | "missing_identity_proof"`.
  final String? flowOutcome;

  /// e.g. `"build" | "db_diff" | "sign" | "inject"` — the last stage reached
  /// before terminal outcome.
  final String? terminalStage;

  /// Reason a won slot was discarded, if applicable.
  final String? discardReason;

  /// Per-stage durations in ms, when reported by the node.
  final int? buildMs;
  final int? dbDiffMs;
  final int? signMs;
  final int? injectMs;
  final int? batchFetchMs;
  final int? hydrationVisibleMs;

  // ─── Client context at terminal time ────────────────────────────────────
  /// `'foreground' | 'inactive' | 'background' | 'detached' | 'hidden'`,
  /// matching `RuntimeMetrics.appState`.
  final String? appState;

  /// `'wifi' | 'cellular' | …`, matching `NetworkMetrics.networkType`.
  final String? networkType;
  final bool? networkConnected;
  final String? platform; // 'android' | 'ios' | …
  final String? platformVersion;
  final String? appVersion;
  final String? appBuildNumber;
  final int? batteryLevel;
  final bool? wakelockHeld;
  final bool? foregroundServiceRunning;

  /// Wall-clock of the alarm that was scheduled for this slot, if any.
  final int? alarmScheduledAtMs;

  /// Wall-clock when the alarm actually fired, if observed.
  final int? alarmFiredAtMs;

  /// Wall-clock when monitoring was started for this slot.
  final int? monitoringStartedAtMs;

  const SlotOutcomeReport({
    required this.id,
    required this.capturedAtMs,
    required this.globalSlot,
    required this.outcome,
    this.epoch,
    this.slotInEpoch,
    this.slotTimeMs,
    this.chainId,
    this.walletAddress,
    this.outcomeReason,
    this.blockHash,
    this.blockHeight,
    this.canonical,
    this.producedAtMs,
    this.flowOutcome,
    this.terminalStage,
    this.discardReason,
    this.buildMs,
    this.dbDiffMs,
    this.signMs,
    this.injectMs,
    this.batchFetchMs,
    this.hydrationVisibleMs,
    this.appState,
    this.networkType,
    this.networkConnected,
    this.platform,
    this.platformVersion,
    this.appVersion,
    this.appBuildNumber,
    this.batteryLevel,
    this.wakelockHeld,
    this.foregroundServiceRunning,
    this.alarmScheduledAtMs,
    this.alarmFiredAtMs,
    this.monitoringStartedAtMs,
  });

  /// Build a stable id from `(global_slot, captured_at_ms)`. Two reports for
  /// the same slot at the same instant are considered duplicates by the
  /// buffer.
  static String buildId(int globalSlot, int capturedAtMs) =>
      '$globalSlot:$capturedAtMs';

  Map<String, dynamic> toJson() => {
        'id': id,
        'captured_at_ms': capturedAtMs,
        'global_slot': globalSlot,
        if (epoch != null) 'epoch': epoch,
        if (slotInEpoch != null) 'slot_in_epoch': slotInEpoch,
        if (slotTimeMs != null) 'slot_time_ms': slotTimeMs,
        if (chainId != null) 'chain_id': chainId,
        if (walletAddress != null) 'wallet_address': walletAddress,
        'outcome': outcome.wire,
        if (outcomeReason != null) 'outcome_reason': outcomeReason,
        if (blockHash != null) 'block_hash': blockHash,
        if (blockHeight != null) 'block_height': blockHeight,
        if (canonical != null) 'canonical': canonical,
        if (producedAtMs != null) 'produced_at_ms': producedAtMs,
        if (flowOutcome != null) 'flow_outcome': flowOutcome,
        if (terminalStage != null) 'terminal_stage': terminalStage,
        if (discardReason != null) 'discard_reason': discardReason,
        if (buildMs != null) 'build_ms': buildMs,
        if (dbDiffMs != null) 'db_diff_ms': dbDiffMs,
        if (signMs != null) 'sign_ms': signMs,
        if (injectMs != null) 'inject_ms': injectMs,
        if (batchFetchMs != null) 'batch_fetch_ms': batchFetchMs,
        if (hydrationVisibleMs != null)
          'hydration_visible_ms': hydrationVisibleMs,
        if (appState != null) 'app_state': appState,
        if (networkType != null) 'network_type': networkType,
        if (networkConnected != null) 'network_connected': networkConnected,
        if (platform != null) 'platform': platform,
        if (platformVersion != null) 'platform_version': platformVersion,
        if (appVersion != null) 'app_version': appVersion,
        if (appBuildNumber != null) 'app_build_number': appBuildNumber,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (wakelockHeld != null) 'wakelock_held': wakelockHeld,
        if (foregroundServiceRunning != null)
          'foreground_service_running': foregroundServiceRunning,
        if (alarmScheduledAtMs != null)
          'alarm_scheduled_at_ms': alarmScheduledAtMs,
        if (alarmFiredAtMs != null) 'alarm_fired_at_ms': alarmFiredAtMs,
        if (monitoringStartedAtMs != null)
          'monitoring_started_at_ms': monitoringStartedAtMs,
      };

  factory SlotOutcomeReport.fromJson(Map<String, dynamic> json) {
    final globalSlot = (json['global_slot'] as num).toInt();
    final capturedAtMs = (json['captured_at_ms'] as num).toInt();
    return SlotOutcomeReport(
      id: (json['id'] as String?) ?? buildId(globalSlot, capturedAtMs),
      capturedAtMs: capturedAtMs,
      globalSlot: globalSlot,
      epoch: (json['epoch'] as num?)?.toInt(),
      slotInEpoch: (json['slot_in_epoch'] as num?)?.toInt(),
      slotTimeMs: (json['slot_time_ms'] as num?)?.toInt(),
      chainId: json['chain_id'] as String?,
      walletAddress: json['wallet_address'] as String?,
      outcome: _SlotOutcomeKindWire.parse(json['outcome'] as String?),
      outcomeReason: json['outcome_reason'] as String?,
      blockHash: json['block_hash'] as String?,
      blockHeight: (json['block_height'] as num?)?.toInt(),
      canonical: json['canonical'] as bool?,
      producedAtMs: (json['produced_at_ms'] as num?)?.toInt(),
      flowOutcome: json['flow_outcome'] as String?,
      terminalStage: json['terminal_stage'] as String?,
      discardReason: json['discard_reason'] as String?,
      buildMs: (json['build_ms'] as num?)?.toInt(),
      dbDiffMs: (json['db_diff_ms'] as num?)?.toInt(),
      signMs: (json['sign_ms'] as num?)?.toInt(),
      injectMs: (json['inject_ms'] as num?)?.toInt(),
      batchFetchMs: (json['batch_fetch_ms'] as num?)?.toInt(),
      hydrationVisibleMs: (json['hydration_visible_ms'] as num?)?.toInt(),
      appState: json['app_state'] as String?,
      networkType: json['network_type'] as String?,
      networkConnected: json['network_connected'] as bool?,
      platform: json['platform'] as String?,
      platformVersion: json['platform_version'] as String?,
      appVersion: json['app_version'] as String?,
      appBuildNumber: json['app_build_number'] as String?,
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
      wakelockHeld: json['wakelock_held'] as bool?,
      foregroundServiceRunning: json['foreground_service_running'] as bool?,
      alarmScheduledAtMs: (json['alarm_scheduled_at_ms'] as num?)?.toInt(),
      alarmFiredAtMs: (json['alarm_fired_at_ms'] as num?)?.toInt(),
      monitoringStartedAtMs:
          (json['monitoring_started_at_ms'] as num?)?.toInt(),
    );
  }
}

/// Lightweight client-context snapshot returned by
/// `MetricsCollectorService.collectClientContextSnapshot()` so the recorder
/// can capture context without depending on the full metrics payload.
class ClientContextSnapshot {
  final String? appState;
  final String? networkType;
  final bool? networkConnected;
  final String? platform;
  final String? platformVersion;
  final String? appVersion;
  final String? appBuildNumber;
  final int? batteryLevel;
  final bool? wakelockHeld;
  final bool? foregroundServiceRunning;

  const ClientContextSnapshot({
    this.appState,
    this.networkType,
    this.networkConnected,
    this.platform,
    this.platformVersion,
    this.appVersion,
    this.appBuildNumber,
    this.batteryLevel,
    this.wakelockHeld,
    this.foregroundServiceRunning,
  });

  const ClientContextSnapshot.empty() : this();
}
