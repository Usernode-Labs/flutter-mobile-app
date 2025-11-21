# Background Block Production System Migration Guide

## Overview

The background block production system has been simplified from 3+ separate services into a single unified `BackgroundBlockProductionOrchestrator`. This migration guide helps transition from the old architecture to the new one.

## What Changed?

### Old Architecture (Deprecated)
- ❌ **EpochSlotSchedulerService** - Monitored epochs, scheduled slots
- ❌ **AlarmCallbackService** - Handled alarm callbacks
- ❌ **SlotNotificationManager** - Managed notifications separately
- ❌ **NotificationStateRepository** - Separate notification state
- ⚠️ **Metrics** - Timer-based only, no event awareness

### New Architecture (Current)
- ✅ **BackgroundBlockProductionOrchestrator** - Single unified service
- ✅ **BlockProductionState** - Single state model
- ✅ **Event-driven metrics** - Metrics triggered by production events
- ✅ **Integrated notifications** - Scheduled atomically with alarms
- ✅ **VRF-aware** - Smart epoch monitoring based on VRF status

## Migration Steps

### 1. Replace EpochSlotSchedulerService

**Old Code:**
```dart
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';

// Initialize
await EpochSlotSchedulerService.instance.initialize();

// Schedule slots
final result = await EpochSlotSchedulerService.instance.scheduleEpochSlots(
  epoch: currentEpoch,
);

// Get scheduled slots
final slots = EpochSlotSchedulerService.instance.getScheduledSlots();
```

**New Code:**
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

### 2. Replace AlarmCallbackService

**Old Code:**
```dart
import 'package:crypto_mobile_app/core/services/alarm_callback_service.dart';

// Handle alarm callback
await AlarmCallbackService.instance.handleAlarmCallback(slotNumber);
```

**New Code:**
```dart
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';

// Handle alarm callback
await BackgroundBlockProductionOrchestrator.instance.handleSlotWakeUp(slotNumber);
```

### 3. Replace SlotNotificationManager

**Old Code:**
```dart
import 'package:crypto_mobile_app/core/services/slot_notification_manager.dart';

// Schedule notifications
await SlotNotificationManager.instance.scheduleNotificationsForSlots(slots);
```

**New Code:**
```dart
// Notifications are now scheduled automatically when slots are scheduled!
// No separate call needed - they're integrated into the orchestrator.

// To enable/disable notifications:
// (This would be handled through the BlockProductionState)
```

### 4. Listen to Block Production Events

**New Feature - Event Stream:**
```dart
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';

// Listen to production lifecycle events
BackgroundBlockProductionOrchestrator.instance.events.listen((event) {
  switch (event.eventType) {
    case 'app_wake_up':
      print('Alarm fired! Slot: ${(event as BlockProductionAppWakeUpEvent).slotNumber}');
      break;
    case 'slot_produced':
      print('Block produced! 🎉');
      break;
    case 'slot_failed':
      print('Production failed');
      break;
    case 'epoch_transition':
      print('New epoch detected');
      break;
  }
});
```

### 5. Enable Event-Driven Metrics

**New Integration:**
```dart
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';

// Start metrics reporting
await MetricsReportingService.instance.start();

// Connect to block production events
MetricsReportingService.instance.startListeningToEvents(
  BackgroundBlockProductionOrchestrator.instance.events,
);
```

## Configuration Changes

### Startup Permission Requests (New)

Permissions are now automatically requested at app startup:
- **POST_NOTIFICATIONS** (Android 13+): Required for slot notifications
- **SCHEDULE_EXACT_ALARM** (Android 12+): Required for precise slot wake-ups
- **Battery Optimization Exemption**: Prevents Android from killing background tasks

Managed by `_requestPermissionsAtStartup()` in `main.dart`. One-time request on first launch.

**See**: [PERMISSIONS.md](./PERMISSIONS.md) for complete documentation.

### Environment Variables (New)

Add these to your `.env` file:

```bash
# Metrics Collection Interval (seconds) - updated from 30 to 5
METRICS_COLLECTION_INTERVAL_SECONDS=5

# Metrics endpoint configuration
METRICS_ENABLED=true
METRICS_ENDPOINT=https://your-metrics-api.com/v1/metrics

# Wake up N seconds before slot time
BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS=60

# Base epoch monitoring interval (seconds)
# Adjusted automatically based on VRF status
EPOCH_MONITOR_BASE_INTERVAL_SECONDS=900
```

## Benefits of the New Architecture

### 1. Simpler Code
- **60% less code**: 3 services → 1 orchestrator
- **Single state object**: No scattered SharedPreferences
- **Single entry point**: All production logic in one place

### 2. Better Reliability
- **Proof of life**: Metrics events prove alarms are firing
- **Atomic scheduling**: Alarms + notifications can't get out of sync
- **VRF-aware**: Never schedule incomplete VRF results
- **Smart polling**: Adapts interval based on VRF progress (2-15 min)

### 3. Easier Debugging
- **Event timeline**: See exact production lifecycle
- **State snapshot**: Complete state available anytime
- **Clear logging**: All logs from orchestrator

### 4. Event-Driven Metrics
- **Targeted collection**: Different metrics per event type
- **app_wake_up**: Lightweight (battery, time) - proves alarm worked!
- **slot_produced**: Production-specific (node state, consensus)
- **health_check**: Full metrics (everything)

## Deprecated Services

The following services are **deprecated** and will be removed in a future release:

- `EpochSlotSchedulerService` → Use `BackgroundBlockProductionOrchestrator`
- `AlarmCallbackService` → Use `BackgroundBlockProductionOrchestrator`
- `SlotNotificationManager` → Notifications now integrated
- `NotificationStateRepository` → State in `BlockProductionState`

## Backward Compatibility

The old services will continue to work for now but will log deprecation warnings. Please migrate to the new orchestrator as soon as possible.

## Troubleshooting

### Alarms not firing?
Check the orchestrator state:
```dart
final snapshot = await BackgroundBlockProductionOrchestrator.instance.getStateSnapshot();
print(snapshot);
```

### Metrics not reporting?
Verify event listener is connected:
```dart
// Make sure this is called after starting metrics
MetricsReportingService.instance.startListeningToEvents(
  BackgroundBlockProductionOrchestrator.instance.events,
);
```

### Need to debug lifecycle?
The orchestrator emits events for all major actions. Listen to the stream!

## Support

For questions or issues, please check:
- The orchestrator source code: `lib/core/services/background_block_production_orchestrator.dart`
- Event types: `lib/core/models/block_production_event.dart`
- State model: `lib/core/models/block_production_state.dart`
