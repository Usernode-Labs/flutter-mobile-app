# Background Block Production System

**Status**: ✅ Complete (All 5 phases implemented)
**Last Updated**: 2025-11-23
**Implementation Date**: January 2025

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Platform Implementation](#platform-implementation)
  - [Android](#android-implementation)
  - [iOS](#ios-implementation)
- [Migration Guide](#migration-guide)
- [Permissions](#permissions)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Overview

The background block production system enables the app to reliably wake up and produce blocks at scheduled slot times. The system uses a unified orchestrator pattern that consolidates multiple services into a single, event-driven coordinator.

### Key Features

- **Unified Orchestrator**: Single service (`BackgroundBlockProductionOrchestrator`) coordinates all block production activities
- **Event-Driven**: Emits events for metrics, logging, and UI updates
- **VRF-Aware**: Smart epoch monitoring that adapts to VRF calculation status
- **Platform-Agnostic Core**: Works across Android and iOS with platform-specific implementations
- **Automatic Permission Requests**: Requests required permissions at app startup
- **Slot Monitoring Integration**: Automatically triggers monitoring when alarms fire

### Reliability Targets

| Platform | Method | Reliability | User Interaction |
|----------|--------|-------------|------------------|
| **Android** | Exact Alarms + FGS | **90-95%** | Minimal (one-time setup) |
| **iOS Tier 1** | Foreground Keep-Alive | **99%** | Must keep app open |
| **iOS Tier 2** | BGTask + Notifications | **80-90%** | Must respond to notifications |
| **iOS Tier 3** | BGTask alone | **40-60%** | None (unreliable) |

---

## Architecture

### Unified Orchestrator Pattern

The `BackgroundBlockProductionOrchestrator` serves as the central coordinator:

```mermaid
flowchart TB
    subgraph Orchestrator["BackgroundBlockProductionOrchestrator"]
        Features["VRF-aware epoch monitoring<br/>Smart polling intervals - 2-15 min<br/>Atomic alarm + notification scheduling<br/>Slot wake-up handling<br/>Production monitoring integration<br/>Event stream emission"]
        State["Single State: BlockProductionState<br/>Single Repo: BlockProductionStateRepo"]
    end

    subgraph Events["Event Stream"]
        E1["epoch_transition"]
        E2["app_wake_up - PROOF!"]
        E3["monitoring_start"]
        E4["slot_produced"]
        E5["slot_failed"]
        E6["app_resumed"]
        E7["error"]
        E8["health_check"]
    end

    subgraph Metrics["MetricsReportingService"]
        M1["Listens to events<br/>Triggers targeted collection<br/>Periodic health checks - 30s"]
    end

    Orchestrator --> Events
    Events --> Metrics
```

### Old vs New Architecture

**Old Architecture (Deprecated but functional):**
- `EpochSlotSchedulerService` - Monitored epochs, scheduled slots
- `AlarmCallbackService` - Handled alarm callbacks
- `SlotNotificationManager` - Managed notifications separately
- **Problems**: State scattered, services could desync, no proof of alarm execution

**New Architecture (Current):**
- `BackgroundBlockProductionOrchestrator` - Single unified service
- `BlockProductionState` - Single state model
- Event-driven metrics - Proof of reliability via `app_wake_up` events
- Integrated notifications - Scheduled atomically with alarms

### Smart Epoch Monitoring

The orchestrator adjusts polling intervals based on VRF status:

- **VRF not started**: 15 minutes (base interval)
- **VRF in progress**: 5 minutes
- **VRF complete**: 2 minutes
- **VRF error**: 10 minutes

This adaptive approach saves battery while remaining responsive to epoch transitions.

---

## Platform Implementation

### Android Implementation

**Reliability**: 90-95% with exact alarms and foreground service

#### Components

1. **AlarmManager Integration** (`AlarmScheduler.kt`)
   - Uses `setExactAndAllowWhileIdle()` for precise timing
   - Bypasses Doze mode restrictions
   - Persists alarms in SharedPreferences

2. **Foreground Service** (`SlotMonitoringService.kt`)
   - Keeps app alive during slot monitoring
   - Type: `dataSync` (Android 12+ requirement)
   - Posts notification within 5 seconds
   - Prevents process termination

3. **Alarm Receiver** (`AlarmReceiver.kt`)
   - Receives alarm broadcasts
   - Starts foreground service immediately
   - Handles `BOOT_COMPLETED` for alarm rescheduling

4. **Boot Recovery** (`BootRescheduleService.kt`)
   - Automatically restores alarms after device reboot
   - Launches Flutter engine in background
   - Reschedules slots for current epoch
   - Self-terminates after completion

#### Android Flow

```mermaid
flowchart TB
    A["Alarm fires<br/>1 min before slot"] --> B["AlarmReceiver.onReceive()"]
    B --> C["Start SlotMonitoringService - FGS"]
    C --> D["Post notification"]
    D --> E["Launch app if needed"]
    E --> F["handleSlotWakeUp()"]
    F --> G["SlotMonitorService starts monitoring"]
    G --> H["Poll node status every 10s"]
    H --> I["Block produced or timeout"]
    I --> J["Stop FGS"]
```

#### Android 12+ Requirements

- **Exact Alarm Permission**: User must grant `SCHEDULE_EXACT_ALARM`
- **Foreground Service Type**: Must declare `foregroundServiceType="dataSync"`
- **Notification Required**: Must post notification within 5 seconds of FGS start
- **Fallback Strategy**: Expedited WorkManager if exact alarms unavailable

#### Android Permissions

**Runtime (require user approval):**
- `POST_NOTIFICATIONS` (Android 13+) - Display notifications
- `SCHEDULE_EXACT_ALARM` (Android 12+) - Schedule precise alarms
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` - Prevent aggressive killing

**Manifest-only (auto-granted):**
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_DATA_SYNC`
- `WAKE_LOCK`
- `RECEIVE_BOOT_COMPLETED`
- `INTERNET`
- `ACCESS_NETWORK_STATE`

---

### iOS Implementation

**Reliability**: 99% (Tier 1), 80-90% (Tier 2), 40-60% (Tier 3)

iOS has fundamental limitations for background execution, requiring a three-tier strategy:

#### Tier 1: Foreground Keep-Alive Mode (99% reliable)

**How it works:**
- User keeps app open during slot times
- WakeLock prevents screen from locking
- Periodic heartbeat prevents app suspension
- Node remains running with stable sync

**Requirements:**
- App must stay in foreground
- Screen on (minimum brightness recommended)
- Charger recommended
- Disable Auto-Lock in iOS Settings

**Best for**: Critical slots where maximum reliability is required

#### Tier 2: BGTask + Notifications (80-90% reliable)

**How it works:**
- Schedule `BGProcessingTask` + local notification
- Notification fires reliably at scheduled time
- User taps notification to open app
- App starts monitoring automatically

**Requirements:**
- Notification permission granted
- User must respond to notification
- User must tap within 1-2 minutes

**Best for**: Users willing to respond to alerts

#### Tier 3: BGTask Alone (40-60% reliable)

**How it works:**
- Schedule `BGProcessingTask` only
- iOS decides when (if) to execute
- 30-second execution limit
- Cannot start Rust node in this time

**Limitations:**
- iOS controls execution timing
- No guarantee task will run
- System resources must be available
- Battery level affects execution

**Best for**: "Set and forget" (but unreliable)

#### iOS Flow

```mermaid
flowchart TB
    A["User enables background production"] --> B["Schedule BGTask + Notification"]
    B --> C["Option A: User enables Keep-Alive"]
    B --> D["Option B: Notification fires"]
    B --> E["Option C: BGTask fires - maybe"]
    C --> C1["App stays foreground → 99% reliability"]
    D --> D1["User taps → App opens → Monitoring starts → 80-90%"]
    E --> E1["30s limit → Minimal impact → 40-60%"]
```

#### iOS Permissions

**Runtime:**
- `Notifications` (alert, sound, badge) - Required for all tiers

**Capability:**
- `Background Modes` (fetch, processing) - Configured in Info.plist

**No boot recovery**: User must open app after reboot to reschedule tasks

---

## Migration Guide

### From Old Services to Orchestrator

If you're using the deprecated services, migrate to the new orchestrator:

#### Old Code
```dart
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';

// Initialize
await EpochSlotSchedulerService.instance.initialize();

// Schedule slots
await EpochSlotSchedulerService.instance.scheduleEpochSlots();

// Get scheduled slots
final slots = EpochSlotSchedulerService.instance.getScheduledSlots();
```

#### New Code
```dart
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';

// Initialize
await BackgroundBlockProductionOrchestrator.instance.initialize();

// Epoch scheduling happens automatically!
// Just call onAppResumed() when app comes to foreground
await BackgroundBlockProductionOrchestrator.instance.onAppResumed();

// Get scheduled slots from state
final slots = BackgroundBlockProductionOrchestrator.instance.scheduledSlots;
```

#### Listen to Events

The orchestrator emits events for all major lifecycle points:

```dart
BackgroundBlockProductionOrchestrator.instance.events.listen((event) {
  switch (event.eventType) {
    case 'app_wake_up':
      print('Alarm fired! Battery: ${event.data['batteryLevel']}%');
      break;
    case 'slot_produced':
      print('Block produced successfully!');
      break;
    case 'slot_failed':
      print('Production failed: ${event.data['reason']}');
      break;
  }
});
```

### Deprecated Services

The following services are deprecated and will be removed in a future release:

- `EpochSlotSchedulerService` → Use `BackgroundBlockProductionOrchestrator`
- `AlarmCallbackService` → Use `BackgroundBlockProductionOrchestrator`
- `SlotNotificationManager` → Notifications integrated into orchestrator
- `NotificationStateRepository` → Use `BlockProductionState`

Old services continue to work but log deprecation warnings.

---

## Permissions

### Automatic Permission Requests

Permissions are automatically requested at app startup (one-time on first launch):

1. Check `has_requested_permissions_at_startup` in SharedPreferences
2. If false (first launch):
   - **Android**: Request `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, battery optimization exemption
   - **iOS**: Request notification permissions (alert, sound, badge)
3. Set flag to true (prevents repeated requests)

**Managed by**: `_requestPermissionsAtStartup()` in `main.dart`

See [startup flow diagram](#startup-permission-flow) for details.

### Managing Permissions After First Launch

**Via App**: Settings → Background Production Settings → Grant Permissions

**Via System Settings**:
- **Android**: Settings → Apps → [App] → Permissions / Alarms & reminders / Battery
- **iOS**: Settings → [App] → Notifications / Background App Refresh

### Startup Permission Flow

```mermaid
flowchart TB
    A["App Startup"] --> B{"Check 'has_requested_permissions_at_startup'"}
    B -->|FALSE - first launch| C["[Android] Request POST_NOTIFICATIONS"]
    C --> D["[Android] Request SCHEDULE_EXACT_ALARM<br/>opens Settings"]
    D --> E["[Android] Request Battery Optimization Exemption"]
    E --> F["[iOS] Request Notifications"]
    F --> G["Set flag = TRUE"]
    B -->|TRUE - subsequent launches| H["Skip permission requests"]
```

### Permission Status Monitoring

The app monitors permission status and emits events:

**Android Events:**
- `android_exact_alarm_permission_granted/denied`
- `android_notification_permission_granted/denied`
- `android_battery_optimization_checked/disabled`

**iOS Events:**
- `ios_notification_permission_granted/denied`
- `ios_background_refresh_status_checked`

---

## Configuration

### Settings Screen

The Background Block Production settings screen provides comprehensive status and configuration options. The settings automatically refresh every 3 seconds to keep permission status, VRF state, and scheduled slots up-to-date.

### Environment Variables

Configure block production via `.env` file:

```bash
# Metrics collection interval for periodic health checks (seconds)
# Default: 30
METRICS_COLLECTION_INTERVAL_SECONDS=30

# Wake up time before slot (seconds)
# Allows time for app startup and node sync
# Default: 60 (1 minute before slot)
BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS=60

# Base epoch monitoring interval (seconds)
# Adjusted automatically based on VRF status:
# - VRF not started: 15 min (900s base)
# - VRF in progress: 5 min
# - VRF complete: 2 min
# - VRF error: 10 min
# Default: 900
EPOCH_MONITOR_BASE_INTERVAL_SECONDS=900
```

**Build with configuration:**
```bash
flutter run --dart-define-from-file=.env
```

### Platform-Specific Configuration

**Android** (`AndroidManifest.xml`):
- Declare permissions
- Register `AlarmReceiver` with `BOOT_COMPLETED` intent filter
- Declare `SlotMonitoringService` with `foregroundServiceType="dataSync"`
- Declare `BootRescheduleService`

**iOS** (`Info.plist`):
- Add `UIBackgroundModes`: `fetch`, `processing`
- Register BGTask identifiers: `com.usernode.app.slotmonitoring`

---

## Testing

### Test Categories

#### 1. Basic Orchestrator Lifecycle
- Initialize orchestrator successfully
- State persists across app restarts
- VRF status detected correctly
- Epoch monitoring intervals adjust based on VRF

#### 2. Slot Scheduling
- Slots scheduled when VRF completes
- Alarms fire at correct time (1 min before slot)
- Notifications delivered with alarms
- Alarms survive app closure (Android)

#### 3. Slot Monitoring
- Monitoring starts when alarm fires
- Block production completes successfully
- Failed production handled gracefully
- Timeout works (2-5 minutes depending on platform)

#### 4. Platform-Specific
**Android:**
- Exact alarms fire reliably
- Foreground service survives 3+ hours
- Boot recovery works (alarms restored after reboot)
- Battery optimization exemption works

**iOS:**
- BGTasks schedule correctly
- Notifications fire on time (100% reliable)
- Keep-Alive mode prevents sleep
- Notification tap opens app

#### 5. Error Scenarios
- No network connection
- Metrics endpoint down
- Insufficient permissions
- State corruption recovery
- Node offline during slot

### Platform-Specific Testing

**Android Devices (minimum 5 for OEM coverage):**
- Google Pixel (stock Android) - baseline
- Samsung Galaxy (One UI) - moderate optimization
- Xiaomi (MIUI) - aggressive killer
- Oppo/OnePlus - aggressive power management
- Budget device - memory pressure

**iOS Devices (minimum 2):**
- iPhone with iOS 16+
- iPad (optional)

### Test Scenarios

- App in foreground
- App in background
- App force-closed
- Device rebooted
- Low Power Mode (iOS)
- Battery Saver Mode (Android)
- Airplane mode during slot → reconnect before slot

---

## Troubleshooting

### Android: Alarms Not Firing

**Symptom**: Scheduled alarms don't wake the app

**Possible Causes:**
1. `SCHEDULE_EXACT_ALARM` permission denied
2. Battery optimization enabled
3. OEM-specific battery saver (Xiaomi, Oppo, Samsung)

**Solution:**
1. Settings → Background Production Settings → Check status
2. Grant "Alarms & reminders" permission
3. Disable battery optimization for app
4. Check OEM-specific settings:
   - **Xiaomi**: Battery & performance → App battery saver → No restrictions
   - **Samsung**: Battery → App power management → Unrestricted
   - **Oppo**: Battery → High background battery consumption → Allow

---

### Android: Notifications Not Showing

**Symptom**: No notifications for block production events

**Possible Causes:**
1. `POST_NOTIFICATIONS` permission denied (Android 13+)
2. Notification channel disabled
3. Do Not Disturb mode active

**Solution:**
1. Settings → Background Production Settings → Grant Permissions
2. Enable `POST_NOTIFICATIONS`
3. Android Settings → Apps → [App] → Notifications → Enable "Slot Monitoring" channel

---

### iOS: Background Tasks Not Executing

**Symptom**: Alarms/notifications don't fire reliably

**Possible Causes:**
1. Background App Refresh disabled
2. Low Power Mode active
3. iOS deprioritized background tasks (normal behavior)
4. Do Not Disturb mode

**Solution:**
1. **Enable Background App Refresh:**
   - Settings → General → Background App Refresh → On
   - Settings → [App] → Background App Refresh → On
2. **Disable Low Power Mode**: Settings → Battery
3. **Use app regularly** (iOS favors frequently-used apps)
4. **Consider Tier 1 approach**: Enable Keep-Alive for critical slots
5. **Best practice**: Keep device plugged in and WiFi connected during slots

**Note**: iOS background task execution is NOT guaranteed. For reliable monitoring, use Tier 1 (Keep-Alive) or Tier 2 (Notifications).

---

### Permission Revoked After Granted

**Symptom**: Permission was granted but now shows as denied

**Possible Causes:**
1. User manually revoked in system settings
2. App was uninstalled/reinstalled (resets permissions)
3. Android system revoked due to non-use

**Solution:**
1. Settings → Background Production Settings
2. Tap "Grant Permissions" button
3. Re-grant all required permissions

---

### Device Reboot Issues

**Android**: Should work automatically via `BootRescheduleService`

If alarms not restored after reboot:
1. Check `RECEIVE_BOOT_COMPLETED` permission in manifest
2. Verify boot receiver is registered
3. Check device logs for boot service execution
4. Manually open app to trigger reschedule

**iOS**: No automatic recovery

User must:
1. Open app after reboot
2. App will detect epoch transition on resume
3. Slots will be rescheduled automatically

---

### Epoch Transition Not Detected

**Symptom**: App doesn't reschedule slots when epoch changes

**Possible Causes:**
1. Epoch monitoring not running
2. Backend RPC not responding
3. App hasn't been opened in long time (iOS)

**Solution:**
1. Check orchestrator initialized: `isInitialized` should be true
2. Verify backend connectivity
3. Open app to trigger manual epoch check
4. Check logs for epoch monitoring activity

---

### Monitoring Timeout

**Symptom**: Slot monitoring times out without producing block

**Possible Causes:**
1. Node not synced
2. Node stopped/crashed
3. Network issues
4. VRF calculation failed

**Solution:**
1. Check node status: should be "running" and "synced"
2. Verify internet connection
3. Check VRF status in epoch info
4. Review node logs for errors
5. Restart node if necessary

---

## Best Practices

### For Android Users
1. **Grant all permissions on first launch**
2. **Whitelist app from battery optimization**
3. **Don't clear app data frequently** (resets permission flag)
4. **Keep app updated** (improvements in newer versions)

### For iOS Users
1. **Plan ahead**: Check upcoming slots in Slot Calculator
2. **Set reminders**: Enable notifications for 10-min alerts
3. **Use Keep-Alive for critical slots**: Open app early, enable mode
4. **Respond to notifications**: Tap within 1-2 minutes
5. **Keep device charged**: Connect to power during slots
6. **Disable Low Power Mode**: Improves background task reliability

### For Developers
1. **Always check permission status** before scheduling
2. **Handle permission denial gracefully** with clear error messages
3. **Re-check permissions on app resume** (catches system changes)
4. **Send permission events to metrics** (monitor grant/deny rates)
5. **Test on OEM devices** (Samsung, Xiaomi, Oppo)
6. **Set realistic user expectations** (iOS requires more involvement)

---

## Related Documentation

- [METRICS.md](./METRICS.md) - Metrics system with 42 event types
- [METRICS_FIELDS_REFERENCE.md](./METRICS_FIELDS_REFERENCE.md) - Detailed JSON field reference with iOS/Android platform differences

---

**Implementation Complete** ✅
**Ready for Production** 🚀
