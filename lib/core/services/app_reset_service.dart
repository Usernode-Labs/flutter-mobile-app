import 'dart:io';

import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/wallet/services/pending_transaction_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppResetService {
  AppResetService._();

  static final AppResetService instance = AppResetService._();

  final _log = LoggingService.instance.withTag('usernode/AppReset');
  Future<void> Function()? _inProcessRestartHandler;
  bool _resetInProgress = false;

  void registerInProcessRestartHandler(Future<void> Function() handler) {
    _inProcessRestartHandler = handler;
  }

  void unregisterInProcessRestartHandler() {
    _inProcessRestartHandler = null;
  }

  bool get isResetInProgress => _resetInProgress;

  Future<void> resetAndRestart({
    required String reason,
    String? backendResponse,
  }) async {
    if (_resetInProgress) {
      _log.warn('Reset already in progress, skipping duplicate request');
      return;
    }

    _resetInProgress = true;
    _log.error(
      'Resetting app state after backend mismatch',
      context: {
        'reason': reason,
        if (backendResponse != null) 'backend_response': backendResponse,
      },
    );

    try {
      await _stopServices();
      await _clearPersistentState();

      final restarted = await PlatformAlarmService.instance.restartActivity();
      if (!restarted && _inProcessRestartHandler != null) {
        await _inProcessRestartHandler!.call();
      }
    } finally {
      _resetInProgress = false;
    }
  }

  Future<void> _stopServices() async {
    AppVersionCheck.instance.stopPeriodicChecks();

    try {
      await MetricsReportingService.instance.resetForAppRestart();
    } catch (e) {
      _log.warn('Failed to stop metrics reporting cleanly: $e');
    }

    try {
      await AndroidForegroundTaskController.instance
          .stopMonitoring(reason: 'app_reset');
    } catch (e) {
      _log.warn('Failed to stop Android monitoring cleanly: $e');
    }

    try {
      await PlatformAlarmService.instance.stopPersistentForegroundService();
    } catch (e) {
      _log.warn('Failed to stop persistent foreground service cleanly: $e');
    }

    try {
      await PlatformAlarmService.instance.stopForegroundService();
    } catch (e) {
      _log.warn('Failed to stop foreground service cleanly: $e');
    }

    try {
      await PlatformAlarmService.instance.cancelAllAlarms();
    } catch (e) {
      _log.warn('Failed to cancel alarms cleanly: $e');
    }

    try {
      await PlatformAlarmService.instance.cancelAlarmWatchdog();
    } catch (e) {
      _log.warn('Failed to cancel alarm watchdog cleanly: $e');
    }

    await RustBackendService.instance.resetForAppRestart();
    await AndroidForegroundTaskController.instance.resetForAppRestart();
    PlatformAlarmService.instance.resetForAppRestart();
    MetricsCollectorService.instance.reset();
  }

  Future<void> _clearPersistentState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    const secureStorage = FlutterSecureStorage();
    await secureStorage.deleteAll();

    try {
      final pendingTransactions = await PendingTransactionService.getInstance();
      await pendingTransactions.clearAllPendingTransactions();
    } catch (e) {
      _log.warn('Failed to clear pending transactions explicitly: $e');
    }

    try {
      await SlotProductionRepository.instance.clearAll();
    } catch (e) {
      _log.warn('Failed to clear slot production state explicitly: $e');
    }

    await _clearAppSupportArtifacts();
  }

  Future<void> _clearAppSupportArtifacts() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final entries = appSupportDir.listSync(followLinks: false);
      for (final entry in entries) {
        final name = entry.uri.pathSegments.isNotEmpty
            ? entry.uri.pathSegments.last
            : '';
        final isVrfDb = _isSqliteArtifact(name, '_usernode_vrf_storage.sqlite');
        final isNodeDb =
            _isSqliteArtifact(name, '_usernode_node_storage.sqlite');
        final isLogsDir = entry is Directory && name == 'logs';
        if (!isVrfDb && !isNodeDb && !isLogsDir) {
          continue;
        }

        if (entry is File) {
          await entry.delete();
        } else if (entry is Directory) {
          await entry.delete(recursive: true);
        }
      }
    } catch (e) {
      _log.warn('Failed to clear app support artifacts: $e');
    }
  }

  bool _isSqliteArtifact(String name, String databaseSuffix) {
    return name.endsWith(databaseSuffix) ||
        name.endsWith('$databaseSuffix-wal') ||
        name.endsWith('$databaseSuffix-shm');
  }
}
