import 'dart:io';

import 'package:crypto_mobile_app/core/config/secure_storage_options.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NextLaunchWriter = Future<void> Function();
typedef TerminalResetHandler = void Function(String reason);
typedef ResetDirectoryResolver = Future<List<Directory>> Function();

/// Owns the one-way application reset boundary.
///
/// A reset never constructs a successor runtime in this process: it wipes
/// everything and asks Android to clear application data (iOS has no supported
/// self-termination API, so it parks on the inert reset surface and asks the
/// user to relaunch). Successful initial login or a network change may write
/// only its explicit cold-launch input after the same wipe and then terminate
/// without a second clear-data call.
///
/// Voluntary sign-out does NOT come here — it is scoped and in-process.
/// Every reason that reaches this class is one the
/// app cannot continue from: an expired or unreadable credential, a different
/// participant replacing the current one, a network change, or the
/// authenticated-to-guest switch.
class AppResetService {
  AppResetService._({
    ResetDirectoryResolver? resetDirectories,
    PlatformAlarmService? platformAlarms,
  })  : _resetDirectories = resetDirectories ?? _defaultResetDirectories,
        _platformAlarms = platformAlarms ?? PlatformAlarmService.instance;

  @visibleForTesting
  AppResetService.test({
    required ResetDirectoryResolver resetDirectories,
    required PlatformAlarmService platformAlarms,
  })  : _resetDirectories = resetDirectories,
        _platformAlarms = platformAlarms;

  static final AppResetService instance = AppResetService._();

  final _log = LoggingService.instance.withTag('usernode/AppReset');
  final ResetDirectoryResolver _resetDirectories;
  final PlatformAlarmService _platformAlarms;
  TerminalResetHandler? _terminalResetHandler;
  void Function()? _localResetHandler;
  Future<void>? _activeReset;

  void registerTerminalResetHandler(TerminalResetHandler handler) {
    _terminalResetHandler = handler;
  }

  void unregisterTerminalResetHandler() {
    _terminalResetHandler = null;
  }

  void registerLocalResetHandler(void Function() handler) {
    _localResetHandler = handler;
  }

  bool get isResetInProgress => _activeReset != null;

  @visibleForTesting
  void enterTerminalSurfaceForTesting([String reason = 'unknown']) =>
      _terminalResetHandler?.call(reason);

  /// Irreversibly resets this application incarnation.
  ///
  /// [prepareNextLaunch], when present, runs only after the old incarnation's
  /// persistent state has been erased. It may write the minimum cold-launch
  /// input for the next incarnation; no runtime object is handed to it.
  Future<void> resetAndTerminate({
    required String reason,
    String? backendResponse,
    NextLaunchWriter? prepareNextLaunch,
  }) {
    final active = _activeReset;
    if (active != null) {
      _log.warn('Reset already in progress, joining the terminal boundary');
      return active;
    }

    final reset = _runTerminalReset(
      reason: reason,
      backendResponse: backendResponse,
      prepareNextLaunch: prepareNextLaunch,
    );
    _activeReset = reset;
    return reset;
  }

