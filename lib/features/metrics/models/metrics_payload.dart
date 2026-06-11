import 'package:freezed_annotation/freezed_annotation.dart';

part 'metrics_payload.freezed.dart';

/// Main metrics payload sent to the centralized API
@freezed
class MetricsPayload with _$MetricsPayload {
  const factory MetricsPayload({
    required EventMetrics event,
    required AppMetricsGroup app,
    required NodeMetricsGroup node,
  }) = _MetricsPayload;

  const MetricsPayload._();

  Map<String, dynamic> toJson() => {
        'event': event.toJson(),
        'app': app.toJson(),
        'node': node.toJson(),
      };
}

/// App-related metrics group.
///
/// Only [device] (its `device_id`) is sent to the metrics API. Runtime,
/// platform, battery, network, permissions and foreground-service data are
/// intentionally omitted from this payload — those models still exist and are
/// collected for the observability snapshots and slot-outcome reports.
@freezed
class AppMetricsGroup with _$AppMetricsGroup {
  const factory AppMetricsGroup({
    DeviceMetrics? device,
  }) = _AppMetricsGroup;

  const AppMetricsGroup._();

  Map<String, dynamic> toJson() => {
        if (device != null) 'device': device!.toJson(),
      };
}

/// Node-related metrics group
@freezed
class NodeMetricsGroup with _$NodeMetricsGroup {
  const factory NodeMetricsGroup({
    required IdentityMetrics identity,
    ConsensusMetrics? consensus,
    List<PeerMetrics>? peers,
  }) = _NodeMetricsGroup;

  const NodeMetricsGroup._();

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        if (consensus != null) 'consensus': consensus!.toJson(),
        if (peers != null) 'peers': peers!.map((p) => p.toJson()).toList(),
      };
}

/// Event metadata
@freezed
class EventMetrics with _$EventMetrics {
  const factory EventMetrics({
    required String eventType,
    required String timestamp,
    Map<String, dynamic>? eventData,
  }) = _EventMetrics;

  const EventMetrics._();

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'timestamp': timestamp,
        if (eventData != null) 'event_data': eventData,
      };
}

/// Node identity
@freezed
class IdentityMetrics with _$IdentityMetrics {
  const factory IdentityMetrics({
    String? peerId,
    String? chainId,
    int? participantId,
  }) = _IdentityMetrics;

  const IdentityMetrics._();

  Map<String, dynamic> toJson() => {
        if (peerId != null) 'peer_id': peerId,
        if (chainId != null) 'chain_id': chainId,
        if (participantId != null) 'participant_id': participantId,
      };
}

/// App runtime and performance metrics
@freezed
class RuntimeMetrics with _$RuntimeMetrics {
  const factory RuntimeMetrics({
    required String appState,
    required String appVersion,
    required String appBuildNumber,
    required int appUptimeMs,
    required bool keepAliveModeActive,
    required bool notificationsEnabled,
  }) = _RuntimeMetrics;

  const RuntimeMetrics._();

  Map<String, dynamic> toJson() => {
        'app_state': appState,
        'app_version': appVersion,
        'app_build_number': appBuildNumber,
        'app_uptime_ms': appUptimeMs,
        'keep_alive_mode_active': keepAliveModeActive,
        'notifications_enabled': notificationsEnabled,
      };
}

/// Platform information
@freezed
class PlatformMetrics with _$PlatformMetrics {
  const factory PlatformMetrics({
    required String platform,
    required String platformVersion,
    String? systemArchitecture,
  }) = _PlatformMetrics;

  const PlatformMetrics._();

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'platform_version': platformVersion,
        if (systemArchitecture != null)
          'system_architecture': systemArchitecture,
      };
}

/// Device information
@freezed
class DeviceMetrics with _$DeviceMetrics {
  const factory DeviceMetrics({
    required String deviceId,
    required String deviceManufacturer,
    required String deviceModel,
    required bool isPhysicalDevice,
  }) = _DeviceMetrics;

  const DeviceMetrics._();

  // Only device_id is sent to the metrics API. Manufacturer/model/physical-ness
  // are still carried on the model for the observability snapshot
  // (_staticDeviceJson), but intentionally excluded from this payload.
  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
      };
}

/// Battery state
@freezed
class BatteryMetrics with _$BatteryMetrics {
  const factory BatteryMetrics({
    int? batteryLevel,
    required String batteryState,
    required bool batteryOptimizationDisabled,
    required bool powerSaveMode,
    required bool lowPowerMode,
  }) = _BatteryMetrics;

  const BatteryMetrics._();

  Map<String, dynamic> toJson() => {
        if (batteryLevel != null) 'battery_level': batteryLevel,
        'battery_state': batteryState,
        'battery_optimization_disabled': batteryOptimizationDisabled,
        'power_save_mode': powerSaveMode,
        'low_power_mode': lowPowerMode,
      };
}

/// Network state
@freezed
class NetworkMetrics with _$NetworkMetrics {
  const factory NetworkMetrics({
    required String networkType,
    required bool networkConnected,
  }) = _NetworkMetrics;

  const NetworkMetrics._();

  Map<String, dynamic> toJson() => {
        'network_type': networkType,
        'network_connected': networkConnected,
      };
}

/// Foreground service metrics (Android only)
@freezed
class ForegroundServiceMetrics with _$ForegroundServiceMetrics {
  const factory ForegroundServiceMetrics({
    required bool foregroundServiceRunning,
    required bool wakelockHeld,
  }) = _ForegroundServiceMetrics;

  const ForegroundServiceMetrics._();

  Map<String, dynamic> toJson() => {
        'foreground_service_running': foregroundServiceRunning,
        'wakelock_held': wakelockHeld,
      };
}

/// Consensus and block production metrics
@freezed
class ConsensusMetrics with _$ConsensusMetrics {
  const factory ConsensusMetrics({
    int? currentEpoch,
    int? currentEpochWonSlots,
    int? currentEpochProduced,
    int? currentEpochFailed,
    int? totalWonSlots,
    int? totalBlocksProduced,
    int? totalBlocksFailed,
    double? bpSuccessRate,
  }) = _ConsensusMetrics;

  const ConsensusMetrics._();

  Map<String, dynamic> toJson() => {
        if (currentEpoch != null) 'current_epoch': currentEpoch,
        if (currentEpochWonSlots != null)
          'current_epoch_won_slots': currentEpochWonSlots,
        if (currentEpochProduced != null)
          'current_epoch_produced': currentEpochProduced,
        if (currentEpochFailed != null)
          'current_epoch_failed': currentEpochFailed,
        if (totalWonSlots != null) 'total_won_slots': totalWonSlots,
        if (totalBlocksProduced != null)
          'total_blocks_produced': totalBlocksProduced,
        if (totalBlocksFailed != null) 'total_blocks_failed': totalBlocksFailed,
        if (bpSuccessRate != null) 'bp_success_rate': bpSuccessRate,
      };
}

/// Peer information
@freezed
class PeerMetrics with _$PeerMetrics {
  const factory PeerMetrics({
    required String peerId,
    String? address,
    String? bestTip,
    int? bestTipGlobalSlot,
    required String connectionStatus,
    required bool incoming,
  }) = _PeerMetrics;

  const PeerMetrics._();

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        if (address != null) 'address': address,
        if (bestTip != null) 'best_tip': bestTip,
        if (bestTipGlobalSlot != null)
          'best_tip_global_slot': bestTipGlobalSlot,
        'connection_status': connectionStatus,
        'incoming': incoming,
      };
}
