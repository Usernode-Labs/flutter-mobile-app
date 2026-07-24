import 'package:freezed_annotation/freezed_annotation.dart';

part 'mobile_context_metrics.freezed.dart';

/// Mobile-context metric groups collected by [MetricsCollectorService] and
/// surfaced to the observability hub via its mobile-context snapshots. These
/// used to double as the topochain metrics payload; that reporting path has
/// been removed, so these types now serve observability only.

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
