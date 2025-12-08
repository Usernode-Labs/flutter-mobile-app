import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';

final _log = LoggingService.instance.withTag('VersionCheck');

// =============================================================================
// API Response Model
// =============================================================================

enum UpgradeLevel { none, recommended, required }

class VersionCheckResult {
  final UpgradeLevel upgrade;
  final String? details;
  final String? updateUrl;

  const VersionCheckResult({required this.upgrade, this.details, this.updateUrl});

  factory VersionCheckResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const VersionCheckResult(upgrade: UpgradeLevel.none);
    }

    final upgradeValue = data['upgrade'] as int? ?? 0;
    return VersionCheckResult(
      upgrade: UpgradeLevel.values[upgradeValue.clamp(0, 2)],
      details: data['details'] as String?,
      updateUrl: data['update_url'] as String?,
    );
  }

  bool get shouldShowDialog => upgrade != UpgradeLevel.none;
  bool get isBlocking => upgrade == UpgradeLevel.required;
}

// =============================================================================
// Version Check Service
// =============================================================================

class AppVersionCheck {
  AppVersionCheck._();
  static final instance = AppVersionCheck._();

  Timer? _timer;

  /// Check version and return result (null on error = fail open)
  /// Returns null if version check is disabled
  Future<VersionCheckResult?> check() async {
    if (!AppConfig.versionCheckEnabled) {
      _log.debug('Version check disabled (no API URL configured)');
      return null;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .post(
            Uri.parse(AppConfig.versionCheckApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'os': Platform.isIOS ? 'ios' : 'android',
              'app_version': info.version,
              'build_number': int.tryParse(info.buildNumber) ?? 1,
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _log.info('Version check : $json');

      if (json['success'] != true) return null;

      return VersionCheckResult.fromJson(json);
    } catch (e) {
      _log.warn('Version check failed: $e');
      return null;
    }
  }

  /// Start periodic checks using configured interval
  void startPeriodicChecks(void Function(VersionCheckResult) onResult) {
    if (!AppConfig.versionCheckEnabled) {
      _log.debug('Periodic version checks disabled (no API URL configured)');
      return;
    }

    _timer?.cancel();
    _log.debug('Starting periodic version checks every ${AppConfig.versionCheckIntervalSeconds}s');
    _timer = Timer.periodic(AppConfig.versionCheckInterval, (_) async {
      final result = await check();
      if (result != null && result.shouldShowDialog) {
        onResult(result);
      }
    });
  }

  void stopPeriodicChecks() {
    _timer?.cancel();
    _timer = null;
  }

  // Rate-limiting for recommended updates (max once per day)
  static const _lastRecommendedDialogKey = 'app:last_recommended_update_dialog';
  static const _recommendedDialogCooldown = Duration(hours: 24);

  /// Check if enough time has passed to show a recommended update dialog
  Future<bool> canShowRecommendedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_lastRecommendedDialogKey);
    if (lastShown == null) return true;

    final lastShownTime = DateTime.fromMillisecondsSinceEpoch(lastShown);
    final elapsed = DateTime.now().difference(lastShownTime);
    return elapsed >= _recommendedDialogCooldown;
  }

  /// Record that the recommended update dialog was shown
  Future<void> markRecommendedDialogShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRecommendedDialogKey, DateTime.now().millisecondsSinceEpoch);
  }

  static String get storeUrl => Platform.isIOS
      ? 'https://apps.apple.com/app/usernode/id0000000000' // TODO: real ID
      : 'https://play.google.com/store/apps/details?id=com.usernodelabs.crypto_mobile_app';
}

// =============================================================================
// Riverpod Provider
// =============================================================================

/// Provider for initial app version check result
final appVersionCheckProvider = FutureProvider<VersionCheckResult?>((ref) {
  return AppVersionCheck.instance.check();
});

// =============================================================================
// Update Dialog
// =============================================================================

/// Shows the appropriate update dialog based on upgrade level
/// Uses the provided navigatorKey to show the dialog
/// For recommended updates, rate-limited to once per day
Future<void> showUpdateDialog(GlobalKey<NavigatorState> navigatorKey, VersionCheckResult result) async {
  _log.info('showUpdateDialog called with upgrade=${result.upgrade}, isBlocking=${result.isBlocking}');

  // Rate-limit recommended updates to once per day
  if (!result.isBlocking) {
    final canShow = await AppVersionCheck.instance.canShowRecommendedDialog();
    if (!canShow) {
      _log.info('Skipping recommended update dialog (shown within last 24h)');
      return;
    }
    // Mark as shown before showing the dialog
    await AppVersionCheck.instance.markRecommendedDialogShown();
  }

  final context = navigatorKey.currentContext;
  if (context == null) {
    _log.warn('Navigator context is null, cannot show dialog');
    return;
  }

  // Report metrics for update dialog shown
  MetricsReportingService.instance.reportEvent(
    'update_dialog_shown',
    eventData: {
      'upgrade_level': result.upgrade.name,
      'is_blocking': result.isBlocking,
    },
  );

  // ignore: use_build_context_synchronously
  showDialog(
    context: context,
    barrierDismissible: !result.isBlocking,
    builder: (ctx) {
      _log.info('Dialog builder called');
      return _UpdateDialog(result: result);
    },
  );
}

class _UpdateDialog extends StatelessWidget {
  final VersionCheckResult result;

  const _UpdateDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !result.isBlocking,
      child: AlertDialog(
        title: Text(result.isBlocking ? 'Update Required' : 'Update Available'),
        content: Text(
          result.details ?? 'A new version of the app is available.',
        ),
        actions: [
          if (!result.isBlocking)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () => _openStore(),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore() async {
    final urlString = result.updateUrl ?? AppVersionCheck.storeUrl;
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
