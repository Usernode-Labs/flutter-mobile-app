import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/features/metrics/data/models/metrics_payload.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service responsible for collecting all metrics from various sources
///
/// Supports both periodic health checks and event-driven metric collection.
class MetricsCollectorService {
  MetricsCollectorService._();
  static final MetricsCollectorService instance = MetricsCollectorService._();

  final Logger _logger = Logger();
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Track app startup time
  DateTime? _appStartTime;

  /// Track app lifecycle state
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  /// Initialize the service (call at app startup)
  void initialize() {
    _appStartTime = DateTime.now();
  }

  /// Update the current app lifecycle state
  void updateAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  /// Collect metrics for a specific block production event
  ///
  /// This performs targeted metric collection based on event type:
  /// - Full: health_check, epoch_transition, app_resumed, app_suspended, android_boot_reschedule_completed
  /// - Lightweight: app_wake_up, android_alarm_fired, ios_notification_delivered, ios_bgtask_executed
  /// - Production: slot_monitoring_start, slot_produced, slot_failed, monitoring_poll, block_production_detected, node_start_*
  /// - Minimal: alarm_scheduled, alarm_cancelled, service/permission events
  Future<MetricsPayload> collectMetricsForEvent(
    BlockProductionEvent event, {
    double? walletBalance,
    String? walletAddress,
  }) async {
    _logger.d('Collecting metrics for event: ${event.eventType}');

    // Determine which metrics to collect based on event type
    final collectFull = _shouldCollectFull(event.eventType);
    final collectLightweight = _shouldCollectLightweight(event.eventType);
    final collectProduction = _shouldCollectProduction(event.eventType);
    final collectMinimal = _shouldCollectMinimal(event.eventType);

    _logger.d('Strategy - Full: $collectFull, Lightweight: $collectLightweight, Production: $collectProduction, Minimal: $collectMinimal');

    return await collectMetrics(
      eventType: event.eventType,
      eventData: event.toJson(),
      walletBalance: walletBalance,
      walletAddress: walletAddress,
      collectFull: collectFull,
      collectLightweight: collectLightweight,
      collectProduction: collectProduction,
      collectMinimal: collectMinimal,
    );
  }

  /// Determine if full metrics should be collected
  bool _shouldCollectFull(String eventType) {
    return eventType == 'health_check' ||
        eventType == 'epoch_transition' ||
        eventType == 'app_resumed' ||
        eventType == 'app_suspended' ||
        eventType == 'android_boot_reschedule_completed';
  }

  /// Determine if lightweight metrics should be collected
  bool _shouldCollectLightweight(String eventType) {
    return eventType == 'app_wake_up' ||
        eventType == 'android_alarm_fired' ||
        eventType == 'ios_notification_delivered' ||
        eventType == 'ios_bgtask_executed';
  }

  /// Determine if production-focused metrics should be collected
  bool _shouldCollectProduction(String eventType) {
    return eventType == 'slot_monitoring_start' ||
        eventType == 'slot_produced' ||
        eventType == 'slot_failed' ||
        eventType == 'monitoring_poll' ||
        eventType == 'block_production_detected' ||
        eventType == 'node_start_initiated' ||
        eventType == 'node_start_completed' ||
        eventType == 'node_start_failed';
  }

  /// Determine if minimal metrics should be collected
  bool _shouldCollectMinimal(String eventType) {
    return eventType == 'alarm_scheduled' ||
        eventType == 'alarm_cancelled' ||
        eventType == 'android_foreground_service_started' ||
        eventType == 'android_foreground_service_stopped' ||
        eventType == 'android_boot_reschedule_started' ||
        eventType == 'android_exact_alarm_permission_granted' ||
        eventType == 'android_exact_alarm_permission_denied' ||
        eventType == 'android_battery_optimization_disabled' ||
        eventType == 'ios_notification_scheduled' ||
        eventType == 'ios_notification_tapped' ||
        eventType == 'ios_bgtask_scheduled' ||
        eventType == 'ios_bgtask_expired' ||
        eventType == 'ios_notification_permission_granted' ||
        eventType == 'ios_notification_permission_denied';
  }

