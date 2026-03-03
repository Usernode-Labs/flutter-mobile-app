import 'dart:async';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/settings/widgets/quick_settings_panel.dart';
import 'package:crypto_mobile_app/features/settings/widgets/general_settings_section.dart';
import 'package:crypto_mobile_app/features/settings/widgets/faq_section.dart';
import 'package:crypto_mobile_app/features/settings/widgets/theme_picker_sheet.dart';
import 'package:crypto_mobile_app/features/settings/widgets/build_info_sheet.dart';
import 'package:crypto_mobile_app/features/settings/widgets/network_switcher_dialog.dart';

final _log =
    LoggingService.instance.withTag('usernode/BackgroundProductionSettings');

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPermissions = false;
  bool _batteryOptDisabled = false;
  String? _deviceManufacturer;
  bool _iosKeepAliveActive = false;
  Timer? _autoTimer;
  bool _refreshing = false;
  bool _active = false;

  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadPackageInfo();
    _active = _isActiveTab();
    if (_active) _startTimer();

    // React to tab changes and start/stop the refresh timer.
    ref.listenManual(currentHomeTabProvider, (_, next) {
      final shouldBeActive = next == 4;
      if (shouldBeActive != _active) {
        _active = shouldBeActive;
        shouldBeActive ? _startTimer() : _stopTimer();
      }
    });
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
      await PlatformAlarmService.instance.initialize();
      await EpochSlotSchedulerService.instance.initialize();
      await SlotProductionRepository.instance.initialize();

      if (!mounted) return;

      final hasPermissions = PlatformAlarmService.instance.hasPermissions;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final batteryOptDisabled =
            await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
        final deviceManufacturer =
            await PlatformAlarmService.instance.getDeviceManufacturer();

        if (mounted) {
          setState(() {
            _hasPermissions = hasPermissions;
            _batteryOptDisabled = batteryOptDisabled;
            _deviceManufacturer = deviceManufacturer;
          });
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosKeepAliveActive =
            IOSForegroundKeepAliveService.instance.isActive;

        if (mounted) {
          setState(() {
            _hasPermissions = hasPermissions;
            _iosKeepAliveActive = iosKeepAliveActive;
          });
        }
      }

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

  // --- Permission / service actions ---

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

  // --- Theme picker ---

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker() {
    final themeMode = ref.read(themeModeProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ThemePickerSheet(
        currentMode: themeMode,
        onChanged: (mode) {
          ref.read(themeModeProvider.notifier).set(mode);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // --- Build info ---

  String _shortCommit(String hash) =>
      hash.length >= 7 ? hash.substring(0, 7) : hash;

  void _showBuildInfo() {
    final env = ref.read(buildEnvProvider);
    final l10n = AppLocalizations.of(context);
    final shortCommit = _shortCommit(env.git.commitHash);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BuildInfoSheet(
        info: BuildInfo(
          appVersion: _packageInfo?.version,
          buildNumber: _packageInfo?.buildNumber,
          nodeVersion: env.version,
          commitHash: shortCommit,
          branch: env.git.branch,
          commitTime: env.git.commitTime,
          rustcVersion: env.rustc.version,
          rustcChannel: env.rustc.channel,
          llvmVersion: env.rustc.llvmVersion,
          cargoTarget: env.cargo.target,
          cargoFeatures: env.cargo.features,
          cargoOptLevel: env.cargo.optLevel.toString(),
          cargoIsDebug: env.cargo.isDebug.toString(),
        ),
        localizations: BuildInfoLocalizations(
          title: l10n.settingsBuildInfo,
          version: l10n.buildInfoVersion,
          commit: l10n.buildInfoCommit,
          branch: l10n.buildInfoBranch,
          commitTime: l10n.buildInfoCommitTime,
          rustc: l10n.buildInfoRustc,
          llvm: l10n.buildInfoLlvm,
          cargoTarget: l10n.buildInfoCargoTarget,
          features: l10n.buildInfoFeatures,
          optLevel: l10n.buildInfoOptLevel,
          debug: l10n.buildInfoDebug,
        ),
      ),
    );
  }

  // --- Network switcher (hidden easter egg) ---

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
      builder: (ctx) => NetworkSwitcherDialog(
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
          '${defaultTargetPlatform == TargetPlatform.iOS ? 'Please manually close and reopen the app to connect to the new network.' : 'The app will now close. Please reopen it to connect to the new network.'}',
        ),
        actions: [
          if (defaultTargetPlatform == TargetPlatform.iOS)
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

  // --- Build info subtitle ---

  String get _buildInfoSubtitle {
    final env = ref.read(buildEnvProvider);
    final sc = _shortCommit(env.git.commitHash);
    if (_packageInfo != null) {
      return 'v${_packageInfo!.version} \u00b7 $sc';
    }
    return sc;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkStatus,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            children: [
              SizedBox(height: spacing.space16),

              // Tier 1: Quick Settings Panel
              QuickSettingsPanel(
                hasPermissions: _hasPermissions,
                batteryOptDisabled: _batteryOptDisabled,
                iosKeepAliveActive: _iosKeepAliveActive,
                deviceManufacturer: _deviceManufacturer,
                onRequestPermissions: _requestPermissions,
                onOpenBatterySettings: _openBatterySettings,
                onToggleKeepAlive: _toggleIOSKeepAlive,
              ),

              SizedBox(height: spacing.space24),

              // Tier 2: General Settings
              GeneralSettingsSection(
                currentThemeLabel: _themeModeLabel(themeMode),
                buildInfoSubtitle: _buildInfoSubtitle,
                onAppearanceTap: _showThemePicker,
                onBuildInfoTap: _showBuildInfo,
                onBuildInfoLongPress: _onVersionLongPress,
              ),

              SizedBox(height: spacing.space24),

              // Tier 3: Help & Info
              FaqSection(
                deviceManufacturer: _deviceManufacturer,
                localizations: FaqLocalizations(
                  whatIsTitle: l10n.bgProdWhatIs,
                  whatIsDescription: l10n.bgProdDescription,
                  step1Title: l10n.bgProdVrfSelection,
                  step1Desc: l10n.bgProdVrfSelectionDesc,
                  step2Title: l10n.bgProdSlotScheduling,
                  step2Desc: l10n.bgProdSlotSchedulingDesc,
                  step3Title: l10n.bgProdBlockProduction,
                  step3Desc: l10n.bgProdBlockProductionDesc,
                  step4Title: l10n.bgProdSuccessTracking,
                  step4Desc: l10n.bgProdSuccessTrackingDesc,
                  platformAndroidTitle: l10n.bgProdAndroidTitle,
                  platformIosTitle: l10n.bgProdIosTitle,
                  platformAndroidDesc: l10n.bgProdAndroidDesc,
                  platformIosDesc: l10n.bgProdIosDesc,
                  reliabilityByMode: l10n.bgProdReliabilityByMode,
                  defaultMode: l10n.bgProdDefaultMode,
                  defaultReliability: l10n.bgProdDefaultReliability,
                  defaultDesc: l10n.bgProdDefaultDesc,
                  keepAliveMode: l10n.bgProdKeepAliveMode,
                  keepAliveReliability: l10n.bgProdKeepAliveReliability,
                  keepAliveDesc: l10n.bgProdKeepAliveDesc,
                  iosKeepAliveReliability: l10n.bgProdIosKeepAliveReliability,
                  iosKeepAliveDesc: l10n.bgProdIosKeepAliveDesc,
                  backgroundOnly: l10n.bgProdBackgroundOnly,
                  backgroundOnlyReliability:
                      l10n.bgProdBackgroundOnlyReliability,
                  backgroundOnlyDesc: l10n.bgProdBackgroundOnlyDesc,
                ),
              ),

              SizedBox(height: spacing.space32),
            ],
          ),
        ),
      ),
    );
  }
}
