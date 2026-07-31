import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
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
import 'package:crypto_mobile_app/features/settings/widgets/diagnostics_settings_section.dart';
import 'package:crypto_mobile_app/features/settings/widgets/faq_section.dart';
import 'package:crypto_mobile_app/features/settings/widgets/legal_settings_section.dart';
import 'package:crypto_mobile_app/features/settings/widgets/theme_picker_sheet.dart';
import 'package:crypto_mobile_app/features/settings/widgets/build_info_sheet.dart';
import 'package:crypto_mobile_app/features/settings/widgets/network_switcher_dialog.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';
import 'package:crypto_mobile_app/features/perf/providers/perf_benchmark_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';

final _log =
    LoggingService.instance.withTag('usernode/BackgroundProductionSettings');

Future<bool> resetChallengeState(WidgetRef ref, BuildContext context) async {
  final reset =
      await ref.read(zkPassportFlowControllerProvider).resetChallengeData();
  if (!reset) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Challenge reset could not be completed. Try again shortly.',
          ),
        ),
      );
    }
    return false;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Challenge state reset')),
    );
  }
  return true;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _appSleepService = AppSleepService.instance;
  bool _hasPermissions = false;
  bool _batteryOptDisabled = false;
  String? _deviceManufacturer;
  bool _iosKeepAliveActive = false;
  Timer? _autoTimer;
  Timer? _longPressTimer;
  bool _refreshing = false;

  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _appSleepService.addListener(_handleAppSleepChanged);
    _checkStatus();
    _loadPackageInfo();
    // Settings is a pushed route (SV shell owns the home): it only exists while
    // visible, so the refresh timer runs for its whole lifetime (sleep aside).
    _startTimer();
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
    _appSleepService.removeListener(_handleAppSleepChanged);
    _autoTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_appSleepService.isSleeping) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appSleepService.isSleeping) return;
      if (mounted && !_refreshing) {
        _checkStatus();
      }
    });
  }

  void _stopTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  void _handleAppSleepChanged() {
    if (!mounted) return;
    if (_appSleepService.isSleeping) {
      _stopTimer();
      return;
    }

    _startTimer();
    unawaited(_checkStatus());
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

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? l10n.settingsPermGrantedSnackbar
              : l10n.settingsPermDeniedSnackbar,
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
    final l10n = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
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
          appVersion: l10n.buildInfoAppVersion,
          buildNumber: l10n.buildInfoBuildNumber,
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
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.networkEnterCode),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.networkCodeHint,
            counterText: '',
          ),
        ),
        actions: [
          Button(
            label: l10n.commonCancel,
            size: ButtonSize.small,
            variant: ButtonVariant.outlined,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          Button(
            label: l10n.commonOk,
            size: ButtonSize.small,
            onTap: () {
              if (pinController.text == AppConfig.networkSwitcherCode) {
                Navigator.of(ctx).pop(true);
              } else {
                Navigator.of(ctx).pop(false);
              }
            },
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
    final l10n = AppLocalizations.of(context);
    final networkName = _networkLabel(network);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.networkRestartRequired),
        content: Text(
          defaultTargetPlatform == TargetPlatform.iOS
              ? l10n.networkSwitchedRestartIos(networkName)
              : l10n.networkSwitchedRestartAndroid(networkName),
        ),
        actions: [
          if (defaultTargetPlatform == TargetPlatform.iOS)
            Button(
              label: l10n.commonOk,
              size: ButtonSize.small,
              onTap: () {
                Navigator.of(ctx).pop();
              },
            )
          else
            Button(
              label: l10n.networkCloseApp,
              size: ButtonSize.small,
              variant: ButtonVariant.primary,
              onTap: () {
                Navigator.of(ctx).pop();
                SystemNavigator.pop();
              },
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

  Future<void> _resetChallengeState() async {
    await resetChallengeState(ref, context);
  }

  Future<void> _confirmAndLogout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsLogOutConfirmTitle),
        content: Text(l10n.settingsLogOutConfirmMessage),
        actions: [
          Button(
            label: l10n.commonCancel,
            size: ButtonSize.small,
            variant: ButtonVariant.outlined,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          Button(
            label: l10n.settingsLogOut,
            size: ButtonSize.small,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // logout() flips authStatus to unauthenticated; the router redirect guard
    // then sends the user to the auth landing.
    await ref.read(identityProvider.notifier).logout();
  }

  Future<void> _toggleAppSleep(bool value) async {
    await _appSleepService.setEnabled(value);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final terms = ref.watch(currentTermsProvider);
    final termsStatus = terms.when(
      data: (snapshot) => snapshot?.terms?.consent?.accepted ?? false
          ? l10n.settingsTermsAccepted
          : l10n.settingsTermsNotAccepted,
      loading: () => l10n.settingsTermsStatusLoading,
      error: (_, __) => l10n.termsUnavailable,
    );

    final authStatus = ref.watch(authStatusProvider);
    final themeMode = ref.watch(themeModeProvider);
    final debugModeEnabled = ref.watch(debugModeProvider);
    final zkSettings = ref.watch(zkPassportSettingsProvider);
    final perfState = ref.watch(perfBenchmarkProvider);
    final facematchStrict =
        zkSettings.whenOrNull(data: (s) => s.facematchStrict) ?? true;
    final appSleepEnabled = _appSleepService.isEnabled;
    final hasCurrentBenchmarkRun = perfState.isStartingRun ||
        perfState.isRunning ||
        (perfState.activeRunId != null && !perfState.hasFinishedRun);

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
                appSleepEnabled: appSleepEnabled,
                onAppearanceTap: _showThemePicker,
                onAppSleepChanged: _toggleAppSleep,
                onBuildInfoTap: _showBuildInfo,
                onBuildInfoLongPress: _onVersionLongPress,
              ),

              SizedBox(height: spacing.space24),

              DiagnosticsSettingsSection(
                onDeviceBenchmarkTap: () => context.push(
                  hasCurrentBenchmarkRun
                      ? AppRoutes.deviceBenchmarkRun
                      : AppRoutes.deviceBenchmark,
                ),
                debugModeEnabled: debugModeEnabled,
                onDebugModeChanged: (value) =>
                    ref.read(debugModeProvider.notifier).set(value),
                onHttpLogsTap: () => context.push(AppRoutes.httpDebugLogs),
              ),

              SizedBox(height: spacing.space24),

              LegalSettingsSection(
                status: termsStatus,
                onTermsTap: () => context.push(AppRoutes.terms),
              ),

              if (authStatus == AuthStatus.authenticated ||
                  authStatus == AuthStatus.guest) ...[
                SizedBox(height: spacing.space24),
                ListSectionHeader(title: l10n.settingsAccount),
                Card(
                  child: authStatus == AuthStatus.authenticated
                      ? ListTile(
                          leading: Icon(
                            Symbols.logout,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            l10n.settingsLogOut,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          onTap: _confirmAndLogout,
                        )
                      : ListTile(
                          leading: const Icon(Symbols.login),
                          title: Text(l10n.settingsLogIn),
                          onTap: () => context.go(AppRoutes.authLanding),
                        ),
                ),
              ],

              SizedBox(height: spacing.space24),

              // Tier 3: Help & Info
              FaqSection(
                deviceManufacturer: _deviceManufacturer,
                localizations: FaqLocalizations(
                  helpAndInfoTitle: l10n.settingsHelpAndInfo,
                  aboutTitle: l10n.settingsAbout,
                  aboutDescription: l10n.faqAboutDescription,
                  whatIsTitle: l10n.bgProdWhatIs,
                  whatIsDescription: l10n.bgProdDescription,
                  steps: [
                    FaqStep(
                        title: l10n.bgProdVrfSelection,
                        description: l10n.bgProdVrfSelectionDesc),
                    FaqStep(
                        title: l10n.bgProdSlotScheduling,
                        description: l10n.bgProdSlotSchedulingDesc),
                    FaqStep(
                        title: l10n.bgProdBlockProduction,
                        description: l10n.bgProdBlockProductionDesc),
                    FaqStep(
                        title: l10n.bgProdSuccessTracking,
                        description: l10n.bgProdSuccessTrackingDesc),
                  ],
                  platformReliabilityTitle: l10n.faqPlatformReliabilityTitle,
                  platformAndroidDesc: l10n.bgProdAndroidDesc,
                  platformIosDesc: l10n.bgProdIosDesc,
                  reliabilityByMode: l10n.bgProdReliabilityByMode,
                  androidModes: [
                    ReliabilityMode(
                        mode: l10n.bgProdDefaultMode,
                        reliability: l10n.bgProdDefaultReliability,
                        description: l10n.bgProdDefaultDesc),
                    ReliabilityMode(
                        mode: l10n.bgProdKeepAliveMode,
                        reliability: l10n.bgProdKeepAliveReliability,
                        description: l10n.bgProdKeepAliveDesc),
                  ],
                  iosModes: [
                    ReliabilityMode(
                        mode: l10n.bgProdKeepAliveMode,
                        reliability: l10n.bgProdIosKeepAliveReliability,
                        description: l10n.bgProdIosKeepAliveDesc),
                    ReliabilityMode(
                        mode: l10n.bgProdBackgroundOnly,
                        reliability: l10n.bgProdBackgroundOnlyReliability,
                        description: l10n.bgProdBackgroundOnlyDesc),
                  ],
                  deviceLabel: _deviceManufacturer != null
                      ? l10n.faqDeviceLabel(_deviceManufacturer!)
                      : null,
                  vrfSlotsTitle: l10n.faqVrfSlotsTitle,
                  vrfWhatIsTitle: l10n.faqVrfWhatIsTitle,
                  vrfWhatIsDescription: l10n.faqVrfWhatIsDescription,
                  vrfStatusMeaningsTitle: l10n.faqVrfStatusMeaningsTitle,
                  vrfStatusPending: l10n.faqVrfStatusPending,
                  vrfStatusPendingDesc: l10n.faqVrfStatusPendingDesc,
                  vrfStatusCalculating: l10n.faqVrfStatusCalculating,
                  vrfStatusCalculatingDesc: l10n.faqVrfStatusCalculatingDesc,
                  vrfStatusComplete: l10n.faqVrfStatusComplete,
                  vrfStatusCompleteDesc: l10n.faqVrfStatusCompleteDesc,
                  vrfWonSlotTitle: l10n.faqVrfWonSlotTitle,
                  vrfWonSlotDescription: l10n.faqVrfWonSlotDescription,
                  vrfTimingTitle: l10n.faqVrfTimingTitle,
                  vrfTimingDescription: l10n.faqVrfTimingDescription,
                ),
              ),

              SizedBox(height: spacing.space24),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) {
                  _longPressTimer?.cancel();
                  _longPressTimer = Timer(
                    const Duration(seconds: 5),
                    () {
                      if (mounted) context.push(AppRoutes.zkIdentityDetail);
                    },
                  );
                },
                onLongPressEnd: (_) => _longPressTimer?.cancel(),
                onLongPressCancel: () => _longPressTimer?.cancel(),
                child: const ListSectionHeader(title: 'ZK Identity'),
              ),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Symbols.face_sharp),
                      title: const Text('Strict Facematch'),
                      value: facematchStrict,
                      onChanged: (value) {
                        ref
                            .read(zkPassportFlowControllerProvider)
                            .setFacematchStrict(value);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Symbols.restart_alt_sharp),
                      title: const Text('Restart Challenge'),
                      subtitle: Text(
                        'Clears zkPassport registration & cached challenges',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: _resetChallengeState,
                    ),
                  ],
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
