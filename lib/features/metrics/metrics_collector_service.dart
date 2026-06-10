import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/features/metrics/models/metrics_payload.dart';
import 'package:crypto_mobile_app/features/metrics/models/slot_outcome_report.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
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

/// Service responsible for collecting all metrics from various sources
///
/// Supports both periodic health checks and event-driven metric collection.
class MetricsCollectorService implements MobileContextSnapshotCollector {
  MetricsCollectorService._();
  static final MetricsCollectorService instance = MetricsCollectorService._();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Provider container for accessing node status providers
  static ProviderContainer? _container;

  /// Debug: check if container is set
  bool get hasContainer => _container != null;

  /// Track app startup time
  DateTime? _appStartTime;

  /// Track app lifecycle state
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // ===== CACHE VARIABLES (reset on app restart) =====

  // Immutable data - cache indefinitely
  PackageInfo? _cachedPackageInfo;
  BaseDeviceInfo? _cachedDeviceInfo;
  String? _cachedPeerId;

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

  /// Clears cached state so a subsequent bootstrap starts cleanly.
  void reset() {
    _container = null;
    _appStartTime = null;
    _appLifecycleState = AppLifecycleState.resumed;
    _cachedPackageInfo = null;
    _cachedDeviceInfo = null;
    _cachedPeerId = null;
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

  /// Capture a focused snapshot of client-side context for slot outcome
  /// reports.
  ///
  /// Unlike [collectMetrics], this skips node status / provider reads and
  /// only collects the fields a [SlotOutcomeReport] needs (app state,
  /// network, platform, app version, battery, wakelock / FG status). Cheap
  /// enough to call inline at slot terminal time without slowing down
  /// monitoring teardown. Any individual field failure degrades to `null`
  /// rather than throwing, so the recorder always gets *some* context.
  Future<ClientContextSnapshot> collectClientContextSnapshot() async {
    Future<T?> safe<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (e) {
        _log.debug('client-context field failed: $e');
        return null;
      }
    }

    final results = await Future.wait([
      safe(_collectRuntimeMetrics),
      safe(_collectPlatformMetrics),
      safe(_collectBatteryMetrics),
      safe(_collectNetworkMetrics),
      Platform.isAndroid
          ? safe(_collectForegroundServiceMetrics)
          : Future<ForegroundServiceMetrics?>.value(null),
    ]);

    final runtime = results[0] as RuntimeMetrics?;
    final platform = results[1] as PlatformMetrics?;
    final battery = results[2] as BatteryMetrics?;
    final network = results[3] as NetworkMetrics?;
    final fg = results[4] as ForegroundServiceMetrics?;

    return ClientContextSnapshot(
      appState: runtime?.appState,
      networkType: network?.networkType,
      networkConnected: network?.networkConnected,
      platform: platform?.platform,
      platformVersion: platform?.platformVersion,
      appVersion: runtime?.appVersion,
      appBuildNumber: runtime?.appBuildNumber,
      batteryLevel: battery?.batteryLevel,
      wakelockHeld: fg?.wakelockHeld ?? runtime?.keepAliveModeActive,
      foregroundServiceRunning: fg?.foregroundServiceRunning,
    );
  }

  /// Collect metrics for a specific block production event
  ///
  /// Always collects full metrics for all event types, providing complete
  /// visibility into app health, node performance, and block production.
  Future<MetricsPayload> collectMetricsForEvent(
    BlockProductionEvent event,
  ) async {
    _log.debug('Collecting full metrics for event: ${event.eventType}');

    return await collectMetrics(
      eventType: event.eventType,
      eventData: event.toJson(),
    );
  }

  /// Collect all metrics and return a complete payload
  ///
  /// Always collects full metrics for comprehensive system state visibility.
  Future<MetricsPayload> collectMetrics({
    String eventType = 'health_check',
    Map<String, dynamic>? eventData,
  }) async {
    // For full collection, fetch node status ONCE from provider to avoid expensive FFI calls
    NodeStatusState? rawStatus;
    if (_container != null && RustBackendService.instance.isRunning) {
      try {
        final rawStatusAsync = _container!.read(nodeStatusProvider);
        rawStatus = rawStatusAsync.valueOrNull;
        _log.debug(
            'nodeStatusProvider: isLoading=${rawStatusAsync.isLoading}, hasValue=${rawStatusAsync.hasValue}, hasError=${rawStatusAsync.hasError}');
      } catch (e) {
        _log.warn('Failed to read nodeStatusProvider: $e');
      }
    }

    // The metrics-API payload carries only event metadata, the hashed
    // device id, node identity, consensus and peers. App runtime/platform/
    // battery/network/permissions and node status/blockchain/wallet are
    // intentionally not reported here (see metrics_payload.dart).
    final event = await _collectEventMetrics(eventType, eventData);
    final device = await _collectDeviceMetrics();
    final identity = await _collectIdentityMetrics();
    final consensus = await _collectConsensusMetrics(rawStatus: rawStatus);
    final peers = await _collectPeersMetrics(rawStatus: rawStatus);

    final app = AppMetricsGroup(device: device);

    final node = NodeMetricsGroup(
      identity: identity,
      consensus: consensus,
      peers: peers,
    );

    return MetricsPayload(
      event: event,
      app: app,
      node: node,
    );
  }

  /// Collect event metadata
  Future<EventMetrics> _collectEventMetrics(
    String eventType,
    Map<String, dynamic>? eventData,
  ) async {
    return EventMetrics(
      eventType: eventType,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      eventData: eventData,
    );
  }

