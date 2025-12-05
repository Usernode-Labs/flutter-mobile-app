import 'dart:async';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/ios_foreground_keepalive_service.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_keepalive_service.dart';
import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

final _log = LoggingService.instance.withTag(LogTag.settings);

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
  bool _androidKeepAliveActive = false;
  Timer? _autoTimer;
  bool _refreshing = false;
  bool _active = false; // active when Settings tab is selected (index 2)

  @override
  void initState() {
    super.initState();
    // Run initialization in background without blocking UI
    _checkStatus();

    // Determine initial active state and maybe start timer
    _active = _isActiveTab();
    if (_active) _startTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  bool _isActiveTab() {
    try {
      return ref.read(currentHomeTabProvider) == 2;
    } catch (_) {
      return false;
    }
  }

  void _startTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _active && !_refreshing) {
        _checkStatus();
      }
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
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

        // Check Android keep-alive status
        final androidKeepAliveActive =
            await AndroidForegroundKeepAliveService.instance.refreshState();

        if (mounted) {
          setState(() {
            _hasPermissions = hasPermissions;
            _batteryOptDisabled = batteryOptDisabled;
            _deviceManufacturer = deviceManufacturer;
            _androidKeepAliveActive = androidKeepAliveActive;
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
      _log.debug('Error checking status: $e');
    }
  }

  Future<void> _refreshProviders() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(nodeStatusProvider.notifier).refresh();
      await ref.read(epochRewardsProvider.notifier).refresh();
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to tab changes and start/stop timers
    final currentTab = ref.watch(currentHomeTabProvider);
    final shouldBeActive = currentTab == 2;
    if (shouldBeActive != _active) {
      _active = shouldBeActive;
      if (_active) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: _checkStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // About section
            _buildAboutSection(theme, colorScheme),
            const SizedBox(height: 8),

            // Build Info section
            _buildBuildInfoCard(theme, colorScheme),
            const SizedBox(height: 8),

            // Appearance / theme section
            _buildThemeSection(theme, colorScheme),
            const SizedBox(height: 8),

            // Feature overview section
            const SizedBox(height: 8),

            // Feature overview section
            _buildFeatureOverviewCard(theme, colorScheme),
            const SizedBox(height: 8),

            // Platform-specific info card
            _buildPlatformInfoCard(theme, colorScheme),
            const SizedBox(height: 8),

            // Understanding VRF & Slots section
            _buildVrfExplanationCard(theme, colorScheme),
            const SizedBox(height: 8),

            // Permissions section
            _buildPermissionsSection(theme, colorScheme),
            const SizedBox(height: 8),

            // iOS Keep-Alive section (if iOS)
            if (Platform.isIOS) ...[
              _buildIOSKeepAliveSection(theme, colorScheme),
              const SizedBox(height: 8),
            ],

            // Android Battery section (if Android)
            if (Platform.isAndroid) ...[
              _buildAndroidBatterySection(theme, colorScheme),
              const SizedBox(height: 8),
            ],

            // Android Keep-Alive section (if Android)
            if (Platform.isAndroid) ...[
              _buildAndroidKeepAliveSection(theme, colorScheme),
              const SizedBox(height: 8),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(ThemeData theme, ColorScheme colorScheme) {
    final themeMode = ref.watch(themeModeProvider);

    void setTheme(ThemeMode mode) {
      ref.read(themeModeProvider.notifier).set(mode);
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how the app looks on your device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: themeMode,
              title: Text(
                'Use system setting',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                'Automatically follow your device’s light or dark mode.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              visualDensity: VisualDensity.compact,
              onChanged: (mode) {
                if (mode != null) setTheme(mode);
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: themeMode,
              title: Text(
                'Light mode',
                style: theme.textTheme.bodyMedium,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              visualDensity: VisualDensity.compact,
              onChanged: (mode) {
                if (mode != null) setTheme(mode);
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: themeMode,
              title: Text(
                'Dark mode',
                style: theme.textTheme.bodyMedium,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              visualDensity: VisualDensity.compact,
              onChanged: (mode) {
                if (mode != null) setTheme(mode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your device is helping run this network directly, peer to peer, with no central servers. Together with other participants\' devices, it processes transactions and runs shared code. It is one of the first networks that can be fully hosted just from participants\' own devices.\n\n' +
                  'Our goal is to enable community-run networks, where participants operate the network themselves and incentives create a schelling point around user participation.\n\n' +
                  'We are currently in testnet. The first few phases of our testing will ensure that the core network and block production works. Then we will work on adding activities, use cases, and smart contracts on top of the core app.\n\n' +
                  'We thank you for helping test this first version of the application. We\'re hopeful to build a very new and different kind of blockchain and network, and your participation helps make this possible.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final env = ref.read(buildEnvProvider);
    final l10n = AppLocalizations.of(context);
    final shortCommit = env.git.commitHash.length >= 7
        ? env.git.commitHash.substring(0, 7)
        : env.git.commitHash;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsBuildInfo,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(l10n.buildInfoVersion, env.version, theme, colorScheme),
            _buildInfoRow(l10n.buildInfoCommit, shortCommit, theme, colorScheme),
            _buildInfoRow(l10n.buildInfoBranch, env.git.branch, theme, colorScheme),
            _buildInfoRow(
                l10n.buildInfoCommitTime, env.git.commitTime, theme, colorScheme),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _buildInfoRow(
                l10n.buildInfoRustc,
                '${env.rustc.version} (${env.rustc.channel})',
                theme,
                colorScheme),
            _buildInfoRow(
                l10n.buildInfoLlvm, env.rustc.llvmVersion, theme, colorScheme),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _buildInfoRow(l10n.buildInfoCargoTarget, env.cargo.target, theme,
                colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureOverviewCard(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bgProdWhatIs,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.bgProdDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildNumberedStep(
              '1',
              l10n.bgProdVrfSelection,
              l10n.bgProdVrfSelectionDesc,
              colorScheme,
            ),
            const SizedBox(height: 12),
            _buildNumberedStep(
              '2',
              l10n.bgProdSlotScheduling,
              l10n.bgProdSlotSchedulingDesc,
              colorScheme,
            ),
            const SizedBox(height: 12),
            _buildNumberedStep(
              '3',
              l10n.bgProdBlockProduction,
              l10n.bgProdBlockProductionDesc,
              colorScheme,
            ),
            const SizedBox(height: 12),
            _buildNumberedStep(
              '4',
              l10n.bgProdSuccessTracking,
              l10n.bgProdSuccessTrackingDesc,
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedStep(
    String number,
    String title,
    String description,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isAndroid ? l10n.bgProdAndroidTitle : l10n.bgProdIosTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isAndroid ? l10n.bgProdAndroidDesc : l10n.bgProdIosDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Reliability breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.bgProdReliabilityByMode,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isAndroid) ...[
                    _buildReliabilityRow(
                      l10n.bgProdDefaultMode,
                      l10n.bgProdDefaultReliability,
                      l10n.bgProdDefaultDesc,
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildReliabilityRow(
                      l10n.bgProdKeepAliveMode,
                      l10n.bgProdKeepAliveReliability,
                      l10n.bgProdKeepAliveDesc,
                      Colors.blue,
                    ),
                  ] else ...[
                    _buildReliabilityRow(
                      l10n.bgProdKeepAliveMode,
                      l10n.bgProdIosKeepAliveReliability,
                      l10n.bgProdIosKeepAliveDesc,
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildReliabilityRow(
                      l10n.bgProdBackgroundOnly,
                      l10n.bgProdBackgroundOnlyReliability,
                      l10n.bgProdBackgroundOnlyDesc,
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ),
            if (isAndroid && _deviceManufacturer != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.smartphone,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Device: $_deviceManufacturer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReliabilityRow(
    String mode,
    String percentage,
    String description,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            percentage,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVrfExplanationCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Understanding VRF & Slots',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // What is VRF
            Text(
              'What is VRF?',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'VRF (Verifiable Random Function) is how the network fairly selects block producers. At the start of each epoch, the network runs VRF calculations to determine which validators will produce blocks in upcoming slots.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // VRF Status meanings
            Text(
              'VRF Status Meanings',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusExplanation(
              'Pending',
              'Waiting for epoch transition to start calculations',
              Colors.grey,
              colorScheme,
            ),
            const SizedBox(height: 6),
            _buildStatusExplanation(
              'Calculating',
              'VRF evaluation in progress (takes a few hours)',
              Colors.orange,
              colorScheme,
            ),
            const SizedBox(height: 6),
            _buildStatusExplanation(
              'Complete',
              'Slot assignments are finalized and scheduled',
              Colors.green,
              colorScheme,
            ),
            const SizedBox(height: 16),
            // What is a won slot
            Text(
              'What is a "Won Slot"?',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When VRF selects your node to produce a block at a specific time, you\'ve "won" that slot. Your responsibility is to have your device awake and connected so the block can be produced.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Why timing matters
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.timer,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why Timing Matters',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Each slot has a ~3-minute window. If your device doesn\'t wake up in time or loses network connectivity, the slot is missed and counted as "failed."',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusExplanation(
    String status,
    String description,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$status: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(ThemeData theme, ColorScheme colorScheme) {
    final isAndroid = Platform.isAndroid;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Why needed explanation
            Text(
              isAndroid
                  ? 'Why exact alarms are required:'
                  : 'Why notifications are required:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAndroid
                  ? 'Android restricts apps from waking the device at precise times unless explicitly allowed. Without this permission, alarms may be delayed by up to 10 minutes, causing missed slots.'
                  : 'Notifications alert you when a slot is approaching, giving you time to open the app and enable keep-alive mode for reliable production.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasPermissions
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hasPermissions
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasPermissions ? Icons.check_circle : Icons.warning,
                    size: 20,
                    color: _hasPermissions ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAndroid
                          ? _hasPermissions
                              ? 'Exact alarm permission granted'
                              : 'Exact alarm permission required'
                          : _hasPermissions
                              ? 'Notification permission granted'
                              : 'Notification permission required',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _hasPermissions
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_hasPermissions) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.settings),
                label:
                    Text(AppLocalizations.of(context).bgProdGrantPermissions),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIOSKeepAliveSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Foreground Keep-Alive Mode',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                // Reliability badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '99%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // How it works
            Text(
              'How it works:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This mode prevents iOS from suspending the app by maintaining an active wake lock. The screen stays on (at minimum brightness) and the app continuously monitors for upcoming slots.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Battery and recommendation info
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.battery_3_bar,
                    '~3-5%/hr',
                    'Battery',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.star,
                    'Critical slots',
                    'Best for',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Toggle
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: _iosKeepAliveActive,
                onChanged: _toggleIOSKeepAlive,
                title: Text(
                  _iosKeepAliveActive ? 'Keep-Alive ON' : 'Keep-Alive OFF',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _iosKeepAliveActive
                      ? 'App will stay awake for block production'
                      : 'Enable when you have upcoming slots',
                  style: TextStyle(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            if (_iosKeepAliveActive) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Tips for best results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildTip('Keep app in foreground during slot times'),
              _buildTip('Connect device to charger'),
              _buildTip('Enable Guided Access (triple-click side button)'),
              _buildTip('Set screen brightness to minimum'),
            ],
            // When to use section
            if (!_iosKeepAliveActive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When to enable:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTip('You have slots coming up in the next few hours'),
                    _buildTip('You can keep the device plugged in'),
                    _buildTip('Missing a slot would be costly'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Optimization',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Why this matters explanation
            Text(
              'Why this matters:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Android\'s battery saver can delay or skip alarms to save power. Disabling battery optimization for this app ensures your wake-up alarms fire on time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Impact comparison
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impact of battery optimization:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enabled: Alarms may be delayed 1-60 seconds, or skipped entirely',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Disabled: Alarms fire precisely when scheduled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _batteryOptDisabled
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _batteryOptDisabled
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _batteryOptDisabled ? Icons.check_circle : Icons.warning,
                    size: 20,
                    color: _batteryOptDisabled ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _batteryOptDisabled
                          ? 'Battery optimization disabled (recommended)'
                          : 'Battery optimization enabled - may affect reliability',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _batteryOptDisabled
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_batteryOptDisabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openBatterySettings,
                icon: const Icon(Icons.settings),
                label: Text(
                    AppLocalizations.of(context).bgProdOpenBatterySettings),
              ),
            ],
            if (_deviceManufacturer != null &&
                ['xiaomi', 'samsung', 'oppo', 'oneplus']
                    .contains(_deviceManufacturer!.toLowerCase())) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_deviceManufacturer Device Detected',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_deviceManufacturer devices have aggressive battery management that may kill apps even with optimization disabled. You may need to configure additional settings in your device\'s battery manager.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
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

  Widget _buildAndroidKeepAliveSection(
      ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Persistent Foreground Mode',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                // Reliability badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '100%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // How it works
            Text(
              'How it works:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Runs a continuous foreground service with a persistent notification. Android is prohibited from killing foreground services, ensuring the app is always ready to produce blocks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Battery and recommendation info
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.battery_3_bar,
                    '~5-10%/hr',
                    'Battery',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.verified,
                    'Critical use',
                    'Best for',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trade-off comparison
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode comparison:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '90-95%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Default: Event-driven, minimal battery drain',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '100%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Persistent: Guaranteed, higher battery usage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Toggle
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: _androidKeepAliveActive,
                onChanged: _toggleAndroidKeepAlive,
                title: Text(
                  _androidKeepAliveActive ? 'Keep-Alive ON' : 'Keep-Alive OFF',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _androidKeepAliveActive
                      ? 'Persistent foreground service running'
                      : 'Enable for guaranteed block production',
                  style: TextStyle(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            if (_androidKeepAliveActive) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Tips for best results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildTip('Connect device to charger for extended use'),
              _buildTip('Battery optimization should be disabled'),
              _buildTip('A persistent notification will be shown'),
            ],
          ],
        ),
      ),
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

  Future<void> _toggleAndroidKeepAlive(bool value) async {
    if (value) {
      final success =
          await AndroidForegroundKeepAliveService.instance.startKeepAlive();
      if (success && mounted) {
        setState(() => _androidKeepAliveActive = true);
      }
    } else {
      await AndroidForegroundKeepAliveService.instance.stopKeepAlive();
      if (mounted) {
        setState(() => _androidKeepAliveActive = false);
      }
    }
  }
}
