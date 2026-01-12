import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/models/block_production_event.dart';
import 'package:crypto_mobile_app/features/metrics/models/metrics_payload.dart';
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
class MetricsCollectorService {
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
  String? _cachedWalletAddress;

  // Semi-static data with TTL
  DateTime? _batteryOptimizationCacheTime;
  bool? _cachedBatteryOptimization;
  final Duration _batteryOptimizationTTL = const Duration(minutes: 5);

  DateTime? _permissionsCacheTime;
  _PermissionsCache? _cachedPermissions;
  final Duration _permissionsTTL = const Duration(minutes: 1);

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

  /// Update the current app lifecycle state
  void updateAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  /// Collect metrics for a specific block production event
  ///
  /// Always collects full metrics for all event types, providing complete
  /// visibility into app health, node performance, and block production.
  Future<MetricsPayload> collectMetricsForEvent(
    BlockProductionEvent event, {
    BigInt? walletBalance,
    String? walletAddress,
  }) async {
    _log.debug('Collecting full metrics for event: ${event.eventType}');

    return await collectMetrics(
      eventType: event.eventType,
      eventData: event.toJson(),
      walletBalance: walletBalance,
      walletAddress: walletAddress,
    );
  }

  /// Collect all metrics and return a complete payload
  ///
  /// Always collects full metrics for comprehensive system state visibility.
  Future<MetricsPayload> collectMetrics({
    String eventType = 'health_check',
    Map<String, dynamic>? eventData,
    BigInt? walletBalance,
    String? walletAddress,
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

    // Collect all metrics in parallel for efficiency
    // Pass rawStatus to methods that need it to avoid duplicate FFI calls
    final results = await Future.wait([
      _collectEventMetrics(eventType, eventData),
      _collectRuntimeMetrics(),
      _collectPlatformMetrics(),
      _collectDeviceMetrics(),
      _collectBatteryMetrics(),
      _collectNetworkMetrics(),
      _collectPermissionsMetrics(),
      _collectStatusMetrics(rawStatus: rawStatus),
      _collectBlockchainMetrics(rawStatus: rawStatus),
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

    // Collect additional metrics - pass rawStatus to avoid duplicate calls
    final identity = await _collectIdentityMetrics();
    final consensus = await _collectConsensusMetrics(rawStatus: rawStatus);
    final wallet = _collectWalletMetrics(walletBalance, walletAddress);
    final peers = await _collectPeersMetrics(rawStatus: rawStatus);
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

  /// Collect node identity
  Future<IdentityMetrics> _collectIdentityMetrics() async {
    // Get peer ID from backend service - CACHED (static per session)
    _cachedPeerId ??= RustBackendService.instance.getPeerId();
    final peerId = _cachedPeerId;

    // Get chain ID from node status provider (shared cache)
    String? chainId;
    if (_container != null) {
      try {
        final nodeStatusAsync = _container!.read(nodeStatusProvider);
        chainId = nodeStatusAsync.value?.chainId;
        _log.debug('Got chain_id from nodeStatusProvider: $chainId');
      } catch (e) {
        _log.debug('Failed to get chain_id from nodeStatusProvider: $e');
      }
    }

    // Fallback: derive from selected network if chain_id unavailable from provider
    if (chainId == null || chainId.isEmpty) {
      try {
        final networkType =
            await RustBackendService.instance.getSelectedNetwork();
        chainId = networkType.name; // 'testnet' or 'internal'
        _log.debug('Using network type as chain_id fallback: $chainId');
      } catch (e) {
        _log.debug('Failed to get network type for chain_id fallback: $e');
        chainId = null;
      }
    }

    return IdentityMetrics(
      peerId: peerId,
      chainId: chainId,
    );
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

  /// Collect permissions state
  Future<PermissionsMetrics> _collectPermissionsMetrics() async {
    // Check if we need to refresh permissions cache (1min TTL)
    if (_shouldRefreshCache(_permissionsCacheTime, _permissionsTTL)) {
      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      final notificationGranted = notificationStatus.isGranted;

      // Check schedule exact alarm permission (Android 12+)
      bool exactAlarmsPermission = false;
      if (Platform.isAndroid) {
        try {
          exactAlarmsPermission = PlatformAlarmService.instance.hasPermissions;
        } catch (e) {
          _log.debug('Could not check exact alarms permission: $e');
        }
      } else if (Platform.isIOS) {
        // iOS doesn't have exact alarms, use notification permission
        exactAlarmsPermission = notificationGranted;
      }

      // Battery optimization exempt (Android) - reuse from battery cache
      bool batteryOptimizationExempt = false;
      if (Platform.isAndroid) {
        try {
          // Reuse cached battery optimization status if available
          if (_cachedBatteryOptimization != null) {
            batteryOptimizationExempt = _cachedBatteryOptimization!;
          } else {
            batteryOptimizationExempt = await PlatformAlarmService.instance
                .isBatteryOptimizationDisabled();
          }
        } catch (e) {
          _log.debug('Could not check battery optimization exempt status: $e');
        }
      }

      // Cache the results
      _cachedPermissions = _PermissionsCache(
        notification: notificationGranted,
        exactAlarms: exactAlarmsPermission,
        batteryOptimization: batteryOptimizationExempt,
      );
      _permissionsCacheTime = DateTime.now();
    }

    // Use cached permissions
    final notificationGranted = _cachedPermissions?.notification ?? false;
    final exactAlarmsPermission = _cachedPermissions?.exactAlarms ?? false;
    final batteryOptimizationExempt =
        _cachedPermissions?.batteryOptimization ?? false;

    // Map notification status to string
    String notificationPermission = 'denied';
    if (notificationGranted) {
      notificationPermission = 'authorized';
    }
    // Note: We can't determine permanently_denied from cache,
    // but this is acceptable for the caching strategy

    return PermissionsMetrics(
      permissionExactAlarms: exactAlarmsPermission,
      permissionBatteryOptimizationExempt: batteryOptimizationExempt,
      exactAlarmsPermission: exactAlarmsPermission,
      notificationPermission: notificationPermission,
    );
  }

  /// Collect node status metrics from Rust backend
  ///
  /// If [rawStatus] is provided, it will be used instead of fetching from backend.
  /// This avoids expensive FFI calls when status is already available.
  Future<StatusMetrics> _collectStatusMetrics(
      {NodeStatusState? rawStatus}) async {
    bool nodeRunning = RustBackendService.instance.isRunning;
    String nodeState = nodeRunning ? 'running' : 'stopped';
    String? syncStatus;
    int? bestTipSlot;
    String? bestTipHash;
    int connectedPeers = 0;

    if (nodeRunning) {
      try {
        // Use existing sync status provider if container is available
        if (_container != null) {
          // Read sync status from provider (reuses UI logic)
          final statusAsync = _container!.read(nodeStatusProvider);
          final statusValue = statusAsync.valueOrNull;
          if (statusValue != null) {
            syncStatus = statusValue.syncStatus.state
                .name; // 'connecting', 'syncing', 'synced', 'error'
            connectedPeers = statusValue.connectedPeers;

            // Get best tip data
            final bestTip = statusValue.localBest;
            bestTipSlot = bestTip?.globalSlot;
            bestTipHash = bestTip?.hash.toString();
          }
        } else {
          // Use provided rawStatus
          if (rawStatus != null) {
            // Count connected peers from rawStatus
            connectedPeers = rawStatus.connectedPeers;

            // Determine sync status based on blockchain sync state
            final applyProgress = rawStatus.applyProgress;

            // Check if we're still connecting (no peers or no sync data)
            if (connectedPeers == 0 || applyProgress == null) {
              syncStatus = 'connecting';
            } else {
              // We have peers and sync data - check sync progress
              final totalBlocks = applyProgress.done +
                  applyProgress.pending +
                  applyProgress.idle;
              if (totalBlocks == BigInt.zero ||
                  applyProgress.done == totalBlocks) {
                syncStatus = 'synced';
              } else {
                syncStatus = 'syncing';
              }
            }

            // Best tip info from blockchain
            final bestTip = rawStatus.networkBest ?? rawStatus.localBest;
            bestTipSlot = bestTip?.globalSlot;
            bestTipHash = bestTip?.hash.toString();
          }
        }
      } catch (e) {
        _log.debug('Error getting node status: $e');
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
  ///
  /// If [rawStatus] is provided, it will be used instead of fetching from backend.
  /// This avoids expensive FFI calls when status is already available.
  Future<ConsensusMetrics> _collectConsensusMetrics(
      {NodeStatusState? rawStatus}) async {
    int? currentEpoch;
    int? currentGlobalSlot;
    int? currentEpochWonSlots;
    int? currentEpochProduced;
    int? currentEpochFailed;
    int? evaluatedCurrentEpoch;
    String? currentEpochVrfEvaluationStatus;
    String? nextEpochVrfEvaluationStatus;
    double? bpSuccessRate;

    if (RustBackendService.instance.isRunning) {
      try {
        // Use provided rawStatus
        if (rawStatus != null) {
          final bestTip = rawStatus.networkBest ?? rawStatus.localBest;
          currentEpoch = bestTip?.epoch;

          // Use backend-provided current global slot
          currentGlobalSlot = rawStatus.currentGlobalSlot;

          // Extract VRF evaluator metrics
          final vrfEvaluator = rawStatus.vrfEvaluator;
          if (vrfEvaluator != null) {
            evaluatedCurrentEpoch = vrfEvaluator.details?.evaluatedCurrentEpoch;
            currentEpochWonSlots =
                vrfEvaluator.details?.wonSlotsCurrentEpoch.toInt();
            currentEpochVrfEvaluationStatus =
                vrfEvaluator.currentEpochVrfEvaluationStatus.name;
            nextEpochVrfEvaluationStatus =
                vrfEvaluator.nextEpochVrfEvaluationStatus.name;
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
      currentGlobalSlot: currentGlobalSlot,
      currentEpochWonSlots: currentEpochWonSlots,
      currentEpochProduced: currentEpochProduced,
      currentEpochFailed: currentEpochFailed,
      evaluatedCurrentEpoch: evaluatedCurrentEpoch,
      currentEpochVrfEvaluationStatus: currentEpochVrfEvaluationStatus,
      nextEpochVrfEvaluationStatus: nextEpochVrfEvaluationStatus,
      bpSuccessRate: bpSuccessRate,
      // Total metrics not implemented yet
      totalWonSlots: null,
      totalBlocksProduced: null,
      totalBlocksFailed: null,
    );
  }

  /// Collect blockchain state
  ///
  /// If [rawStatus] is provided, it will be used instead of fetching from backend.
  /// This avoids expensive FFI calls when status is already available.
  Future<BlockchainMetrics> _collectBlockchainMetrics(
      {NodeStatusState? rawStatus}) async {
    int? blockchainHeight;
    String? latestBlockHash;
    int? latestBlockSlot;
    String? latestBlockTimestamp;

    if (RustBackendService.instance.isRunning) {
      try {
        // Use provided rawStatus
        if (rawStatus != null) {
          final bestTip = rawStatus.networkBest ?? rawStatus.localBest;

          blockchainHeight = bestTip?.height;
          latestBlockHash = bestTip?.hash.toString();
          latestBlockSlot = bestTip?.globalSlot;
          // Convert timestamp (assuming it's in milliseconds since epoch)
          if (bestTip?.timestamp != null) {
            latestBlockTimestamp = DateTime.fromMillisecondsSinceEpoch(
              bestTip!.timestamp.toInt(),
              isUtc: true,
            ).toIso8601String();
          }
        }
      } catch (e) {
        _log.debug('Error collecting blockchain metrics: $e');
      }
    }

    return BlockchainMetrics(
      blockchainHeight: blockchainHeight,
      blockchainLatestBlockHash: latestBlockHash,
      blockchainLatestBlockSlot: latestBlockSlot,
      blockchainLatestBlockTimestamp: latestBlockTimestamp,
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
  WalletMetrics _collectWalletMetrics(BigInt? balance, String? address) {
    // Cache wallet address if provided - CACHED (immutable per session)
    if (address != null) {
      _cachedWalletAddress = address;
    }

    return WalletMetrics(
      walletBalance: balance,
      walletAddress: _cachedWalletAddress ?? address,
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
          bestTipHeight: peer.bestTipHeight,
          bestTipGlobalSlot: peer.bestTipGlobalSlot,
          bestTipTimestamp: null, // Not available in current RpcPeerInfo
          connectionStatus: peer.connectionStatus.toString().split('.').last,
          connectingDetails: null, // Not available in current RpcPeerInfo
          incoming: peer.incoming,
          time: DateTime.now().millisecondsSinceEpoch, // Current time as proxy
        );
      }).toList();
    } catch (e) {
      _log.debug('Error collecting peers metrics: $e');
      return [];
    }
  }
}

/// Helper class for caching permissions data
class _PermissionsCache {
  final bool notification;
  final bool exactAlarms;
  final bool batteryOptimization;

  _PermissionsCache({
    required this.notification,
    required this.exactAlarms,
    required this.batteryOptimization,
  });
}