  Future<void> _runTerminalReset({
    required String reason,
    String? backendResponse,
    NextLaunchWriter? prepareNextLaunch,
  }) async {
    _log.warn(
      'Entering terminal application reset',
      context: {
        'reason': reason,
        if (backendResponse != null) 'backend_response': backendResponse,
        'has_next_launch_input': prepareNextLaunch != null,
      },
    );

    // The native platform boundary invalidates the application incarnation
    // synchronously. Session/runtime authority is owned by the private
    // composition root and Rust, never by a parallel Dart lifecycle service.
    _platformAlarms.beginTerminalReset();
    AppVersionCheck.instance.stopPeriodicChecks();
    _bestEffortSync(
      'close local reset handlers',
      () => _localResetHandler?.call(),
    );

    // Dispose the functional provider graph before the first await. Reset is
    // terminal, so keeping UI/providers alive for a best-effort WebView reply
    // is less important than preventing an admitted async writer from
    // repopulating storage after the wipe.
    Object? resetError;
    StackTrace? resetStackTrace;
    if (!_enterTerminalSurface(reason)) {
      resetError = StateError('The functional app graph was not disposed');
      resetStackTrace = StackTrace.current;
    }

    await _bestEffort(
      'clear error-reporting state',
      SentryUtil.closeForTerminalReset,
    );

    if (!await _cancelNativeWork()) {
      resetError ??= StateError('Mandatory native reset cleanup failed');
      resetStackTrace ??= StackTrace.current;
    }

    await _bestEffort(
      'stop observability reporting',
      ObservabilityReportingService.instance.stopMobileContextSnapshotReporting,
    );
    MetricsCollectorService.instance.reset();
    await _bestEffort(
      'close application logging',
      LoggingService.instance.closeForTerminalReset,
    );

    try {
      await _clearPersistentState();
    } catch (error, stackTrace) {
      resetError ??= error;
      resetStackTrace ??= stackTrace;
      _log.error(
        'Persistent reset failed; discarding next-launch input',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // The old provider graph is gone before the new boot payload exists, so
    // no listener in this incarnation can observe or adopt the next session.
    if (resetError == null && prepareNextLaunch != null) {
      try {
        await prepareNextLaunch();
      } catch (error, stackTrace) {
        resetError = error;
        resetStackTrace = stackTrace;
        _log.error(
          'Could not persist next-launch input; discarding the new session',
          error: error,
          stackTrace: stackTrace,
        );
        await _bestEffort(
          'discard partial next-launch input',
          _clearPersistentState,
        );
      }
    }

    await _bestEffort(
      'enter native terminal boundary',
      () => _platformAlarms.enterTerminalReset(
        clearApplicationData: prepareNextLaunch == null || resetError != null,
      ),
    );

    if (resetError != null) {
      Error.throwWithStackTrace(resetError, resetStackTrace!);
    }
  }

  Future<bool> _cancelNativeWork() async {
    var mandatoryCleanupSucceeded = await _requiredCleanup(
      'invalidate application incarnation',
      _platformAlarms.invalidateApplicationIncarnation,
    );
    await _bestEffort(
      'stop persistent foreground service',
      _platformAlarms.stopPersistentForegroundService,
    );
    await _bestEffort(
      'stop foreground service',
      _platformAlarms.stopForegroundService,
    );
    await _bestEffort(
      'release native wakelock',
      _platformAlarms.releaseWakelock,
    );
    await _bestEffort(
      'cancel alarms',
      _platformAlarms.cancelAllAlarms,
    );
    await _bestEffort(
      'cancel alarm watchdog',
      _platformAlarms.cancelAlarmWatchdog,
    );
    mandatoryCleanupSucceeded = await _requiredCleanup(
          'clear WebView session data',
          _platformAlarms.clearWebSessionData,
        ) &&
        mandatoryCleanupSucceeded;
    mandatoryCleanupSucceeded = await _requiredCleanup(
          'clear native reset state',
          _platformAlarms.clearNativeResetState,
        ) &&
        mandatoryCleanupSucceeded;
    _platformAlarms.closeForTerminalReset();
    return mandatoryCleanupSucceeded;
  }

  Future<void> _clearPersistentState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.clear()) {
      throw StateError('SharedPreferences.clear returned false');
    }
    NetworkPrefs.resetForApplicationReset();

    const secureStorage = FlutterSecureStorage(
      aOptions: usernodeAndroidSecureStorageOptions,
    );
    await secureStorage.deleteAll();
    if (Platform.isIOS) {
      // Session and social-push state intentionally use this device-only
      // accessibility class. Keychain deleteAll queries are accessibility-
      // scoped, so the default query above does not remove these items.
      const deviceOnlySecureStorage = FlutterSecureStorage(
        aOptions: usernodeAndroidSecureStorageOptions,
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
      );
      await deviceOnlySecureStorage.deleteAll();
    }

    final directories = await _resetDirectories();
    final clearedPaths = <String>{};
    for (final directory in directories) {
      if (!clearedPaths.add(directory.path) || !await directory.exists()) {
        continue;
      }
      await for (final entry in directory.list(followLinks: false)) {
        await entry.delete(recursive: true);
      }
    }
  }

  static Future<List<Directory>> _defaultResetDirectories() async {
    final directories = <Directory>[
      await getApplicationSupportDirectory(),
      await getApplicationDocumentsDirectory(),
      await getApplicationCacheDirectory(),
    ];
    // The reset contract is mobile-only. Android and iOS expose an app-scoped
    // temporary root; desktop/test hosts may expose a shared system temp root
    // that this service must never enumerate and erase.
    if (Platform.isAndroid || Platform.isIOS) {
      directories.add(await getTemporaryDirectory());
    }
    return directories;
  }

  Future<void> _bestEffort(
    String operation,
    Future<dynamic> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _log.error(
        'Could not $operation during terminal reset',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _requiredCleanup(
    String operation,
    Future<bool> Function() action,
  ) async {
    try {
      final succeeded = await action();
      if (!succeeded) {
        _log.error('$operation failed during terminal reset');
      }
      return succeeded;
    } catch (error, stackTrace) {
      _log.error(
        'Could not $operation during terminal reset',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool _enterTerminalSurface(String reason) {
    final handler = _terminalResetHandler;
    if (handler == null) {
      _log.error('No terminal reset surface is registered');
      return false;
    }
    try {
      handler(reason);
      return true;
    } catch (error, stackTrace) {
      _log.error(
        'Could not enter terminal reset surface',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _bestEffortSync(String operation, void Function() action) {
    try {
      action();
    } catch (error, stackTrace) {
      _log.error(
        'Could not $operation during terminal reset',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
