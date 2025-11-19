import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/ios_foreground_keepalive_service.dart';
import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

class BackgroundProductionSettingsScreen extends ConsumerStatefulWidget {
  const BackgroundProductionSettingsScreen({super.key});

  @override
  ConsumerState<BackgroundProductionSettingsScreen> createState() =>
      _BackgroundProductionSettingsScreenState();
}

class _BackgroundProductionSettingsScreenState
    extends ConsumerState<BackgroundProductionSettingsScreen> {
  bool _hasPermissions = false;
  bool _batteryOptDisabled = false;
  String? _deviceManufacturer;
  bool _iosKeepAliveActive = false;
  Timer? _autoTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Run initialization in background without blocking UI
    _checkStatus();

    // Periodic auto-refresh every 3 seconds
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_refreshing) {
        _refreshProviders();
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

    try {
      // Initialize services (non-blocking)
      await PlatformAlarmService.instance.initialize();
      await EpochSlotSchedulerService.instance.initialize();
      await SlotProductionRepository.instance.initialize();

      if (!mounted) return;

      // Check permissions and update UI
      final hasPermissions = PlatformAlarmService.instance.hasPermissions;

      if (Platform.isAndroid) {
        // Check battery optimization
        final batteryOptDisabled =
            await PlatformAlarmService.instance.isBatteryOptimizationDisabled();

        // Get device manufacturer
        final deviceManufacturer =
            await PlatformAlarmService.instance.getDeviceManufacturer();

        if (mounted) {
          setState(() {
            _hasPermissions = hasPermissions;
            _batteryOptDisabled = batteryOptDisabled;
            _deviceManufacturer = deviceManufacturer;
          });
        }
      } else if (Platform.isIOS) {
        final iosKeepAliveActive =
            IOSForegroundKeepAliveService.instance.isActive;

        if (mounted) {
          setState(() {
            _hasPermissions = hasPermissions;
            _iosKeepAliveActive = iosKeepAliveActive;
          });
        }
      }

      // Refresh providers to get latest VRF status and won slots
      await _refreshProviders();
    } catch (e) {
      debugPrint('Error checking status: $e');
    }
  }

  Future<void> _refreshProviders() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(nodeRawStatusProvider.notifier).refresh();
      await ref.read(nodeEpochRewardsProvider.notifier).refresh();
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Block Production'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _checkStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Platform-specific info card
            _buildPlatformInfoCard(theme, colorScheme),
            const SizedBox(height: 24),

            // Permissions section
            _buildPermissionsSection(theme, colorScheme),
            const SizedBox(height: 24),

            // iOS Keep-Alive section (if iOS)
            if (Platform.isIOS) ...[
              _buildIOSKeepAliveSection(theme, colorScheme),
              const SizedBox(height: 24),
            ],

            // Android Battery section (if Android)
            if (Platform.isAndroid) ...[
              _buildAndroidBatterySection(theme, colorScheme),
              const SizedBox(height: 24),
            ],

            // Scheduled slots section
            _buildScheduledSlotsSection(theme, colorScheme),
            const SizedBox(height: 24),

            // Statistics card
            _buildStatisticsCard(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final isAndroid = Platform.isAndroid;
    final platformName = isAndroid ? 'Android' : 'iOS';
    final description = isAndroid
        ? 'Automatically wakes your device using exact alarms to produce blocks at won slot times.'
        : 'Automatically wakes your device using background tasks to produce blocks at won slot times.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAndroid ? Icons.android : Icons.phone_iphone,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '$platformName Background Production',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (isAndroid && _deviceManufacturer != null) ...[
              const SizedBox(height: 8),
              Text(
                'Device: $_deviceManufacturer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasPermissions ? Icons.check_circle : Icons.warning,
                  color: _hasPermissions ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Text(
                  'Permissions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Platform.isAndroid
                  ? _hasPermissions
                      ? 'Exact alarm permission granted'
                      : 'Exact alarm permission required for reliable wake-ups'
                  : _hasPermissions
                      ? 'Notification permission granted'
                      : 'Notification permission required',
              style: theme.textTheme.bodyMedium,
            ),
            if (!_hasPermissions) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.settings),
                label: const Text('Grant Permissions'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIOSKeepAliveSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phonelink_lock,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  'Foreground Keep-Alive Mode',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _iosKeepAliveActive
                  ? 'ACTIVE - App will stay awake for block production (99% reliable)'
                  : 'INACTIVE - Enable for best iOS reliability (99% success rate)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _iosKeepAliveActive,
              onChanged: _toggleIOSKeepAlive,
              title: Text(
                _iosKeepAliveActive ? 'Keep-Alive ON' : 'Keep-Alive OFF',
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
              subtitle: Text(
                'Keeps app awake during slot times',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (_iosKeepAliveActive) ...[
              const Divider(),
              Text(
                'Tips for best results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              _buildTip('Keep app in foreground during slot times'),
              _buildTip('Connect device to charger'),
              _buildTip('Enable Guided Access (triple-click side button)'),
              _buildTip('Set screen brightness to minimum'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidBatterySection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _batteryOptDisabled
                      ? Icons.battery_full
                      : Icons.battery_alert,
                  color: _batteryOptDisabled ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Text(
                  'Battery Optimization',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _batteryOptDisabled
                  ? 'Battery optimization disabled (recommended)'
                  : 'Battery optimization may interfere with alarms',
              style: theme.textTheme.bodyMedium,
            ),
            if (!_batteryOptDisabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openBatterySettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Battery Settings'),
              ),
            ],
            if (_deviceManufacturer != null &&
                ['xiaomi', 'samsung', 'oppo', 'oneplus']
                    .contains(_deviceManufacturer!.toLowerCase())) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_deviceManufacturer devices require additional settings. Tap for guide.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledSlotsSection(ThemeData theme, ColorScheme colorScheme) {
    // Get VRF status and won slots from providers
    final rawStatusAsync = ref.watch(nodeRawStatusProvider);
    final epochRewardsAsync = ref.watch(nodeEpochRewardsProvider);

    // Unwrap async values
    final rawStatus = rawStatusAsync.valueOrNull;
    final epochRewards = epochRewardsAsync.valueOrNull;

    // Get VRF status
    final vrfEvaluator = rawStatus?.vrfEvaluator;
    final vrfStatus = vrfEvaluator?.currentEpochVrfEvaluationStatus;
    final isVrfComplete =
        vrfStatus != null && vrfStatus == RpcStatusVrfEvaluationStatus.completed;
    final isVrfCalculating = vrfStatus != null &&
        vrfStatus == RpcStatusVrfEvaluationStatus.evaluating;

    // Get current epoch from raw status
    final currentEpoch = rawStatus?.epoch;

    // Validate epoch matches before showing won slots (prevents showing stale data)
    final allWonSlots = (epochRewards != null &&
            currentEpoch != null &&
            epochRewards.epoch == currentEpoch)
        ? (epochRewards.wonSlots ?? [])
        : <RpcEpochWonSlot>[];

    // Filter to future slots only, with correct timezone handling
    final now = DateTime.now();
    final futureSlots = allWonSlots.where((slot) {
      try {
        // Parse timestamp as UTC and convert to local time
        final slotTime = DateTime.fromMillisecondsSinceEpoch(
          slot.expectedTimeMs.toInt(),
          isUtc: true,
        ).toLocal();
        return slotTime.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();

    // Get next slot
    final nextSlot = futureSlots.isNotEmpty ? futureSlots.first : null;

    // VRF status chip
    Widget vrfStatusChip;
    if (vrfStatus == null) {
      vrfStatusChip = Chip(
        label: const Text('Loading...'),
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        labelStyle: theme.textTheme.labelSmall,
      );
    } else if (isVrfComplete) {
      vrfStatusChip = Chip(
        label: const Text('VRF Complete'),
        backgroundColor: Colors.green.withValues(alpha: 0.2),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: Colors.green.shade700,
        ),
      );
    } else if (isVrfCalculating) {
      vrfStatusChip = Chip(
        label: const Text('VRF Calculating...'),
        backgroundColor: Colors.orange.withValues(alpha: 0.2),
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          color: Colors.orange.shade700,
        ),
      );
    } else {
      vrfStatusChip = Chip(
        label: const Text('VRF Pending'),
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        labelStyle: theme.textTheme.labelSmall,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Won Slots This Epoch',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                vrfStatusChip,
              ],
            ),
            const SizedBox(height: 12),
            if (futureSlots.isEmpty)
              Text(
                allWonSlots.isEmpty
                    ? 'No slots won for this epoch'
                    : 'No upcoming slots remaining',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            else ...[
              Text(
                '${futureSlots.length} upcoming slot${futureSlots.length != 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              if (nextSlot != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Slot',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slot ${nextSlot.globalSlot}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            nextSlot.expectedTimeMs.toInt(),
                            isUtc: true,
                          ).toLocal(),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme, ColorScheme colorScheme) {
    final stats = SlotProductionRepository.instance.getStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Production Statistics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Won Slots',
                    stats.totalWonSlots.toString(),
                    Icons.star,
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Produced',
                    stats.totalProduced.toString(),
                    Icons.check_circle,
                    colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Failed',
                    stats.totalFailed.toString(),
                    Icons.error,
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Success Rate',
                    '${stats.successRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours} hours';
    } else {
      return 'in ${difference.inDays} days';
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await PlatformAlarmService.instance.requestPermissions();
    await _checkStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Permissions granted successfully'
              : 'Please grant permissions in settings',
        ),
      ),
    );
  }

  Future<void> _openBatterySettings() async {
    await PlatformAlarmService.instance.openBatteryOptimizationSettings();
  }

  Future<void> _toggleIOSKeepAlive(bool value) async {
    if (value) {
      final success =
          await IOSForegroundKeepAliveService.instance.startKeepAlive();
      if (success && mounted) {
        setState(() => _iosKeepAliveActive = true);
      }
    } else {
      await IOSForegroundKeepAliveService.instance.stopKeepAlive();
      if (mounted) {
        setState(() => _iosKeepAliveActive = false);
      }
    }
  }
}
