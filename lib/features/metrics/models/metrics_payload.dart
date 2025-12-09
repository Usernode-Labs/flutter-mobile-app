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

/// App-related metrics group
@freezed
class AppMetricsGroup with _$AppMetricsGroup {
  const factory AppMetricsGroup({
    required RuntimeMetrics runtime,
    PlatformMetrics? platform,
    DeviceMetrics? device,
    BatteryMetrics? battery,
    NetworkMetrics? network,
    PermissionsMetrics? permissions,
    ForegroundServiceMetrics? foregroundService, // Android only
  }) = _AppMetricsGroup;

  const AppMetricsGroup._();

  Map<String, dynamic> toJson() => {
        'runtime': runtime.toJson(),
        if (platform != null) 'platform': platform!.toJson(),
        if (device != null) 'device': device!.toJson(),
        if (battery != null) 'battery': battery!.toJson(),
        if (network != null) 'network': network!.toJson(),
        if (permissions != null) 'permissions': permissions!.toJson(),
        if (foregroundService != null)
          'foreground_service': foregroundService!.toJson(),
      };
}

/// Node-related metrics group
@freezed
class NodeMetricsGroup with _$NodeMetricsGroup {
  const factory NodeMetricsGroup({
    required IdentityMetrics identity,
    StatusMetrics? status,
    ConsensusMetrics? consensus,
    BlockchainMetrics? blockchain,
    WalletMetrics? wallet,
    List<PeerMetrics>? peers,
  }) = _NodeMetricsGroup;

  const NodeMetricsGroup._();

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        if (status != null) 'status': status!.toJson(),
        if (consensus != null) 'consensus': consensus!.toJson(),
        if (blockchain != null) 'blockchain': blockchain!.toJson(),
        if (wallet != null) 'wallet': wallet!.toJson(),
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
  }) = _IdentityMetrics;

  const IdentityMetrics._();

  Map<String, dynamic> toJson() => {
        if (peerId != null) 'peer_id': peerId,
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

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_manufacturer': deviceManufacturer,
        'device_model': deviceModel,
        'is_physical_device': isPhysicalDevice,
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

/// App permissions state
@freezed
class PermissionsMetrics with _$PermissionsMetrics {
  const factory PermissionsMetrics({
    required bool permissionExactAlarms,
    required bool permissionBatteryOptimizationExempt,
    required bool exactAlarmsPermission,
    required String notificationPermission,
  }) = _PermissionsMetrics;

  const PermissionsMetrics._();

  Map<String, dynamic> toJson() => {
        'permission_exact_alarms': permissionExactAlarms,
        'permission_battery_optimization_exempt':
            permissionBatteryOptimizationExempt,
        'exact_alarms_permission': exactAlarmsPermission,
        'notification_permission': notificationPermission,
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

/// Node status metrics
@freezed
class StatusMetrics with _$StatusMetrics {
  const factory StatusMetrics({
    required bool nodeRunning,
    required String nodeState,
    String? nodeSyncStatus,
    int? nodeBestTipSlot,
    String? nodeBestTipHash,
    required int nodeConnectedPeers,
  }) = _StatusMetrics;

  const StatusMetrics._();

  Map<String, dynamic> toJson() => {
        'node_running': nodeRunning,
        'node_state': nodeState,
        if (nodeSyncStatus != null) 'node_sync_status': nodeSyncStatus,
        if (nodeBestTipSlot != null) 'node_best_tip_slot': nodeBestTipSlot,
        if (nodeBestTipHash != null) 'node_best_tip_hash': nodeBestTipHash,
        'node_connected_peers': nodeConnectedPeers,
      };
}

/// Consensus and block production metrics
@freezed
class ConsensusMetrics with _$ConsensusMetrics {
  const factory ConsensusMetrics({
    int? currentEpoch,
    int? currentGlobalSlot,
    int? currentEpochWonSlots,
    int? currentEpochProduced,
    int? currentEpochFailed,
    int? totalWonSlots,
    int? totalBlocksProduced,
    int? totalBlocksFailed,
    int? evaluatedCurrentEpoch,
    String? currentEpochVrfEvaluationStatus,
    String? nextEpochVrfEvaluationStatus,
    double? bpSuccessRate,
  }) = _ConsensusMetrics;

  const ConsensusMetrics._();

  Map<String, dynamic> toJson() => {
        if (currentEpoch != null) 'current_epoch': currentEpoch,
        if (currentGlobalSlot != null) 'current_global_slot': currentGlobalSlot,
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
        if (evaluatedCurrentEpoch != null)
          'evaluated_current_epoch': evaluatedCurrentEpoch,
        if (currentEpochVrfEvaluationStatus != null)
          'current_epoch_vrf_evaluation_status':
              currentEpochVrfEvaluationStatus,
        if (nextEpochVrfEvaluationStatus != null)
          'next_epoch_vrf_evaluation_status': nextEpochVrfEvaluationStatus,
        if (bpSuccessRate != null) 'bp_success_rate': bpSuccessRate,
      };
}

/// Blockchain state
@freezed
class BlockchainMetrics with _$BlockchainMetrics {
  const factory BlockchainMetrics({
    int? blockchainHeight,
    String? blockchainLatestBlockHash,
    int? blockchainLatestBlockSlot,
    String? blockchainLatestBlockTimestamp,
  }) = _BlockchainMetrics;

  const BlockchainMetrics._();

  Map<String, dynamic> toJson() => {
        if (blockchainHeight != null) 'blockchain_height': blockchainHeight,
        if (blockchainLatestBlockHash != null)
          'blockchain_latest_block_hash': blockchainLatestBlockHash,
        if (blockchainLatestBlockSlot != null)
          'blockchain_latest_block_slot': blockchainLatestBlockSlot,
        if (blockchainLatestBlockTimestamp != null)
          'blockchain_latest_block_timestamp': blockchainLatestBlockTimestamp,
      };
}

/// Wallet metrics
@freezed
class WalletMetrics with _$WalletMetrics {
  const factory WalletMetrics({
    BigInt? walletBalance,
    String? walletAddress,
  }) = _WalletMetrics;

  const WalletMetrics._();

  Map<String, dynamic> toJson() => {
        if (walletBalance != null) 'wallet_balance': walletBalance!.toInt(),
        if (walletAddress != null) 'wallet_address': walletAddress,
      };
}

/// Peer information
@freezed
class PeerMetrics with _$PeerMetrics {
  const factory PeerMetrics({
    required String peerId,
    String? address,
    String? bestTip,
    int? bestTipHeight,
    int? bestTipGlobalSlot,
    int? bestTipTimestamp,
    required String connectionStatus,
    String? connectingDetails,
    required bool incoming,
    required int time,
  }) = _PeerMetrics;

  const PeerMetrics._();

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        if (address != null) 'address': address,
        if (bestTip != null) 'best_tip': bestTip,
        if (bestTipHeight != null) 'best_tip_height': bestTipHeight,
        if (bestTipGlobalSlot != null)
          'best_tip_global_slot': bestTipGlobalSlot,
        if (bestTipTimestamp != null) 'best_tip_timestamp': bestTipTimestamp,
        'connection_status': connectionStatus,
        if (connectingDetails != null) 'connecting_details': connectingDetails,
        'incoming': incoming,
        'time': time,
      };
}
