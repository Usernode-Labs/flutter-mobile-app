# App Permissions Guide

> Comprehensive guide to runtime permissions required for background block production

## Overview

This app requires several runtime permissions to enable reliable background block production monitoring. Permissions are requested **automatically at app startup** (one-time on first launch) and can be managed through the Background Production Settings screen.

## Permission Summary

| Permission | Android | iOS | Required | Purpose |
|----------|---------|-----|----------|---------|
| **Notifications** | POST_NOTIFICATIONS (13+) | Notifications | ✅ Yes | Alert user about block production events |
| **Exact Alarms** | SCHEDULE_EXACT_ALARM (12+) | N/A | ✅ Yes | Wake app at precise times for slot monitoring |
| **Battery Optimization Exemption** | REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | N/A | ⚠️ Recommended | Prevent Android from killing background tasks |
| **Background Refresh** | N/A | Background Fetch | ✅ Yes | iOS background task execution |

---

## Android Permissions

### 1. POST_NOTIFICATIONS (Android 13+)

**Purpose**: Display notifications about block production events, alarms, and system status.

**Required Since**: Android 13 (API 33)

**Declaration** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Request Flow**:
1. App startup → Check if permission granted
2. If not granted → Show system permission dialog
3. User grants/denies permission
4. Result sent to metrics system

**User Sees**: Standard Android permission dialog with "Allow" / "Don't allow" options.

**If Denied**: App cannot show notifications but background monitoring still works.

---

### 2. SCHEDULE_EXACT_ALARM (Android 12+)

**Purpose**: Schedule exact alarms to wake the app at precise times for slot monitoring.

**Required Since**: Android 12 (API 31)

**Declaration** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

**Request Flow**:
1. App startup → Check if permission granted
2. If not granted → Open system settings page
3. User navigates to "Alarms & reminders" toggle
4. User enables permission
5. User returns to app
6. App re-checks permission status on resume

**User Sees**: Android Settings screen with toggle for "Alarms & reminders".

**Path**: Settings → Apps → [App Name] → Alarms & reminders

**If Denied**: Background block production will NOT work - alarms won't fire.

**Note**: This is a **special permission** that requires navigation to system settings. It cannot be requested via a simple dialog.

---

### 3. Battery Optimization Exemption (Android 6+)

**Purpose**: Prevent Android from killing the app's background processes to save battery.

**Required Since**: Android 6 (API 23)

**Recommendation**: ⚠️ Highly recommended but not strictly required.

**Declaration** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

**Request Flow**:
1. App startup → Check if exemption granted
2. If not granted → Show exemption dialog
3. User grants/denies exemption
4. Result sent to metrics system

**User Sees**: System dialog asking to "Allow [App Name] to ignore battery optimizations?"

**If Denied**: Android may aggressively kill background tasks, especially on OEM devices (Xiaomi, Oppo, Samsung, etc.).

**Google Play Policy**: Apps using this permission must have a valid use case. Block production monitoring qualifies as it requires reliable background execution.

---

### Additional Android Permissions (Manifest-Only)

These are granted automatically at install time and do not require runtime requests:

- **FOREGROUND_SERVICE** - Run foreground services
- **FOREGROUND_SERVICE_DATA_SYNC** - Specify foreground service type (Android 14+)
- **WAKE_LOCK** - Keep CPU awake during block production
- **RECEIVE_BOOT_COMPLETED** - Reschedule alarms after device reboot
- **INTERNET** - Network access
- **ACCESS_NETWORK_STATE** - Check network connectivity
- **NFC** - NFC hardware access (if available)
- **USE_BIOMETRIC** - Biometric authentication

---

## iOS Permissions

### 1. Notifications

**Purpose**: Display notifications about block production events and slot reminders.

**Request Flow**:
1. App startup → Check if permission granted
2. If not granted → Show iOS permission dialog
3. User grants/denies permission
4. Result sent to metrics system

**Permissions Requested**:
- Alert notifications
- Sound notifications
- Badge count

**User Sees**: Standard iOS permission dialog with "Allow" / "Don't Allow" options.

**If Denied**: App cannot show notifications but background monitoring may still work (depends on iOS version and background task availability).

---

### 2. Background Fetch

**Purpose**: Execute background tasks for slot monitoring.

**Configuration** (`Info.plist`):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

**BGTaskScheduler Tasks**:
- `be.tramckrijte.workmanager.slot_monitoring_task`
- `com.usernode.app.slotmonitoring`

**No Runtime Permission Required**: Background modes are capability-based, configured in Xcode project settings.

**Note**: iOS background task execution is **NOT guaranteed**. iOS decides when to run background tasks based on device state, battery level, and usage patterns.

---

## Startup Permission Request Flow

### First App Launch Sequence

```
App Startup
  └─> Initialize services
       └─> Check SharedPreferences for 'has_requested_permissions_at_startup'
            ├─> If FALSE (first launch):
            │    ├─> [Android] Request POST_NOTIFICATIONS
            │    │    └─> User grants/denies
            │    │
            │    ├─> [Android] Request SCHEDULE_EXACT_ALARM
            │    │    └─> Opens Settings → User enables → Returns to app
            │    │
            │    ├─> [Android] Request Battery Optimization Exemption
            │    │    └─> User grants/denies
            │    │
            │    ├─> [iOS] Request Notifications
            │    │    └─> User grants/denies
            │    │
            │    └─> Set 'has_requested_permissions_at_startup' = TRUE
            │
            └─> If TRUE (subsequent launches):
                 └─> Skip permission requests
```

### Implementation

**File**: `/lib/main.dart` → `_requestPermissionsAtStartup()`