  /// Collect node identity
  Future<IdentityMetrics> _collectIdentityMetrics() async {
    // Get peer ID from backend service - CACHED (static per session)
    _cachedPeerId ??= RustBackendService.instance.getPeerId();
    final peerId = _cachedPeerId;

    // Read chain_id directly from the Rust node, *not* from the Riverpod
    // cache. `nodeStatusProvider` is a one-shot AsyncNotifier — it builds
    // exactly once per app session and never refreshes itself. At cold
    // boot the first read often happens before the embedded node has
    // reported its chain hash, so the provider caches `null` for the rest
    // of the session and every consumer that reads through it gets a
    // stale value. The metrics POST tick is the single best moment to
    // ask for fresh state, and a direct FFI hop here is cheap enough at
    // the once-per-25-60s cadence we run at.
    //
    // We intentionally do NOT fall back to the selected-network name
    // (e.g. 'testnet'). A null chain_id is a real signal that the node
    // wasn't reachable at this instant; stamping a fake string instead
    // poisons the analytics join against `vrf_slots` server-side and
    // makes legitimate reports invisible. Leaving chain_id null keeps
    // those reports debuggable on the server.
    String? chainId;
    try {
      final node = await RustBackendService.instance.getStatusNode();
      chainId = node?.chainId.toString();
      _log.debug(
          'Got chain_id from RustBackendService.getStatusNode(): $chainId');
    } catch (e) {
      _log.debug('Failed to get chain_id from getStatusNode(): $e');
    }

    return IdentityMetrics(
      peerId: peerId,
      chainId: chainId,
      participantId: await _loadParticipantId(),
    );
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

  /// Collect consensus and block production metrics
  ///
  /// If [rawStatus] is provided, it will be used instead of fetching from backend.
  /// This avoids expensive FFI calls when status is already available.
  Future<ConsensusMetrics> _collectConsensusMetrics(
      {NodeStatusState? rawStatus}) async {
    int? currentEpoch;
    int? currentEpochWonSlots;
    int? currentEpochProduced;
    int? currentEpochFailed;
    double? bpSuccessRate;

    if (RustBackendService.instance.isRunning) {
      try {
        // Use provided rawStatus
        if (rawStatus != null) {
          final bestTip = rawStatus.networkBest ?? rawStatus.localBest;
          currentEpoch = bestTip?.epoch;

          // Won slots come from the VRF evaluator details.
          final vrfEvaluator = rawStatus.vrfEvaluator;
          if (vrfEvaluator != null) {
            currentEpochWonSlots =
                vrfEvaluator.details?.wonSlotsCurrentEpoch.toInt();
          }
        }

        // Get produced blocks data from producedBlocksSummaryProvider (same as Produced Blocks screen)
        if (_container != null) {
          try {
            final summaryAsync =
                _container!.read(producedBlocksSummaryProvider);
            final summary = summaryAsync.valueOrNull;
            _log.debug(
                'producedBlocksSummaryProvider: hasValue=${summaryAsync.hasValue}, currentEpoch=${summary?.currentEpoch}');

            if (summary != null && summary.epochScores.isNotEmpty) {
              final summaryCurrentEpoch = summary.currentEpoch;
              if (summaryCurrentEpoch >= 0 &&
                  summaryCurrentEpoch < summary.epochScores.length) {
                final epochScore = summary.epochScores[summaryCurrentEpoch];
                currentEpochWonSlots ??= epochScore.won;
                currentEpochProduced = epochScore.produced;
                currentEpochFailed = epochScore.missed;

                // Calculate bp_success_rate (0-100)
                final rate = epochScore.evaluatedPercent *
                    epochScore.producedOfEvaluatedPercent *
                    100;
                if (!rate.isNaN && !rate.isInfinite) {
                  bpSuccessRate = rate.clamp(0.0, 100.0);
                }
              }
            }
          } catch (e) {
            _log.warn('Failed to read producedBlocksSummaryProvider: $e');
          }
        }
      } catch (e) {
        _log.debug('Error collecting consensus metrics: $e');
      }
    }

    return ConsensusMetrics(
      currentEpoch: currentEpoch,
      currentEpochWonSlots: currentEpochWonSlots,
      currentEpochProduced: currentEpochProduced,
      currentEpochFailed: currentEpochFailed,
      bpSuccessRate: bpSuccessRate,
      // Total metrics not implemented yet
      totalWonSlots: null,
      totalBlocksProduced: null,
      totalBlocksFailed: null,
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

  /// Collect peers metrics
  ///
  /// If [rawStatus] is provided, it will be used instead of fetching from backend.
  /// This avoids expensive FFI calls when status is already available.
  Future<List<PeerMetrics>> _collectPeersMetrics(
      {NodeStatusState? rawStatus}) async {
    if (!RustBackendService.instance.isRunning) {
      return [];
    }

    try {
      // Use provided rawStatus
      if (rawStatus == null) return [];

      return rawStatus.peers.map((peer) {
        return PeerMetrics(
          peerId: peer.peerId.toString(),
          address: peer.address,
          bestTip: null, // Not available in current RpcPeerInfo
          bestTipGlobalSlot: peer.bestTipGlobalSlot,
          connectionStatus: peer.connectionStatus.toString().split('.').last,
          incoming: peer.incoming,
        );
      }).toList();
    } catch (e) {
      _log.debug('Error collecting peers metrics: $e');
      return [];
    }
  }
}
