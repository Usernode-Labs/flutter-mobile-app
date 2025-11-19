import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/metrics/data/models/metrics_payload.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service responsible for collecting all metrics from various sources
class MetricsCollectorService {
  MetricsCollectorService._();
  static final MetricsCollectorService instance = MetricsCollectorService._();

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

  /// Collect all metrics and return a complete payload
  Future<MetricsPayload> collectMetrics({
    double? walletBalance,
    String? walletAddress,
  }) async {
    // Collect all metrics in parallel for efficiency
    final results = await Future.wait([
      _collectEventMetrics(),
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
  Future<EventMetrics> _collectEventMetrics() async {
    return EventMetrics(
      eventType: 'health_check',
      timestamp: DateTime.now().toUtc().toIso8601String(),
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
    int batteryLevel = -1; // -1 indicates unavailable
    BatteryState batteryState = BatteryState.unknown;

    try {
      batteryLevel = await _battery.batteryLevel;
      batteryState = await _battery.batteryState;
    } catch (e) {
      // Battery info not available on this platform (desktop/simulator)
      // Use default values
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
    // Handle unavailable battery level gracefully
    final powerSaveMode = batteryLevel < 0
        ? false
        : (batteryState == BatteryState.charging ? false : batteryLevel < 20);
    final lowPowerMode = batteryLevel < 0 ? false : batteryLevel < 20;

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
          // Determine sync status based on blockchain sync state
          final syncBlocks = status.blockchain.sync.blocks;
          if (syncBlocks != null) {
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

          // Count connected peers
          connectedPeers = status.peers
              .where(
                  (p) => p.connectionStatus == PeerConnectionStatus.connected)
              .length;
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
          currentGlobalSlot = bestTip.globalSlot;

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