```dart
Future<void> _requestPermissionsAtStartup(LoggingService log) async {
  final prefs = await SharedPreferences.getInstance();
  final hasRequestedPermissions = prefs.getBool('has_requested_permissions_at_startup') ?? false;

  if (hasRequestedPermissions) {
    log.info('Permissions already requested at startup previously');
    return;
  }

  log.info('Requesting permissions at startup...');

  // Initialize platform alarm service
  await PlatformAlarmService.instance.initialize();

  // Request all necessary permissions
  final granted = await PlatformAlarmService.instance.requestPermissions();

  // Mark that we've requested permissions
  await prefs.setBool('has_requested_permissions_at_startup', true);
}
```

**Platform-Specific Implementation**:

**Android** (`PlatformAlarmService._requestAndroidPermissions()`):
1. POST_NOTIFICATIONS → Direct permission request
2. SCHEDULE_EXACT_ALARM → Opens system settings
3. Battery Optimization → Shows exemption dialog

**iOS** (`PlatformAlarmService._requestIOSPermissions()`):
1. Notifications → Direct permission request (alert, sound, badge)

---

## Managing Permissions After First Launch

Users can manage permissions through:

### Via App Settings Screen

**Path**: Settings → Background Production Settings → Grant Permissions button

This re-triggers the permission request flow for any missing permissions.

### Via System Settings

**Android**:
- Settings → Apps → [App Name] → Permissions
- Settings → Apps → [App Name] → Alarms & reminders
- Settings → Apps → [App Name] → Battery → Unrestricted

**iOS**:
- Settings → [App Name] → Notifications
- Settings → General → Background App Refresh → [App Name]

---

## Permission Status Monitoring

The app continuously monitors permission status and sends events to the metrics system:

### Android Events
- `android_exact_alarm_permission_granted`
- `android_exact_alarm_permission_denied`
- `android_notification_permission_granted`
- `android_notification_permission_denied`
- `android_battery_optimization_checked`
- `android_battery_optimization_disabled`

### iOS Events
- `ios_notification_permission_granted`
- `ios_notification_permission_denied`
- `ios_background_refresh_status_checked`

### Permission Check Triggers
- App startup
- App resume (returns from background)
- Settings screen opened
- Permission request result received

---

## Troubleshooting

### Android: Alarms Not Firing

**Symptom**: Scheduled alarms don't wake the app.

**Possible Causes**:
1. SCHEDULE_EXACT_ALARM permission denied
2. Battery optimization enabled
3. OEM-specific battery saver (Xiaomi, Oppo, Samsung)

**Solution**:
1. Go to Settings → Background Production Settings → Check status
2. Grant "Alarms & reminders" permission
3. Disable battery optimization for the app
4. Check OEM-specific battery settings:
   - Xiaomi: Settings → Battery & performance → App battery saver → [App] → No restrictions
   - Samsung: Settings → Device care → Battery → App power management → [App] → Unrestricted
   - Oppo: Settings → Battery → High background battery consumption → [App] → Allow

---

### Android: Notifications Not Showing

**Symptom**: No notifications displayed for block production events.

**Possible Causes**:
1. POST_NOTIFICATIONS permission denied (Android 13+)
2. Notification channel disabled
3. Do Not Disturb mode active

**Solution**:
1. Go to Settings → Background Production Settings → Grant Permissions
2. Enable POST_NOTIFICATIONS
3. Check Android Settings → Apps → [App] → Notifications
4. Ensure "Slot Monitoring" channel is enabled

---

### iOS: Background Tasks Not Executing

**Symptom**: Alarms/notifications don't fire reliably on iOS.

**Possible Causes**:
1. Background App Refresh disabled
2. Low Power Mode active
3. iOS deprioritized background tasks (normal behavior)
4. Device in Do Not Disturb mode

**Solution**:
1. Enable Background App Refresh:
   - Settings → General → Background App Refresh → On
   - Settings → [App Name] → Background App Refresh → On
2. Disable Low Power Mode (Settings → Battery)
3. Use the app regularly (iOS favors frequently-used apps)
4. Keep device plugged in and WiFi connected during testing

**Note**: iOS background task execution is **NOT guaranteed**. For reliable block production monitoring on iOS, keep the app in the foreground or use notifications as fallback.

---

### Permission Revoked After Granted

**Symptom**: Permission was granted but now shows as denied.

**Possible Causes**:
1. User manually revoked permission in system settings
2. App was uninstalled/reinstalled (resets permissions)
3. Android system revoked permission due to app not using it

**Solution**:
1. Go to Settings → Background Production Settings
2. Tap "Grant Permissions" button
3. Re-grant all required permissions

---

## Best Practices

### For Users

1. **Grant all permissions on first launch** - This ensures reliable background monitoring
2. **Don't clear app data frequently** - This resets the permission request flag
3. **Exempt app from battery optimization** - Critical for OEM devices
4. **Keep app updated** - Permission handling improvements in newer versions

### For Developers

1. **Always check permission status before scheduling alarms**
2. **Handle permission denial gracefully** - Provide clear error messages
3. **Re-check permissions on app resume** - Catches changes made in system settings
4. **Send permission events to metrics** - Monitor permission grant/deny rates
5. **Test on OEM devices** - Samsung, Xiaomi, Oppo have aggressive battery management

---

## Related Documentation

- [METRICS_EVENTS.md](./METRICS_EVENTS.md) - Permission-related metrics events
- [background-block-production.md](./background-block-production.md) - Background production architecture
- [BACKGROUND_PRODUCTION_TESTING.md](./BACKGROUND_PRODUCTION_TESTING.md) - Testing permission flows

---

**Last Updated**: 2025-11-21
**Version**: 1.0.0
