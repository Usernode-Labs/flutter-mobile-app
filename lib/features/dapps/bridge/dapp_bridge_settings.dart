part of '../dapp_webview_screen.dart';

/// Settings/profile/misc bridge methods. Native settings, account state, and
/// actions stay behind trusted SV chrome; the installed app's public release
/// identifiers are also shared with `getBridgeInfo` so staging can display
/// which Flutter binary hosts it.
mixin _BridgeSettings on _DappWebViewScreenStateBase {
  /// `openExternal` JS-channel method: opens the given http(s) URL in the
  /// system browser. Non-web schemes are rejected so pages can't silently
  /// fire intent://, tel:, etc. through this path.
  Future<void> _handleOpenExternal(
      String id, Map<String, dynamic> payload) async {
    final args = payload['args'];
    final url = args is Map<String, dynamic> ? args['url']?.toString() : null;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openExternal requires an http(s) url',
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _resolveJsPromise(
      id: id,
      value: launched,
      error: launched ? null : 'Could not open URL',
    );
  }

  /// `openNativeScreen` JS-channel method: pushes an allowlisted native
  /// route. Escape hatch for the tooling that stays native — diagnostics,
  /// the device benchmark, and the HTTP log viewer (debugging UIs over
  /// native-only data). Only the trusted SV origin may drive native
  /// navigation — sub-apps get a rejection.
  Future<void> _handleOpenNativeScreen(
      String id, Map<String, dynamic> payload) async {
    const allowedScreens = <String, String>{
      'diagnostics': AppRoutes.diagnostics,
      'benchmark': AppRoutes.deviceBenchmark,
      'httpLogs': AppRoutes.httpDebugLogs,
    };
    final args = payload['args'];
    final screen =
        args is Map<String, dynamic> ? args['screen']?.toString() : null;
    final route = screen == null ? null : allowedScreens[screen];
    if (route == null) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'Unknown screen; allowed: ${allowedScreens.keys.join(', ')}',
      );
      return;
    }
    if (!await _isTrustedShortcutOrigin()) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'openNativeScreen is only available to the dapps home',
      );
      return;
    }
    if (!mounted) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'openNativeScreen')) {
      return;
    }
    if (!mounted) return;
    context.push(route);
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// `getProfileInfo`: the leaderboard participant id SV's #profile screen
  /// needs to query /me/ranking and /me/breakdown. Null when this install
  /// hasn't registered with the leaderboard yet.
  Future<void> _handleGetProfileInfo(String id) async {
    final identity = ref.read(identityProvider);
    if (!await _requireTrustedChromeOrigin(id, 'getProfileInfo')) return;
    if (!_identityScopeIsCurrent(identity)) {
      await _rejectStaleIdentityScope(id, 'getProfileInfo');
      return;
    }
    await _resolveJsPromise(
      id: id,
      // Use only the captured identity. The participant-id provider may still
      // hold the previous bucket's value while an identity transition settles.
      value: {'participantId': identity.participantId},
      error: null,
    );
  }

  /// Public, device-local build metadata. `getBridgeInfo` includes these two
  /// fields so the Social Vibecoding shell can identify the installed Flutter
  /// binary even on a staging origin, where privileged settings access is
  /// intentionally unavailable. App version/build are public release
  /// identifiers; no account, wallet, or device state is exposed here.
  Future<Map<String, String?>> _mobileAppBuildInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (_) {
      return const {
        'appVersion': null,
        'buildNumber': null,
      };
    }
  }

  /// One JSON shape shared by `getSettingsState` and every settings setter
  /// (each setter resolves with the refreshed state so SV re-renders from a
  /// single source of truth). Mirrors what the native settings screen shows.
  Future<Map<String, dynamic>> _settingsStateSnapshot() async {
    // Live probes, not the service's cached combined flag: the granular
    // request methods don't refresh `hasPermissions`, and its legacy
    // notifications&&exactAlarm semantics would mislabel `exactAlarmGranted`.
    bool exactAlarmGranted = false;
    bool? batteryOptDisabled;
    bool notificationsGranted = false;
    String? deviceManufacturer;
    try {
      await PlatformAlarmService.instance.initialize();
      notificationsGranted =
          await PlatformAlarmService.instance.hasNotificationsPermission();
      final alarm =
          await PlatformAlarmService.instance.alarmPermissionsSnapshot();
      exactAlarmGranted = alarm['exactAlarmGranted'] == true;
      batteryOptDisabled = alarm['batteryOptDisabled'] as bool?;
      if (defaultTargetPlatform == TargetPlatform.android) {
        deviceManufacturer =
            await PlatformAlarmService.instance.getDeviceManufacturer();
      }
    } catch (e) {
      debugPrint('[Usernode JS-channel] permission probe failed: $e');
    }

    final mobileAppBuildInfo = await _mobileAppBuildInfo();

    String? nodeVersion;
    String? commitHash;
    String? branch;
    try {
      final env = ref.read(buildEnvProvider);
      nodeVersion = env.version;
      final hash = env.git.commitHash;
      commitHash = hash.length >= 7 ? hash.substring(0, 7) : hash;
      branch = env.git.branch;
    } catch (_) {}

    final facematchStrict = ref
            .read(zkPassportSettingsProvider)
            .whenOrNull(data: (s) => s.facematchStrict) ??
        true;

    return {
      'buildInfo': {
        ...mobileAppBuildInfo,
        'nodeVersion': nodeVersion,
        'commitHash': commitHash,
        'branch': branch,
      },
      'nodeSleepEnabled': AppSleepService.instance.isEnabled,
      'debugMode': ref.read(debugModeProvider),
      'facematchStrict': facematchStrict,
      // Terms moved to the SV web settings (session-authed /challenges-api
      // terms routes) — no native terms state remains.
      'authStatus': ref.read(authStatusProvider).name,
      'permissions': {
        'platform':
            defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
        'exactAlarmGranted': exactAlarmGranted,
        'notificationsGranted': notificationsGranted,
        'batteryOptDisabled': batteryOptDisabled,
        'deviceManufacturer': deviceManufacturer,
      },
    };
  }

  Future<void> _handleGetSettingsState(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'getSettingsState')) return;
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  Future<void> _handleSetNodeSleepEnabled(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setNodeSleepEnabled')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'setNodeSleepEnabled')) {
      return;
    }
    await AppSleepService.instance.setEnabled(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  Future<void> _handleSetDebugMode(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setDebugMode')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'setDebugMode')) return;
    await ref.read(debugModeProvider.notifier).set(enabled);
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  Future<void> _handleSetFacematchStrict(
      String id, Map<String, dynamic> payload) async {
    if (!await _requireTrustedChromeOrigin(id, 'setFacematchStrict')) return;
    final enabled = await _requireBoolArg(id, payload, 'enabled');
    if (enabled == null) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'setFacematchStrict')) {
      return;
    }
    await ref.read(zkPassportFlowControllerProvider).setFacematchStrict(
          enabled,
        );
    await _resolveJsPromise(
      id: id,
      value: await _settingsStateSnapshot(),
      error: null,
    );
  }

  /// `resetZkChallenge`: same reset the native settings screen offers.
  /// Confirmation happens web-side; this is the commit.
  Future<void> _handleResetZkChallenge(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'resetZkChallenge')) return;
    if (!mounted) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'resetZkChallenge')) {
      return;
    }
    if (!mounted) return;
    final reset = await resetChallengeState(ref, context);
    if (!reset) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error:
            'A zkPassport proof is still being processed. Try again shortly.',
      );
      return;
    }
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  Future<void> _handleRequestPermissions(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'requestPermissions')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'requestPermissions')) {
      return;
    }
    final granted = await PlatformAlarmService.instance.requestPermissions();
    final state = await _settingsStateSnapshot();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  Future<void> _handleOpenBatterySettings(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'openBatterySettings')) return;
    if (!await _revalidatePrivilegedBridgeLease(id, 'openBatterySettings')) {
      return;
    }
    await PlatformAlarmService.instance.openBatteryOptimizationSettings();
    await _resolveJsPromise(id: id, value: true, error: null);
  }

  /// Granular variant of `requestPermissions`: notification permission only.
  /// SV prompts at its own product moments (social push, nudges) without
  /// dragging the user through the alarm/battery chain.
  Future<void> _handleRequestNotificationPermission(String id) async {
    if (!await _requireTrustedChromeOrigin(
        id, 'requestNotificationPermission')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'requestNotificationPermission',
    )) {
      return;
    }
    final granted =
        await PlatformAlarmService.instance.requestNotificationsPermission();
    final state = await _settingsStateSnapshot();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  /// Granular variant of `requestPermissions`: exact-alarm + battery only,
  /// for the post-`startNode` sheet. Never shows the notification dialog.
  Future<void> _handleRequestAlarmPermissions(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'requestAlarmPermissions')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'requestAlarmPermissions',
    )) {
      return;
    }
    final granted =
        await PlatformAlarmService.instance.requestAlarmPermissions();
    final state = await _settingsStateSnapshot();
    await _resolveJsPromise(
      id: id,
      value: {...state, 'granted': granted},
      error: null,
    );
  }

  /// Deep link to the OS notification settings — the recovery path once the
  /// OS permission dialog is exhausted (denied on iOS, or twice on Android).
  Future<void> _handleOpenNotificationSettings(String id) async {
    if (!await _requireTrustedChromeOrigin(id, 'openNotificationSettings')) {
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(
      id,
      'openNotificationSettings',
    )) {
      return;
    }
    final opened =
        await PlatformAlarmService.instance.openNotificationSettings();
    await _resolveJsPromise(
      id: id,
      value: opened,
      error: opened ? null : 'Could not open notification settings',
    );
  }
}
