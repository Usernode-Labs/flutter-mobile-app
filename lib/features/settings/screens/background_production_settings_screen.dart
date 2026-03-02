import 'dart:async';
import 'dart:io';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/ios_foreground_keepalive_service.dart';
import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

final _log =
    LoggingService.instance.withTag('usernode/BackgroundProductionSettings');

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
  bool _active = false; // active when Settings tab is selected (index 4)

  // Package info (app version)
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    // Run initialization in background without blocking UI
    _checkStatus();
    _loadPackageInfo();

    // Determine initial active state and maybe start timer
    _active = _isActiveTab();
    if (_active) _startTimer();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  bool _isActiveTab() {
    try {
      return ref.read(currentHomeTabProvider) == 4;
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

  // Network switcher methods
  void _onVersionLongPress() {
    _showPinDialog();
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '4-digit code',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == AppConfig.networkSwitcherCode) {
                Navigator.of(ctx).pop(true);
              } else {
                Navigator.of(ctx).pop(false);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showNetworkSwitcherDialog();
    }
  }

  Future<void> _showNetworkSwitcherDialog() async {
    final prefs = await SharedPreferences.getInstance();
    const allowedNetworks = {'testnet', 'internal', 'custom'};
    final storedNetwork = prefs.getString('network:type');
    final currentNetwork =
        allowedNetworks.contains(storedNetwork) ? storedNetwork! : 'testnet';

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _NetworkSwitcherDialog(
        currentNetwork: currentNetwork,
      ),
    );

    if (result != null && result != currentNetwork && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('network:type', result);
      _showRestartDialog(result);
    }
  }

  String _networkLabel(String network) {
    switch (network) {
      case 'internal':
        return 'Internal';
      case 'custom':
        return 'Custom';
      case 'testnet':
      default:
        return 'Testnet';
    }
  }

  Future<void> _showRestartDialog(String network) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Required'),
        content: Text(
          'Network switched to ${_networkLabel(network)}. '
          '${Platform.isIOS ? 'Please manually close and reopen the app to connect to the new network.' : 'The app will now close. Please reopen it to connect to the new network.'}',
        ),
        actions: [
          if (Platform.isIOS)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                SystemNavigator.pop();
              },
              child: const Text('Close App'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkStatus,
          child: ListView(
            padding: EdgeInsets.all(spacing.space16),
            children: [
              // Keep About collapsed but place it first
              _buildAboutSection(theme, colorScheme),
              SizedBox(height: spacing.space8),
              // Top-priority sections
              _buildPermissionsSection(theme, colorScheme),
              SizedBox(height: spacing.space8),
              if (Platform.isIOS) ...[
                _buildIOSKeepAliveSection(theme, colorScheme),
                SizedBox(height: spacing.space8),
              ],
              if (Platform.isAndroid) ...[
                _buildAndroidBatterySection(theme, colorScheme),
                SizedBox(height: spacing.space8),
                _buildThemeSection(theme, colorScheme),
                SizedBox(height: spacing.space8),
              ],
              if (!Platform.isAndroid) ...[
                _buildThemeSection(theme, colorScheme),
                SizedBox(height: spacing.space8),
              ],

              // Collapsible sections (collapsed by default)
              _buildFeatureOverviewCard(theme, colorScheme),
              SizedBox(height: spacing.space8),
              _buildPlatformInfoCard(theme, colorScheme),
              SizedBox(height: spacing.space8),
              _buildVrfExplanationCard(theme, colorScheme),
              SizedBox(height: spacing.space8),

              // Build Info section (at the bottom)
              _buildBuildInfoCard(theme, colorScheme),
              SizedBox(height: spacing.space32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(ThemeData theme, ColorScheme colorScheme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final themeMode = ref.watch(themeModeProvider);

    void setTheme(ThemeMode mode) {
      ref.read(themeModeProvider.notifier).set(mode);
    }

    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: 'Appearance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: themeMode,
            title: Text(
              'Use system setting',
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Automatically follow your device\'s light or dark mode.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onChanged: (mode) {
              if (mode != null) setTheme(mode);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme, ColorScheme colorScheme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    const aboutText =
        'Your device is part of a new network. It verifies, executes, and contributes compute directly to the network, passively in the background - with no central servers, no hidden infra. As long as users keep the app running, the network will continue to operate, peer to peer, with no external dependencies.\n\n'
        'We\'re doing this to enable networks that can be hosted end-to-end by their own communities - both for decentralization, and to enable a natural coordination point around participation, where users who help operate and contribute to systems directly realize the benefits from it.\n\n'
        'Right now we are in testnet as we validate the core layer: block production, consensus behavior, and network reliability. As these stabilize, we\'ll build upon the unique features of the platform - its decentralization, zero knowledge proofs, and sybil-resistant identity - to introduce new activities, coordination mechanisms, and tools for self-hosted, sybil-resistant communities.\n\n'
        'Thanks for helping test at this early stage. The app right now is simple, but as we prove out the core functionality, we hope to make possible a new kind of community-owned network, where users can directly run and benefit from the networks they use.';

    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: 'About',
      preview: Text(
        'Your device is part of a new network. It verifies, executes, and contributes compute...',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          Text(
            aboutText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildInfoCard(ThemeData theme, ColorScheme colorScheme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final env = ref.read(buildEnvProvider);
    final l10n = AppLocalizations.of(context);
    final shortCommit = env.git.commitHash.length >= 7
        ? env.git.commitHash.substring(0, 7)
        : env.git.commitHash;

    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: l10n.settingsBuildInfo,
      preview: Row(
        children: [
          if (_packageInfo != null) ...[
            Text(
              'v${_packageInfo!.version}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontFamily: 'monospace',
              ),
            ),
            Text(
              ' • ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          Text(
            shortCommit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          // App version and build number
          if (_packageInfo != null) ...[
            GestureDetector(
              onLongPress: _onVersionLongPress,
              behavior: HitTestBehavior.opaque,
              child: _buildInfoRow(
                  'App Version', _packageInfo!.version, theme, colorScheme),
            ),
            _buildInfoRow(
                'Build Number', _packageInfo!.buildNumber, theme, colorScheme),
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.space8),
              child: const Divider(height: 1),
            ),
          ],
          // Node/Rust version
          _buildInfoRow(l10n.buildInfoVersion, env.version, theme, colorScheme),
          _buildInfoRow(l10n.buildInfoCommit, shortCommit, theme, colorScheme),
          _buildInfoRow(
              l10n.buildInfoBranch, env.git.branch, theme, colorScheme),
          _buildInfoRow(
              l10n.buildInfoCommitTime, env.git.commitTime, theme, colorScheme),
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.space8),
            child: const Divider(height: 1),
          ),
          _buildInfoRow(
              l10n.buildInfoRustc,
              '${env.rustc.version} (${env.rustc.channel})',
              theme,
              colorScheme),
          _buildInfoRow(
              l10n.buildInfoLlvm, env.rustc.llvmVersion, theme, colorScheme),
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.space8),
            child: const Divider(height: 1),
          ),
          _buildInfoRow(
              l10n.buildInfoCargoTarget, env.cargo.target, theme, colorScheme),
          _buildInfoRow(
              l10n.buildInfoFeatures, env.cargo.features, theme, colorScheme),
          _buildInfoRow(l10n.buildInfoOptLevel, env.cargo.optLevel.toString(),
              theme, colorScheme),
          _buildInfoRow(l10n.buildInfoDebug, env.cargo.isDebug.toString(),
              theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, ThemeData theme, ColorScheme colorScheme) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space4),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: l10n.bgProdWhatIs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          Text(
            l10n.bgProdDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          SizedBox(height: spacing.space16),
          _buildNumberedStep(
            '1',
            l10n.bgProdVrfSelection,
            l10n.bgProdVrfSelectionDesc,
            colorScheme,
          ),
          SizedBox(height: spacing.space12),
          _buildNumberedStep(
            '2',
            l10n.bgProdSlotScheduling,
            l10n.bgProdSlotSchedulingDesc,
            colorScheme,
          ),
          SizedBox(height: spacing.space12),
          _buildNumberedStep(
            '3',
            l10n.bgProdBlockProduction,
            l10n.bgProdBlockProductionDesc,
            colorScheme,
          ),
          SizedBox(height: spacing.space12),
          _buildNumberedStep(
            '4',
            l10n.bgProdSuccessTracking,
            l10n.bgProdSuccessTrackingDesc,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedStep(
    String number,
    String title,
    String description,
    ColorScheme colorScheme,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
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
        SizedBox(width: spacing.space12),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;

    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: isAndroid ? l10n.bgProdAndroidTitle : l10n.bgProdIosTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          Text(
            isAndroid ? l10n.bgProdAndroidDesc : l10n.bgProdIosDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.space16),
          // Reliability breakdown
          Container(
            padding: EdgeInsets.all(spacing.space12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                SizedBox(height: spacing.space12),
                if (isAndroid) ...[
                  _buildReliabilityRow(
                    l10n.bgProdDefaultMode,
                    l10n.bgProdDefaultReliability,
                    l10n.bgProdDefaultDesc,
                    Colors.green,
                  ),
                  SizedBox(height: spacing.space8),
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
                  SizedBox(height: spacing.space8),
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
            SizedBox(height: spacing.space12),
            Row(
              children: [
                Icon(
                  Symbols.smartphone_sharp,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                SizedBox(width: spacing.space8),
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
    );
  }

  Widget _buildReliabilityRow(
    String mode,
    String percentage,
    String description,
    Color color,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: spacing.space8, vertical: spacing.space4),
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
        SizedBox(width: spacing.space12),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return _buildCollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: 'Understanding VRF & Slots',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space4),
          // What is VRF
          Text(
            'What is VRF?',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.space8),
          Text(
            'VRF (Verifiable Random Function) is how the network fairly selects block producers. At the start of each epoch, the network runs VRF calculations to determine which validators will produce blocks in upcoming slots.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          SizedBox(height: spacing.space16),
          // VRF Status meanings
          Text(
            'VRF Status Meanings',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.space8),
          _buildStatusExplanation(
            'Pending',
            'Waiting for epoch transition to start calculations',
            Colors.grey,
            colorScheme,
          ),
          SizedBox(height: spacing.space8),
          _buildStatusExplanation(
            'Calculating',
            'VRF evaluation in progress (takes a few hours)',
            Colors.orange,
            colorScheme,
          ),
          SizedBox(height: spacing.space8),
          _buildStatusExplanation(
            'Complete',
            'Slot assignments are finalized and scheduled',
            Colors.green,
            colorScheme,
          ),
          SizedBox(height: spacing.space16),
          // What is a won slot
          Text(
            'What is a "Won Slot"?',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.space8),
          Text(
            'When VRF selects your node to produce a block at a specific time, you\'ve "won" that slot. Your responsibility is to have your device awake and connected so the block can be produced.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          SizedBox(height: spacing.space16),
          // Why timing matters
          Container(
            padding: EdgeInsets.all(spacing.space12),
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
                  Symbols.timer_sharp,
                  size: 20,
                  color: Colors.amber.shade700,
                ),
                SizedBox(width: spacing.space12),
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
                      SizedBox(height: spacing.space4),
                      Text(
                        'Each slot has a ~5-seconds window. If your device doesn\'t wake up in time or loses network connectivity, the slot is missed and counted as "failed."',
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
    );
  }

  Widget _buildCollapsibleCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String title,
    required Widget child,
    String? subtitle,
    Widget? preview,
  }) {
    return _CollapsibleCard(
      theme: theme,
      colorScheme: colorScheme,
      title: title,
      subtitle: subtitle,
      preview: preview,
      child: child,
    );
  }

  Widget _buildStatusExplanation(
    String status,
    String description,
    Color color,
    ColorScheme colorScheme,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(top: spacing.space8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: spacing.space12),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final isAndroid = Platform.isAndroid;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            spacing.space16, spacing.space12, spacing.space16, spacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.space12),
            // Why needed explanation
            Text(
              isAndroid
                  ? 'Why exact alarms are required:'
                  : 'Why notifications are required:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.space8),
            Text(
              isAndroid
                  ? 'Android restricts apps from waking the device at precise times unless explicitly allowed. Without this permission, alarms may be delayed by up to 10 minutes, causing missed slots.'
                  : 'Notifications alert you when a slot is approaching, giving you time to open the app and enable keep-alive mode for reliable production.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            SizedBox(height: spacing.space16),
            // Status indicator
            Container(
              padding: EdgeInsets.all(spacing.space12),
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
                    _hasPermissions
                        ? Symbols.check_circle_sharp
                        : Symbols.warning_sharp,
                    size: 20,
                    color: _hasPermissions ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: spacing.space12),
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
              SizedBox(height: spacing.space12),
              FilledButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Symbols.settings_sharp),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            spacing.space16, spacing.space12, spacing.space16, spacing.space12),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.space8,
                    vertical: spacing.space4,
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
            SizedBox(height: spacing.space12),
            // How it works
            Text(
              'How it works:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: spacing.space4),
            Text(
              'This mode prevents iOS from suspending the app by maintaining an active wake lock. The screen stays on (at minimum brightness) and the app continuously monitors for upcoming slots.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            SizedBox(height: spacing.space12),
            // Battery and recommendation info
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Symbols.battery_3_bar_sharp,
                    '~3-5%/hr',
                    'Battery',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: spacing.space8),
                Expanded(
                  child: _buildInfoChip(
                    Symbols.star_sharp,
                    'Critical slots',
                    'Best for',
                    colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space16),
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
              SizedBox(height: spacing.space16),
              const Divider(height: 1),
              SizedBox(height: spacing.space12),
              Text(
                'Tips for best results:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.space8),
              _buildTip('Keep app in foreground during slot times'),
              _buildTip('Connect device to charger'),
              _buildTip('Enable Guided Access (triple-click side button)'),
              _buildTip('Set screen brightness to minimum'),
            ],
            // When to use section
            if (!_iosKeepAliveActive) ...[
              SizedBox(height: spacing.space16),
              Container(
                padding: EdgeInsets.all(spacing.space12),
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
                    SizedBox(height: spacing.space8),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      padding: EdgeInsets.all(spacing.space8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
          SizedBox(width: spacing.space8),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Padding(
      padding: EdgeInsets.only(left: spacing.space8, top: spacing.space4),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            spacing.space16, spacing.space12, spacing.space16, spacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Optimization',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.space12),
            // Why this matters explanation
            Text(
              'Why this matters:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: spacing.space8),
            Text(
              'Android\'s battery saver can delay or skip alarms to save power. Disabling battery optimization for this app ensures your wake-up alarms fire on time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            SizedBox(height: spacing.space16),
            // Impact comparison
            Container(
              padding: EdgeInsets.all(spacing.space12),
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
                  SizedBox(height: spacing.space8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Symbols.warning_amber_sharp,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      SizedBox(width: spacing.space8),
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
                  SizedBox(height: spacing.space8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Symbols.check_circle_sharp,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(width: spacing.space8),
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
            SizedBox(height: spacing.space16),
            // Status indicator
            Container(
              padding: EdgeInsets.all(spacing.space12),
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
                    _batteryOptDisabled
                        ? Symbols.check_circle_sharp
                        : Symbols.warning_sharp,
                    size: 20,
                    color: _batteryOptDisabled ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: spacing.space12),
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
              SizedBox(height: spacing.space12),
              OutlinedButton.icon(
                onPressed: _openBatterySettings,
                icon: const Icon(Symbols.settings_sharp),
                label: Text(
                    AppLocalizations.of(context).bgProdOpenBatterySettings),
              ),
            ],
            if (_deviceManufacturer != null &&
                ['xiaomi', 'samsung', 'oppo', 'oneplus']
                    .contains(_deviceManufacturer!.toLowerCase())) ...[
              SizedBox(height: spacing.space16),
              Container(
                padding: EdgeInsets.all(spacing.space12),
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
                          Symbols.warning_amber_sharp,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        SizedBox(width: spacing.space8),
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
                    SizedBox(height: spacing.space8),
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

class _CollapsibleCard extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? preview;

  const _CollapsibleCard({
    required this.theme,
    required this.colorScheme,
    required this.title,
    required this.child,
    this.subtitle,
    this.preview,
  });

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceBright,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Theme(
        data: widget.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
              horizontal: spacing.space16, vertical: spacing.space8),
          childrenPadding: EdgeInsets.fromLTRB(
              spacing.space16, 0, spacing.space16, spacing.space16),
          title: Text(
            widget.title,
            style: widget.theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: _buildSubtitle(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedBackgroundColor: widget.colorScheme.surfaceBright,
          backgroundColor: widget.colorScheme.surfaceBright,
          iconColor: widget.colorScheme.onSurfaceVariant,
          collapsedIconColor: widget.colorScheme.onSurfaceVariant,
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          children: [widget.child],
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    if (_isExpanded) {
      // Return empty SizedBox to maintain layout if needed, or null
      return null;
    }

    if (widget.subtitle != null) {
      return Text(
        widget.subtitle!,
        style: widget.theme.textTheme.bodySmall?.copyWith(
          color: widget.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    if (widget.preview != null) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      return Padding(
        padding: EdgeInsets.only(top: spacing.space4),
        child: widget.preview!,
      );
    }

    return null;
  }
}

class _NetworkSwitcherDialog extends StatefulWidget {
  final String currentNetwork;

  const _NetworkSwitcherDialog({required this.currentNetwork});

  @override
  State<_NetworkSwitcherDialog> createState() => _NetworkSwitcherDialogState();
}

class _NetworkSwitcherDialogState extends State<_NetworkSwitcherDialog> {
  late String selectedNetwork;

  @override
  void initState() {
    super.initState();
    selectedNetwork = widget.currentNetwork;
  }

  String _formatUrl(String url) {
    return url.replaceFirst(RegExp(r'^https?://'), '');
  }

  Widget _buildUrlRow(
      String label, String url, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              url,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOption({
    required String networkType,
    required String displayName,
    required String description,
    required bool isSelected,
    required bool isCurrentlyActive,
    required String genesisUrl,
    required String seedlistUrl,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedNetwork = networkType;
        });
      },
      child: Container(
        padding: EdgeInsets.all(spacing.space12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Symbols.radio_button_checked_sharp
                      : Symbols.radio_button_unchecked_sharp,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                SizedBox(width: spacing.space8),
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isCurrentlyActive) ...[
                  SizedBox(width: spacing.space8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: spacing.space4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: spacing.space8),
            _buildUrlRow('Genesis', _formatUrl(genesisUrl), theme, colorScheme),
            SizedBox(height: spacing.space4),
            _buildUrlRow(
                'Seedlist', _formatUrl(seedlistUrl), theme, colorScheme),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Network Switcher'),
          IconButton(
            icon: const Icon(Symbols.close_sharp),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT NETWORK',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: spacing.space12),

            // Testnet Option
            _buildNetworkOption(
              networkType: 'testnet',
              displayName: 'Testnet',
              description: 'Default network',
              isSelected: selectedNetwork == 'testnet',
              isCurrentlyActive: widget.currentNetwork == 'testnet',
              genesisUrl: AppConfig.testnetGenesisUrl,
              seedlistUrl: AppConfig.testnetSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
            ),

            SizedBox(height: spacing.space12),

            // Internal Option
            _buildNetworkOption(
              networkType: 'internal',
              displayName: 'Internal',
              description: 'Development network',
              isSelected: selectedNetwork == 'internal',
              isCurrentlyActive: widget.currentNetwork == 'internal',
              genesisUrl: AppConfig.internalGenesisUrl,
              seedlistUrl: AppConfig.internalSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
            ),

            SizedBox(height: spacing.space12),

            // Custom Option
            _buildNetworkOption(
              networkType: 'custom',
              displayName: 'Custom',
              description: 'static.usernodelabs.org/custom',
              isSelected: selectedNetwork == 'custom',
              isCurrentlyActive: widget.currentNetwork == 'custom',
              genesisUrl: AppConfig.customGenesisUrl,
              seedlistUrl: AppConfig.customSeedlistUrl,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedNetwork == widget.currentNetwork
              ? null
              : () => Navigator.of(context).pop(selectedNetwork),
          child: Text(selectedNetwork == widget.currentNetwork
              ? 'No Change'
              : 'Switch Network'),
        ),
      ],
    );
  }
}
