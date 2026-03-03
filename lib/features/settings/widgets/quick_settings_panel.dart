import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Tier 1: High-priority quick settings panel with semantic Card.
///
/// Shows permission status, platform controls, and battery optimization
/// using semantic colors to communicate system health at a glance.
class QuickSettingsPanel extends StatelessWidget {
  const QuickSettingsPanel({
    super.key,
    required this.hasPermissions,
    required this.batteryOptDisabled,
    required this.iosKeepAliveActive,
    this.deviceManufacturer,
    required this.onRequestPermissions,
    required this.onOpenBatterySettings,
    required this.onToggleKeepAlive,
    this.platformOverride,
  });

  final bool hasPermissions;
  final bool batteryOptDisabled;
  final bool iosKeepAliveActive;
  final String? deviceManufacturer;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenBatterySettings;
  final ValueChanged<bool> onToggleKeepAlive;

  /// Override the platform for testing/widgetbook. When null, uses dart:io.
  final TargetPlatform? platformOverride;

  bool get _isIOS => platformOverride != null
      ? platformOverride == TargetPlatform.iOS
      : defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroid => platformOverride != null
      ? platformOverride == TargetPlatform.android
      : defaultTargetPlatform == TargetPlatform.android;

  bool get _allPermissionsGranted {
    if (_isIOS) return hasPermissions;
    return hasPermissions && batteryOptDisabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;

    final allGood = _allPermissionsGranted;
    final group = allGood ? semantic.success : semantic.warning;

    return Card(
      elevation: 0,
      color: group.colorSurface,
      shape: RoundedRectangleBorder(borderRadius: radii.borderRadiusLarge),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.space16),
              child: _buildHeader(context, allGood, group),
            ),
            SizedBox(height: spacing.space12),
            _buildPermissionTile(context, colorScheme, semantic),
            if (_isIOS) _buildKeepAliveTile(context, colorScheme, semantic),
            if (_isAndroid) ...[
              _buildBatteryTile(context, colorScheme, semantic),
              if (_isAggressiveManufacturer) ...[
                SizedBox(height: spacing.space8),
                _buildManufacturerWarning(context, semantic),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool allGood,
    SemanticColorGroup group,
  ) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions',
          style: theme.textTheme.labelLarge?.copyWith(
            color: group.onColorSurface,
          ),
        ),
        SizedBox(height: spacing.space8),
        Text(
          allGood ? 'All Good' : 'Action Needed',
          style: theme.textTheme.displaySmall?.copyWith(
            color: group.onColorSurface,
            fontFamily: kMonoFontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(
    BuildContext context,
    ColorScheme colorScheme,
    AppSemanticColors semantic,
  ) {
    final group = hasPermissions ? semantic.success : semantic.warning;

    return ListTile(
      leading: IconBadge(
        icon: _isAndroid ? Symbols.alarm_sharp : Symbols.notifications_sharp,
        backgroundColor: group.colorContainer,
        iconColor: group.onColorContainer,
      ),
      title: Text(_isAndroid ? 'Exact Alarms' : 'Notifications'),
      subtitle: Text(
        hasPermissions
            ? 'Granted'
            : _isAndroid
                ? 'Required for precise block timing'
                : 'Required for slot alerts',
      ),
      trailing: hasPermissions
          ? Icon(
              Symbols.check_circle_sharp,
              color: semantic.success.color,
            )
          : Button(
              label: 'Enable',
              size: ButtonSize.small,
              variant: ButtonVariant.primary,
              onTap: onRequestPermissions,
            ),
    );
  }

  Widget _buildKeepAliveTile(
    BuildContext context,
    ColorScheme colorScheme,
    AppSemanticColors semantic,
  ) {
    final group = iosKeepAliveActive ? semantic.success : semantic.warning;

    return SwitchListTile(
      value: iosKeepAliveActive,
      onChanged: onToggleKeepAlive,
      secondary: IconBadge(
        icon: Symbols.screen_lock_portrait_sharp,
        backgroundColor: group.colorContainer,
        iconColor: group.onColorContainer,
      ),
      title: const Text('Foreground Keep-Alive'),
      subtitle: Text(
        iosKeepAliveActive
            ? 'Active \u2014 99% reliability'
            : 'Enable for critical slots',
      ),
    );
  }

  Widget _buildBatteryTile(
    BuildContext context,
    ColorScheme colorScheme,
    AppSemanticColors semantic,
  ) {
    final group = batteryOptDisabled ? semantic.success : semantic.warning;

    return ListTile(
      leading: IconBadge(
        icon: Symbols.battery_saver_sharp,
        backgroundColor: group.colorContainer,
        iconColor: group.onColorContainer,
      ),
      title: const Text('Battery Optimization'),
      subtitle: Text(
        batteryOptDisabled
            ? 'Disabled (recommended)'
            : 'May delay or skip alarms',
      ),
      trailing: batteryOptDisabled
          ? Icon(
              Symbols.check_circle_sharp,
              color: semantic.success.color,
            )
          : Button(
              label: 'Fix',
              size: ButtonSize.small,
              variant: ButtonVariant.primary,
              onTap: onOpenBatterySettings,
            ),
    );
  }

  bool get _isAggressiveManufacturer {
    if (deviceManufacturer == null) return false;
    return ['xiaomi', 'samsung', 'oppo', 'oneplus']
        .contains(deviceManufacturer!.toLowerCase());
  }

  Widget _buildManufacturerWarning(
    BuildContext context,
    AppSemanticColors semantic,
  ) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.warning_amber_sharp,
            size: theme.extension<AppSizing>()!.iconXSmall,
            color: semantic.warning.onColorSurface,
          ),
          SizedBox(width: spacing.space8),
          Expanded(
            child: Text(
              '$deviceManufacturer devices have aggressive battery management '
              'that may kill apps. Check your device\'s battery manager.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: semantic.warning.onColorSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