  /// Collect all metrics and return a complete payload
  Future<MetricsPayload> collectMetrics({
    String eventType = 'health_check',
    Map<String, dynamic>? eventData,
    double? walletBalance,
    String? walletAddress,
    bool collectFull = true,
    bool collectLightweight = false,
    bool collectProduction = false,
    bool collectMinimal = false,
  }) async {
    // For minimal collection (permission/scheduling events), only collect event + runtime
    if (collectMinimal) {
      _logger.d('Using minimal collection strategy');
      return await _collectMinimalMetrics(eventType, eventData);
    }

    // For lightweight collection (app_wake_up), only collect essential metrics
    if (collectLightweight) {
      _logger.d('Using lightweight collection strategy');
      return await _collectLightweightMetrics(eventType, eventData);
    }

    // For production events, collect production-focused metrics
    if (collectProduction) {
      _logger.d('Using production-focused collection strategy');
      return await _collectProductionFocusedMetrics(
        eventType,
        eventData,
        walletBalance,
        walletAddress,
      );
    }

    _logger.d('Using full collection strategy');

    // For full collection, collect everything
    // Collect all metrics in parallel for efficiency
    final results = await Future.wait([
      _collectEventMetrics(eventType, eventData),
      _collectRuntimeMetrics(),
      _collectPlatformMetrics(),
      _collectDeviceMetrics(),
      _collectBatteryMetrics(),
      _collectNetworkMetrics(),
      _collectPermissionsMetrics(),
      _collectStatusMetrics(),
      _collectBlockchainMetrics(),
    ]);

    final event = results[0] as EventMetrics;
    final runtime = results[1] as RuntimeMetrics;
    final platform = results[2] as PlatformMetrics;
    final device = results[3] as DeviceMetrics;
    final battery = results[4] as BatteryMetrics;
    final network = results[5] as NetworkMetrics;
    final permissions = results[6] as PermissionsMetrics;
    final status = results[7] as StatusMetrics;
    final blockchain = results[8] as BlockchainMetrics;

    // Collect additional metrics
    final identity = await _collectIdentityMetrics();
    final consensus = await _collectConsensusMetrics();
    final production = _collectProductionMetrics();
    final wallet = _collectWalletMetrics(walletBalance, walletAddress);
    final peers = await _collectPeersMetrics();
    final foregroundService =
        Platform.isAndroid ? await _collectForegroundServiceMetrics() : null;

    // Build app metrics group
    final app = AppMetricsGroup(
      runtime: runtime,
      platform: platform,
      device: device,
      battery: battery,
      network: network,
      permissions: permissions,
      foregroundService: foregroundService,
    );

    // Build node metrics group
    final node = NodeMetricsGroup(
      identity: identity,
      status: status,
      consensus: consensus,
      blockchain: blockchain,
      production: production,
      wallet: wallet,
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

  /// Collect lightweight metrics for app_wake_up events
  ///
  /// This is PROOF that the alarm fired! Only collects essential metrics.
  Future<MetricsPayload> _collectLightweightMetrics(
    String eventType,
    Map<String, dynamic>? eventData,
  ) async {
    final event = await _collectEventMetrics(eventType, eventData);
    final runtime = await _collectRuntimeMetrics();

    // Get battery level (lightweight)
    int batteryLevel = 0;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      // Battery info not available
    }

    final battery = BatteryMetrics(
      batteryLevel: batteryLevel,
      batteryState: 'unknown', // Skip detailed collection for lightweight
      batteryOptimizationDisabled: false,
      powerSaveMode: false,
      lowPowerMode: false,
    );

    // Minimal app metrics
    final app = AppMetricsGroup(
      runtime: runtime,
      platform: null, // Skip for lightweight
      device: null, // Skip for lightweight
      battery: battery,
      network: null, // Skip for lightweight
      permissions: null, // Skip for lightweight
      foregroundService: null, // Skip for lightweight
    );

    // Minimal node metrics
    final identity = await _collectIdentityMetrics();
    final node = NodeMetricsGroup(
      identity: identity,
      status: null, // Skip for lightweight
      consensus: null, // Skip for lightweight
      blockchain: null, // Skip for lightweight
      production: null, // Skip for lightweight
      wallet: null, // Skip for lightweight
      peers: null, // Skip for lightweight
    );

    return MetricsPayload(
      event: event,
      app: app,
      node: node,
    );
  }

  /// Collect minimal metrics for permission/scheduling events
  ///
  /// This is the most lightweight collection - only event + runtime + identity.
  /// Used for tracking events that don't require context (permissions, alarms scheduled).
  Future<MetricsPayload> _collectMinimalMetrics(
    String eventType,
    Map<String, dynamic>? eventData,
  ) async {
    _logger.d('Collecting minimal metrics - Event: $eventType');

    final event = await _collectEventMetrics(eventType, eventData);
    final runtime = await _collectRuntimeMetrics();

    _logger.d('Event timestamp: ${event.timestamp}');
    _logger.d('App state: ${runtime.appState}');

    // Minimal app metrics - only runtime
    final app = AppMetricsGroup(
      runtime: runtime,
      platform: null,
      device: null,
      battery: null,
      network: null,
      permissions: null,
      foregroundService: null,
    );

    // Minimal node metrics - only identity
    final identity = await _collectIdentityMetrics();
    _logger.d('Peer ID: ${identity.peerId}');

    final node = NodeMetricsGroup(
      identity: identity,
      status: null,
      consensus: null,
      blockchain: null,
      production: null,
      wallet: null,
      peers: null,
    );

    return MetricsPayload(
      event: event,
      app: app,
      node: node,
    );
  }

  /// Collect production-focused metrics for slot events
  Future<MetricsPayload> _collectProductionFocusedMetrics(
    String eventType,
    Map<String, dynamic>? eventData,
    double? walletBalance,
    String? walletAddress,
  ) async {
    final event = await _collectEventMetrics(eventType, eventData);
    final runtime = await _collectRuntimeMetrics();
    final battery = await _collectBatteryMetrics();

    // App metrics (reduced set)
    final app = AppMetricsGroup(
      runtime: runtime,
      platform: null, // Skip for production
      device: null, // Skip for production
      battery: battery,
      network: null, // Skip for production
      permissions: null, // Skip for production
      foregroundService:
          Platform.isAndroid ? await _collectForegroundServiceMetrics() : null,
    );

    // Node metrics (production-focused)
    final identity = await _collectIdentityMetrics();
    final status = await _collectStatusMetrics();
    final consensus = await _collectConsensusMetrics();
    final production = _collectProductionMetrics(); // Existing method

    final node = NodeMetricsGroup(
      identity: identity,
      status: status,
      consensus: consensus,
      blockchain: null, // Skip detailed blockchain for production
      production: production,
      wallet: null, // Skip wallet for production
      peers: null, // Skip peers for production
    );

    return MetricsPayload(
      event: event,
      app: app,
      node: node,
    );
  }

  /// Collect node identity
  Future<IdentityMetrics> _collectIdentityMetrics() async {
    // Get peer ID from backend service
    final peerId = RustBackendService.instance.getPeerId();

    return IdentityMetrics(
      peerId: peerId,
    );
  }

  /// Collect app runtime and performance metrics
  Future<RuntimeMetrics> _collectRuntimeMetrics() async {
    final packageInfo = await PackageInfo.fromPlatform();

    // Calculate uptime
    final uptime = _appStartTime != null
        ? DateTime.now().difference(_appStartTime!).inMilliseconds
        : 0;

    // Check if wakelock is held
    final wakelockActive = await WakelockPlus.enabled;

    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    final notificationsEnabled = notificationStatus.isGranted;

    // Map lifecycle state to string
    String appState;
    switch (_appLifecycleState) {
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

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      platformVersion = androidInfo.version.release;
      architecture = androidInfo.supportedAbis.isNotEmpty
          ? androidInfo.supportedAbis.first
          : null;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
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

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      manufacturer = androidInfo.manufacturer;
      model = androidInfo.model;
      isPhysical = androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
      manufacturer = 'Apple';
      model = iosInfo.model;
      isPhysical = iosInfo.isPhysicalDevice;
    }

    return DeviceMetrics(
      deviceId: deviceId,
      deviceManufacturer: manufacturer,
      deviceModel: model,
      isPhysicalDevice: isPhysical,
    );
  }

  /// Collect battery state
  Future<BatteryMetrics> _collectBatteryMetrics() async {
    // Default values for when battery info is unavailable
    int batteryLevel = 0; // 0 when unavailable (API requires >= 0)
    BatteryState batteryState = BatteryState.unknown;
    bool batteryAvailable = true;

    try {
      batteryLevel = await _battery.batteryLevel;
      batteryState = await _battery.batteryState;
    } catch (e) {
      // Battery info not available on this platform (desktop/simulator)
      // Use default values
      batteryAvailable = false;
    }

    // Check if battery optimization is disabled (Android)
    bool batteryOptimizationDisabled = false;
    if (Platform.isAndroid) {
      try {
        batteryOptimizationDisabled =
            await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
      } catch (_) {
        // Ignore if method not available
      }
    }

    // For power save mode, we'll use battery state as proxy
    // Only calculate power modes when battery info is available
    final powerSaveMode = !batteryAvailable
        ? false
        : (batteryState == BatteryState.charging ? false : batteryLevel < 20);
    final lowPowerMode = !batteryAvailable ? false : batteryLevel < 20;

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

  /// Collect permissions state
  Future<PermissionsMetrics> _collectPermissionsMetrics() async {
    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    final notificationGranted = notificationStatus.isGranted;

    // Check schedule exact alarm permission (Android 12+)
    bool exactAlarmsPermission = false;
    if (Platform.isAndroid) {
      try {
        exactAlarmsPermission = PlatformAlarmService.instance.hasPermissions;
      } catch (_) {
        // Ignore if method not available
      }
    } else if (Platform.isIOS) {
      // iOS doesn't have exact alarms, use notification permission
      exactAlarmsPermission = notificationGranted;
    }

    // Battery optimization exempt (Android)
    bool batteryOptimizationExempt = false;
    if (Platform.isAndroid) {
      try {
        batteryOptimizationExempt =
            await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
      } catch (_) {
        // Ignore if method not available
      }
    }

    // Map notification status to string
    String notificationPermission = 'denied';
    if (notificationStatus.isGranted) {
      notificationPermission = 'authorized';
    } else if (notificationStatus.isPermanentlyDenied) {
      notificationPermission = 'permanently_denied';
    }

    return PermissionsMetrics(
      permissionNotifications: notificationGranted,
      permissionExactAlarms: exactAlarmsPermission,
      permissionBatteryOptimizationExempt: batteryOptimizationExempt,
      exactAlarmsPermission: exactAlarmsPermission,
      notificationPermission: notificationPermission,
    );
  }

  /// Collect node status metrics from Rust backend
  Future<StatusMetrics> _collectStatusMetrics() async {
    bool nodeRunning = RustBackendService.instance.isRunning;
    String nodeState = nodeRunning ? 'running' : 'stopped';
    String? syncStatus;
    int? bestTipSlot;
    String? bestTipHash;
    int connectedPeers = 0;

    if (nodeRunning) {
      try {
        final status = await RustBackendService.instance.getStatus();
        if (status != null) {
          // Count connected peers first
          connectedPeers = status.peers
              .where(
                  (p) => p.connectionStatus == PeerConnectionStatus.connected)
              .length;

          // Determine sync status based on blockchain sync state
          final syncBlocks = status.blockchain.sync.blocks;

          // Check if we're still connecting (no peers or no sync data)
          if (connectedPeers == 0 || syncBlocks == null) {
            syncStatus = 'connecting';
          } else {
            // We have peers and sync data - check sync progress
            final totalBlocks = syncBlocks.applyProgress.done +
                syncBlocks.applyProgress.pending +
                syncBlocks.applyProgress.idle;
            if (totalBlocks == BigInt.zero ||
                syncBlocks.applyProgress.done == totalBlocks) {
              syncStatus = 'synced';
            } else {
              syncStatus = 'syncing';
            }
          }

          // Best tip info from blockchain
          final bestTip = status.blockchain.bestTip;
          bestTipSlot = bestTip.globalSlot;
          bestTipHash = bestTip.hash.toString();
        }
      } catch (_) {
        // Error getting status, node might be starting
        nodeState = 'error';
      }
    }

    return StatusMetrics(
      nodeRunning: nodeRunning,
      nodeState: nodeState,
      nodeSyncStatus: syncStatus,
      nodeBestTipSlot: bestTipSlot,
      nodeBestTipHash: bestTipHash,
      nodeConnectedPeers: connectedPeers,
    );
  }

  /// Collect consensus and block production metrics
  Future<ConsensusMetrics> _collectConsensusMetrics() async {
    int? currentEpoch;
    int? currentGlobalSlot;

    if (RustBackendService.instance.isRunning) {
      try {
        final status = await RustBackendService.instance.getStatus();
        if (status != null) {
          final bestTip = status.blockchain.bestTip;
          currentEpoch = bestTip.epoch;

          // Use backend-provided current global slot
          currentGlobalSlot = status.node.curGlobalSlot;
          // TODO: Decide fallback strategy when curGlobalSlot is unavailable

          // TODO: Implement won slots and production tracking
          // This will be implemented in Phase 3
        }
      } catch (_) {
        // Ignore errors
      }
    }

    return ConsensusMetrics(
      currentEpoch: currentEpoch,
      currentGlobalSlot: currentGlobalSlot,
      // These will be populated when we implement consensus tracking
      currentEpochWonSlots: null,
      currentEpochProduced: null,
      currentEpochFailed: null,
      totalWonSlots: null,
      totalBlocksProduced: null,
      totalBlocksFailed: null,
    );
  }

  /// Collect blockchain state
  Future<BlockchainMetrics> _collectBlockchainMetrics() async {
    int? blockchainHeight;
    String? latestBlockHash;
    int? latestBlockSlot;
    String? latestBlockTimestamp;

    if (RustBackendService.instance.isRunning) {
      try {
        final status = await RustBackendService.instance.getStatus();
        if (status != null) {
          final bestTip = status.blockchain.bestTip;

          blockchainHeight = bestTip.height;
          latestBlockHash = bestTip.hash.toString();
          latestBlockSlot = bestTip.globalSlot;
          // Convert timestamp (assuming it's in milliseconds since epoch)
          latestBlockTimestamp = DateTime.fromMillisecondsSinceEpoch(
            bestTip.timestamp.toInt(),
            isUtc: true,
          ).toIso8601String();
        }
      } catch (_) {
        // Ignore errors
      }
    }

    return BlockchainMetrics(
      blockchainHeight: blockchainHeight,
      blockchainLatestBlockHash: latestBlockHash,
      blockchainLatestBlockSlot: latestBlockSlot,
      blockchainLatestBlockTimestamp: latestBlockTimestamp,
    );
  }

  /// Collect block production configuration
  ProductionMetrics _collectProductionMetrics() {
    return ProductionMetrics(
      backgroundProductionEnabled: true, // Enabled if app is configured
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

  /// Collect wallet metrics
  WalletMetrics _collectWalletMetrics(double? balance, String? address) {
    return WalletMetrics(
      walletBalance: balance,
      walletAddress: address,
    );
  }

  /// Collect peers metrics
  Future<List<PeerMetrics>> _collectPeersMetrics() async {
    if (!RustBackendService.instance.isRunning) {
      return [];
    }

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) return [];

      return status.peers.map((peer) {
        return PeerMetrics(
          peerId: peer.peerId.toString(),
          address: peer.address,
          bestTip: null, // Not available in current RpcPeerInfo
          bestTipHeight: peer.bestTipHeight,
          bestTipGlobalSlot: peer.bestTipGlobalSlot,
          bestTipTimestamp: null, // Not available in current RpcPeerInfo
          connectionStatus: peer.connectionStatus.toString().split('.').last,
          connectingDetails: null, // Not available in current RpcPeerInfo
          incoming: peer.incoming,
          time: DateTime.now().millisecondsSinceEpoch, // Current time as proxy
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
