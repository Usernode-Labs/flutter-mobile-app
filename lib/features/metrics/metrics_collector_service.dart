import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/features/metrics/models/mobile_context_metrics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final _log = LoggingService.instance.withTag('usernode/MetricsCollector');

/// Hashes a device ID using SHA-256 (64 chars) for privacy
/// Returns 'unknown' as-is when device ID cannot be determined
String _hashDeviceId(String deviceId) {
  if (deviceId == 'unknown') {
    return 'unknown';
  }
  final bytes = utf8.encode(deviceId);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// Collects mobile-context snapshots (identity, runtime, platform, device,
/// battery, network, foreground-service) for the observability hub.
///
/// Implements [MobileContextSnapshotCollector], which
/// [ObservabilityReportingService] uses to enrich its node events.
class MetricsCollectorService implements MobileContextSnapshotCollector {
  MetricsCollectorService._();
  static final MetricsCollectorService instance = MetricsCollectorService._();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Provider container for reading the participant id.
  static ProviderContainer? _container;

  /// Track app startup time
  DateTime? _appStartTime;

  /// Track app lifecycle state
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // ===== CACHE VARIABLES (reset on app restart) =====

  // Immutable data - cache indefinitely
  PackageInfo? _cachedPackageInfo;
  BaseDeviceInfo? _cachedDeviceInfo;

  // Semi-static data with TTL
  DateTime? _batteryOptimizationCacheTime;
  bool? _cachedBatteryOptimization;
  final Duration _batteryOptimizationTTL = const Duration(minutes: 5);

  /// Helper method to check if cache should be refreshed
  bool _shouldRefreshCache(DateTime? cacheTime, Duration ttl) {
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > ttl;
  }

  /// Initialize the service (call at app startup)
  void initialize(ProviderContainer container) {
    _container = container;
    _appStartTime = DateTime.now();
    // Initialize to actual current state if available
    final currentState = WidgetsBinding.instance.lifecycleState;
    if (currentState != null) {
      _appLifecycleState = currentState;
    }
  }

  /// Releases the disposed session host without resetting process metrics.
  void detachSessionHost() {
    _container = null;
  }

  /// Clears cached state so a subsequent bootstrap starts cleanly.
  void reset() {
    _container = null;
    _appStartTime = null;
    _appLifecycleState = AppLifecycleState.resumed;
    _cachedPackageInfo = null;
    _cachedDeviceInfo = null;
    _batteryOptimizationCacheTime = null;
    _cachedBatteryOptimization = null;
  }

  /// Update the current app lifecycle state
  void updateAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  /// Collect per-run static mobile context used by observability.
  ///
  /// `device_id_hash` is the existing hashed identifier from [_collectDeviceMetrics],
  /// not the raw platform device id.
  @override
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    final results = await Future.wait<Object?>([
      _safeMobileContextField('identity', _collectMobileContextIdentity),
      _safeMobileContextField('runtime', _collectRuntimeMetrics),
      _safeMobileContextField('platform', _collectPlatformMetrics),
      _safeMobileContextField('device', _collectDeviceMetrics),
    ]);

    final identity = results[0] as Map<String, dynamic>?;
    final runtime = results[1] as RuntimeMetrics?;
    final platform = results[2] as PlatformMetrics?;
    final device = results[3] as DeviceMetrics?;

    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      if (identity != null) 'identity': identity,
      if (runtime != null) 'runtime': _staticRuntimeJson(runtime),
      if (platform != null) 'platform': platform.toJson(),
      if (device != null) 'device': _staticDeviceJson(device),
    };
  }

  /// Collect runtime/app-state mobile context used by observability.
  @override
  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    final results = await Future.wait<Object?>([
      _safeMobileContextField('identity', _collectMobileContextIdentity),
      _safeMobileContextField('runtime', _collectRuntimeMetrics),
    ]);

    final identity = results[0] as Map<String, dynamic>?;
    final runtime = results[1] as RuntimeMetrics?;

    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      if (identity != null) 'identity': identity,
      if (runtime != null) 'runtime': _dynamicRuntimeJson(runtime),
    };
  }

  /// Collect power, network, and foreground-service mobile context.
  @override
  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async {
    final results = await Future.wait<Object?>([
      _safeMobileContextField('identity', _collectMobileContextIdentity),
      _safeMobileContextField('battery', _collectBatteryMetrics),
      _safeMobileContextField('network', _collectNetworkMetrics),
      Platform.isAndroid
          ? _safeMobileContextField(
              'foreground_service',
              _collectForegroundServiceMetrics,
            )
          : Future<Object?>.value(null),
    ]);

    final identity = results[0] as Map<String, dynamic>?;
    final battery = results[1] as BatteryMetrics?;
    final network = results[2] as NetworkMetrics?;
    final foregroundService = results[3] as ForegroundServiceMetrics?;

    return {
      if (eventData != null && eventData.isNotEmpty) 'event_data': eventData,
      if (identity != null) 'identity': identity,
      if (battery != null) 'battery': battery.toJson(),
      if (network != null) 'network': network.toJson(),
      if (foregroundService != null)
        'foreground_service': foregroundService.toJson(),
    };
  }

  Future<Object?> _safeMobileContextField(
    String label,
    Future<Object?> Function() collect,
  ) async {
    try {
      return await collect();
    } catch (e) {
      _log.debug('mobile-context-snapshot field failed ($label): $e');
      return null;
    }
  }

  Map<String, dynamic> _staticRuntimeJson(RuntimeMetrics runtime) => {
        'app_version': runtime.appVersion,
        'app_build_number': runtime.appBuildNumber,
      };

  Map<String, dynamic> _dynamicRuntimeJson(RuntimeMetrics runtime) => {
        'app_state': runtime.appState,
        'app_uptime_ms': runtime.appUptimeMs,
        'keep_alive_mode_active': runtime.keepAliveModeActive,
        'notifications_enabled': runtime.notificationsEnabled,
      };

  Map<String, dynamic> _staticDeviceJson(DeviceMetrics device) => {
        'device_id_hash': device.deviceId,
        'device_manufacturer': device.deviceManufacturer,
        'device_model': device.deviceModel,
        'is_physical_device': device.isPhysicalDevice,
      };

  Future<Map<String, dynamic>?> _collectMobileContextIdentity() async {
    final participantId = await _loadParticipantId();
    if (participantId == null) {
      return null;
    }

    return {'participant_id': participantId};
  }

  Future<int?> _loadParticipantId() async {
    if (_container != null) {
      try {
        final participantId =
            await _container!.read(participantIdProvider.future);
        if (participantId != null) {
          return participantId;
        }
      } catch (e) {
        _log.debug('Failed to get participant_id from provider: $e');
      }
    }

    try {
      return await loadParticipantId();
    } catch (e) {
      _log.debug('Failed to load participant_id from storage: $e');
      return null;
    }
  }

  /// Collect app runtime and performance metrics
  Future<RuntimeMetrics> _collectRuntimeMetrics() async {
    // Get package info (app version, build number) - CACHED (immutable)
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    final packageInfo = _cachedPackageInfo!;

    // Calculate uptime
    final uptime = _appStartTime != null
        ? DateTime.now().difference(_appStartTime!).inMilliseconds
        : 0;

    // Check if wakelock is held
    //
    // On Android, `wakelock_plus` requires a foreground Activity and will throw when the UI
    // is destroyed (e.g. during background execution / "Don't keep activities").
    // We instead track the native PARTIAL_WAKE_LOCK held by our foreground service.
    final wakelockActive = Platform.isAndroid
        ? await PlatformAlarmService.instance.isWakelockHeld()
        : await WakelockPlus.enabled;

    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    final notificationsEnabled = notificationStatus.isGranted;

    // Get ACTUAL current lifecycle state, not cached state
    // This ensures we capture the true state even for background alarm wake-ups
    final currentState = WidgetsBinding.instance.lifecycleState;
    final actualAppState = currentState ?? _appLifecycleState;

    // Map lifecycle state to string
    String appState;
    switch (actualAppState) {
      case AppLifecycleState.resumed:
        appState = 'foreground';
        break;
      case AppLifecycleState.inactive:
        appState = 'inactive';
        break;
      case AppLifecycleState.paused:
        appState = 'background';
        break;
      case AppLifecycleState.detached:
        appState = 'detached';
        break;
      case AppLifecycleState.hidden:
        appState = 'hidden';
        break;
    }

    return RuntimeMetrics(
      appState: appState,
      appVersion: packageInfo.version,
      appBuildNumber: packageInfo.buildNumber,
      appUptimeMs: uptime,
      keepAliveModeActive: wakelockActive,
      notificationsEnabled: notificationsEnabled,
    );
  }

  /// Collect platform information
  Future<PlatformMetrics> _collectPlatformMetrics() async {
    String? architecture;
    String platformVersion = 'unknown';

    // Get device info - CACHED (immutable)
    if (Platform.isAndroid) {
      _cachedDeviceInfo ??= await _deviceInfo.androidInfo;
      final androidInfo = _cachedDeviceInfo as AndroidDeviceInfo;
      platformVersion = androidInfo.version.release;
      architecture = androidInfo.supportedAbis.isNotEmpty
          ? androidInfo.supportedAbis.first
          : null;
    } else if (Platform.isIOS) {
      _cachedDeviceInfo ??= await _deviceInfo.iosInfo;
      final iosInfo = _cachedDeviceInfo as IosDeviceInfo;
      platformVersion = iosInfo.systemVersion;
      architecture = iosInfo.utsname.machine;
    }

    return PlatformMetrics(
      platform: Platform.operatingSystem,
      platformVersion: platformVersion,
      systemArchitecture: architecture,
    );
  }

  /// Collect device information
  Future<DeviceMetrics> _collectDeviceMetrics() async {
    String deviceId = 'unknown';
    String manufacturer = 'unknown';
    String model = 'unknown';
    bool isPhysical = true;

    // Reuse cached device info - CACHED (immutable)
    if (Platform.isAndroid) {
      _cachedDeviceInfo ??= await _deviceInfo.androidInfo;
      final androidInfo = _cachedDeviceInfo as AndroidDeviceInfo;
      deviceId = androidInfo.id;
      manufacturer = androidInfo.manufacturer;
      model = androidInfo.model;
      isPhysical = androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      _cachedDeviceInfo ??= await _deviceInfo.iosInfo;
      final iosInfo = _cachedDeviceInfo as IosDeviceInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
      manufacturer = 'Apple';
      model = iosInfo.model;
      isPhysical = iosInfo.isPhysicalDevice;
    }

    return DeviceMetrics(
      deviceId: _hashDeviceId(deviceId),
      deviceManufacturer: manufacturer,
      deviceModel: model,
      isPhysicalDevice: isPhysical,
    );
  }

  /// Collect battery state
  Future<BatteryMetrics> _collectBatteryMetrics() async {
    // Default values for when battery info is unavailable
    int? batteryLevel;
    BatteryState batteryState = BatteryState.unknown;

    try {
      _log.trace('Attempting to get battery level...');
      batteryLevel = await _battery.batteryLevel;
      _log.trace('Battery level retrieved: $batteryLevel%');
      batteryState = await _battery.batteryState;
      _log.trace('Battery state: $batteryState');
    } catch (e, stackTrace) {
      // Battery info not available on this platform (desktop/simulator)
      _log.warn('Could not get battery level: $e');
      _log.trace('Battery error stacktrace: $stackTrace');
    }

    // Check if battery optimization is disabled (Android) - CACHED with 5min TTL
    bool batteryOptimizationDisabled = false;
    if (Platform.isAndroid) {
      try {
        if (_shouldRefreshCache(
            _batteryOptimizationCacheTime, _batteryOptimizationTTL)) {
          _cachedBatteryOptimization = await PlatformAlarmService.instance
              .isBatteryOptimizationDisabled();
          _batteryOptimizationCacheTime = DateTime.now();
        }
        batteryOptimizationDisabled = _cachedBatteryOptimization ?? false;
      } catch (e) {
        _log.debug('Could not check battery optimization status: $e');
      }
    }

    // For power save mode, we'll use battery state as proxy
    // Only calculate power modes when battery info is available
    final powerSaveMode = batteryLevel == null
        ? false
        : (batteryState == BatteryState.charging ? false : batteryLevel < 20);
    final lowPowerMode = batteryLevel == null ? false : batteryLevel < 20;

    return BatteryMetrics(
      batteryLevel: batteryLevel,
      batteryState: batteryState.toString().split('.').last,
      batteryOptimizationDisabled: batteryOptimizationDisabled,
      powerSaveMode: powerSaveMode,
      lowPowerMode: lowPowerMode,
    );
  }

  /// Collect network state
  Future<NetworkMetrics> _collectNetworkMetrics() async {
    final connectivityResult = await _connectivity.checkConnectivity();

    // Map connectivity result to network type
    String networkType = 'none';
    bool networkConnected = false;

    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      networkType = 'wifi';
      networkConnected = true;
    } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
      networkType = 'cellular';
      networkConnected = true;
    } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
      networkType = 'ethernet';
      networkConnected = true;
    }

    return NetworkMetrics(
      networkType: networkType,
      networkConnected: networkConnected,
    );
  }

  /// Collect foreground service metrics (Android only)
  Future<ForegroundServiceMetrics?> _collectForegroundServiceMetrics() async {
    if (!Platform.isAndroid) return null;

    // Get actual state from platform channels
    final foregroundServiceRunning =
        await PlatformAlarmService.instance.isForegroundServiceRunning();
    final wakelockHeld = await PlatformAlarmService.instance.isWakelockHeld();

    return ForegroundServiceMetrics(
      foregroundServiceRunning: foregroundServiceRunning,
      wakelockHeld: wakelockHeld,
    );
  }
}
