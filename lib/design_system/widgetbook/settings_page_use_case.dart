import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../features/settings/widgets/build_info_sheet.dart';
import '../../features/settings/widgets/faq_section.dart';
import '../../features/settings/widgets/general_settings_section.dart';
import '../../features/settings/widgets/quick_settings_panel.dart';
import '../../features/settings/widgets/theme_picker_sheet.dart';
import '../src/bottom_nav.dart';
import '../src/nav_indicator_shapes.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent settingsPageComponent() {
  return WidgetbookComponent(
    name: 'Settings',
    useCases: [
      _playground(),
      _quickSettingsStates(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Use case 1 — Full page playground with knobs
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      // Quick Settings knobs
      final platform = context.knobs.object.dropdown<TargetPlatform>(
        label: 'Platform',
        options: [TargetPlatform.android, TargetPlatform.iOS],
        initialOption: TargetPlatform.android,
        labelBuilder: (p) => p == TargetPlatform.android ? 'Android' : 'iOS',
      );
      final hasPermissions = context.knobs.boolean(
        label: 'Has permissions',
        initialValue: true,
      );
      final batteryOptDisabled = context.knobs.boolean(
        label: 'Battery opt disabled (Android)',
        initialValue: true,
      );
      final iosKeepAliveActive = context.knobs.boolean(
        label: 'iOS keep-alive active',
        initialValue: false,
      );
      final showManufacturerWarning = context.knobs.boolean(
        label: 'Aggressive manufacturer (Android)',
        initialValue: false,
      );

      // General Settings knobs
      final themeMode = context.knobs.object.dropdown<ThemeMode>(
        label: 'Theme mode',
        options: ThemeMode.values,
        initialOption: ThemeMode.system,
        labelBuilder: (m) => m.name,
      );

      return _SettingsPage(
        hasPermissions: hasPermissions,
        batteryOptDisabled: batteryOptDisabled,
        iosKeepAliveActive: iosKeepAliveActive,
        platformOverride: platform,
        deviceManufacturer: showManufacturerWarning ? 'Xiaomi' : null,
        themeMode: themeMode,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — All Quick Settings states side by side
// ---------------------------------------------------------------------------

WidgetbookUseCase _quickSettingsStates() {
  return WidgetbookUseCase(
    name: 'Quick Settings States',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      Widget label(String text) => Padding(
            padding: EdgeInsets.only(bottom: spacing.space8),
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Android states
            label('ALL GOOD \u2014 ANDROID'),
            QuickSettingsPanel(
              hasPermissions: true,
              batteryOptDisabled: true,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.android,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('PERMISSION DENIED \u2014 ANDROID'),
            QuickSettingsPanel(
              hasPermissions: false,
              batteryOptDisabled: true,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.android,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('BATTERY OPT ENABLED \u2014 ANDROID'),
            QuickSettingsPanel(
              hasPermissions: true,
              batteryOptDisabled: false,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.android,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('BOTH ISSUES \u2014 ANDROID'),
            QuickSettingsPanel(
              hasPermissions: false,
              batteryOptDisabled: false,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.android,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('AGGRESSIVE MANUFACTURER \u2014 ANDROID'),
            QuickSettingsPanel(
              hasPermissions: true,
              batteryOptDisabled: true,
              iosKeepAliveActive: false,
              deviceManufacturer: 'Xiaomi',
              platformOverride: TargetPlatform.android,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            // iOS states
            label('ALL GOOD + KEEP-ALIVE \u2014 iOS'),
            QuickSettingsPanel(
              hasPermissions: true,
              batteryOptDisabled: true,
              iosKeepAliveActive: true,
              platformOverride: TargetPlatform.iOS,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('KEEP-ALIVE OFF \u2014 iOS'),
            QuickSettingsPanel(
              hasPermissions: true,
              batteryOptDisabled: true,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.iOS,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space24),

            label('NOTIFICATION DENIED \u2014 iOS'),
            QuickSettingsPanel(
              hasPermissions: false,
              batteryOptDisabled: true,
              iosKeepAliveActive: false,
              platformOverride: TargetPlatform.iOS,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),
            SizedBox(height: spacing.space32),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Full settings page composition
// ---------------------------------------------------------------------------

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.hasPermissions,
    required this.batteryOptDisabled,
    required this.iosKeepAliveActive,
    required this.platformOverride,
    required this.themeMode,
    this.deviceManufacturer,
  });

  final bool hasPermissions;
  final bool batteryOptDisabled;
  final bool iosKeepAliveActive;
  final TargetPlatform platformOverride;
  final String? deviceManufacturer;
  final ThemeMode themeMode;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  int _navIndex = 4;

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
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ThemePickerSheet(
        currentMode: widget.themeMode,
        onChanged: (_) => Navigator.of(context).pop(),
      ),
    );
  }

  void _showBuildInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BuildInfoSheet(
        info: BuildInfo(
          appVersion: '1.2.3',
          buildNumber: '42',
          nodeVersion: '0.8.1',
          commitHash: 'abc1234',
          branch: 'main',
          commitTime: '2025-03-01 12:00:00',
          rustcVersion: '1.78.0',
          rustcChannel: 'stable',
          llvmVersion: '18.1.2',
          cargoTarget: 'aarch64-linux-android',
          cargoFeatures: 'default',
          cargoOptLevel: '3',
          cargoIsDebug: 'false',
        ),
        localizations: BuildInfoLocalizations(
          title: 'Build Info',
          version: 'Version',
          commit: 'Commit',
          branch: 'Branch',
          commitTime: 'Commit Time',
          rustc: 'Rustc',
          llvm: 'LLVM',
          cargoTarget: 'Cargo Target',
          features: 'Features',
          optLevel: 'Opt Level',
          debug: 'Debug',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          children: [
            SizedBox(height: spacing.space16),

            // Tier 1: Quick Settings Panel
            QuickSettingsPanel(
              hasPermissions: widget.hasPermissions,
              batteryOptDisabled: widget.batteryOptDisabled,
              iosKeepAliveActive: widget.iosKeepAliveActive,
              deviceManufacturer: widget.deviceManufacturer,
              platformOverride: widget.platformOverride,
              onRequestPermissions: () {},
              onOpenBatterySettings: () {},
              onToggleKeepAlive: (_) {},
            ),

            SizedBox(height: spacing.space24),

            // Tier 2: General Settings
            GeneralSettingsSection(
              currentThemeLabel: _themeModeLabel(widget.themeMode),
              buildInfoSubtitle: 'v1.2.3 \u00b7 abc1234',
              onAppearanceTap: _showThemePicker,
              onBuildInfoTap: _showBuildInfo,
              onBuildInfoLongPress: () {},
            ),

            SizedBox(height: spacing.space24),

            // Tier 3: Help & Info
            FaqSection(
              deviceManufacturer: widget.deviceManufacturer,
              localizations: const FaqLocalizations(
                whatIsTitle: 'How Block Production Works',
                whatIsDescription:
                    'Your device participates in a decentralized block production process.',
                step1Title: 'VRF Selection',
                step1Desc:
                    'At each epoch start, the network uses VRF to fairly select block producers.',
                step2Title: 'Slot Scheduling',
                step2Desc:
                    'Your device schedules alarms for each assigned slot.',
                step3Title: 'Block Production',
                step3Desc:
                    'When the alarm fires, your device wakes up and produces the block.',
                step4Title: 'Success Tracking',
                step4Desc:
                    'The network records whether each block was produced successfully.',
                platformAndroidTitle: 'Android Reliability',
                platformIosTitle: 'iOS Reliability',
                platformAndroidDesc:
                    'Android uses exact alarms that fire even in Doze mode.',
                platformIosDesc:
                    'iOS requires the app to remain in the foreground for reliable timing.',
                reliabilityByMode: 'Reliability by mode',
                defaultMode: 'Default (Exact Alarms)',
                defaultReliability: '~95%',
                defaultDesc: 'Uses Android exact alarm API',
                keepAliveMode: 'Keep-Alive Mode',
                keepAliveReliability: '~98%',
                keepAliveDesc: 'Foreground service with wake lock',
                iosKeepAliveReliability: '~99%',
                iosKeepAliveDesc: 'Screen stays on at minimum brightness',
                backgroundOnly: 'Background Only',
                backgroundOnlyReliability: '~60%',
                backgroundOnlyDesc: 'iOS may suspend the app at any time',
              ),
            ),

            SizedBox(height: spacing.space32),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        items: [
          BottomNavItem(
            icon: Symbols.cards_star_sharp,
            label: 'Challenges',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.account_balance_wallet_sharp,
            label: 'Wallet',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.action_key_sharp,
            label: 'Apps',
            indicatorShape: NavIndicatorShape.blob,
            indicatorColor: semantic.community.color,
            indicatorFillColor: semantic.community.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.check_circle_sharp,
            label: 'Node',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.settings_sharp,
            label: 'Settings',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
        ],
        selectedIndex: _navIndex,
        onItemSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}
