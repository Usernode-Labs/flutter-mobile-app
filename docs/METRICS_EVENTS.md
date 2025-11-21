# Metrics Events Catalog

> Comprehensive documentation of all metrics event types in the background block production monitoring system.

## Overview

The metrics system uses **event-driven collection** to capture targeted data about the block production lifecycle, app state, and system health. Instead of collecting all metrics at regular intervals, different event types trigger different collection strategies optimized for performance and relevance.

**Total Event Types**: 42
**Collection Strategies**: 4 (Full, Lightweight, Production-Focused, Minimal)
**Platforms**: Android, iOS, Both

## Event-Driven Architecture

```
BackgroundBlockProductionOrchestrator
  └─> Emits BlockProductionEvent
       └─> MetricsReportingService.handleEvent()
            └─> MetricsCollectorService.collectMetricsForEvent()
                 └─> Targeted collection based on event type
                      └─> Send to API backend
```

## Collection Strategies

### Full Metrics Collection
**When**: Critical system state changes
**Metrics**: Event + Runtime + Platform + Device + Battery + Network + Permissions + Node Status + Blockchain + Consensus + Production + Wallet + Peers
**Purpose**: Complete system state snapshot for analysis

### Lightweight Metrics Collection
**When**: Alarm/wake events (proof of reliability)
**Metrics**: Event + Runtime + Battery Level + Peer ID
**Purpose**: Prove alarm system works with minimal overhead

### Production-Focused Metrics Collection
**When**: Slot monitoring and block production events
**Metrics**: Event + Runtime + Battery + Node Status + Consensus + Production + Foreground Service (Android)
**Purpose**: Track block production performance

### Minimal Metrics Collection
**When**: Permission requests, service lifecycle events
**Metrics**: Event + Runtime + Peer ID
**Purpose**: Record events without context overhead

---

## Event Type Reference

### Full Metrics Collection Events

#### `health_check`
**Platform**: Both
**When**: Periodic health checks (every 5 seconds, configurable)
**Collection**: Full
**Purpose**: Regular system health monitoring

**Event Data**:
```json
{
  "event_type": "health_check",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "currentEpoch": 123,
    "scheduledSlotsCount": 5,
    "nodeRunning": true
  }
}
```

#### `epoch_transition`
**Platform**: Both
**When**: New epoch detected by orchestrator
**Collection**: Full
**Purpose**: Track epoch changes and VRF status

**Event Data**:
```json
{
  "event_type": "epoch_transition",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "previousEpoch": 122,
    "newEpoch": 123,
    "slotsScheduled": 8,
    "vrfStatus": "available",
    "nextAlarmTime": "2025-11-21T12:30:00Z"
  }
}
```

#### `app_resumed`
**Platform**: Both
**When**: App returns to foreground
**Collection**: Full
**Purpose**: Check system state after app was backgrounded

**Event Data**:
```json
{
  "event_type": "app_resumed",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "currentEpoch": 123,
    "nodeRunning": true,
    "scheduledSlotsCount": 5
  }
}
```

#### `app_suspended`
**Platform**: Both
**When**: App goes to background
**Collection**: Full
**Status**: Not yet implemented

#### `android_boot_reschedule_completed`
**Platform**: Android
**When**: After device reboot, alarms rescheduled
**Collection**: Full
**Status**: Not yet implemented

---

### Lightweight Metrics Collection Events

#### `app_wake_up`
**Platform**: Both
**When**: Alarm fires and app wakes up for slot monitoring
**Collection**: Lightweight
**Purpose**: **PROOF OF LIFE** - Proves alarm system is working

**Event Data**:
```json
{
  "event_type": "app_wake_up",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "alarmTime": "2025-11-21T12:00:00Z",
    "batteryLevel": 85,
    "alarmLatencyMs": 234,
    "deviceState": "locked",
    "networkStatus": "wifi",
    "wakeSource": "alarm"
  }
}
```

#### `android_alarm_fired`
**Platform**: Android
**When**: AlarmReceiver receives alarm broadcast
**Collection**: Lightweight
**Purpose**: Track alarm execution at native Android level

**Event Data**:
```json
{
  "event_type": "android_alarm_fired",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "alarmId": "slot_12345",
    "slotNumber": 12345,
    "batteryLevel": 85,
    "networkState": "wifi"
  }
}
```

#### `ios_notification_delivered`
**Platform**: iOS
**When**: iOS notification delivered to device
**Collection**: Lightweight
**Status**: Not yet implemented

#### `ios_bgtask_executed`
**Platform**: iOS
**When**: iOS background task actually executes
**Collection**: Lightweight
**Purpose**: Track rare iOS background task execution

**Event Data**:
```json
{
  "event_type": "ios_bgtask_executed",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "executionDuration": 15000
  }
}
```

---

### Production-Focused Metrics Collection Events

#### `slot_monitoring_start`
**Platform**: Both
**When**: Slot monitoring begins after alarm fires
**Collection**: Production-Focused
**Purpose**: Track slot monitoring initialization

**Event Data**:
```json
{
  "event_type": "slot_monitoring_start",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "slotTime": "2025-11-21T12:00:00Z",
    "nodeState": "running",
    "currentEpoch": 123,
    "foregroundServiceActive": true
  }
}
```

#### `slot_produced`
**Platform**: Both
**When**: Block successfully produced for slot
**Collection**: Production-Focused
**Purpose**: Record successful block production

**Event Data**:
```json
{
  "event_type": "slot_produced",
  "timestamp": "2025-11-21T12:00:05Z",
  "event_data": {
    "slotNumber": 12345,
    "blockHash": "0x1234...",
    "blockHeight": 567890,
    "productionTime": "2025-11-21T12:00:05Z",
    "nodeState": "running",
    "consensusState": "synced"
  }
}
```

#### `slot_failed`
**Platform**: Both
**When**: Block production fails or slot is missed
**Collection**: Production-Focused
**Purpose**: Diagnose production failures

**Event Data**:
```json
{
  "event_type": "slot_failed",
  "timestamp": "2025-11-21T12:00:15Z",
  "event_data": {
    "slotNumber": 12345,
    "reason": "node_not_synced",
    "errorDetails": "Local height 100 blocks behind network",
    "nodeState": "running",
    "consensusState": "syncing"
  }
}
```

#### `monitoring_poll`
**Platform**: Both
**When**: During each node status poll while monitoring slot
**Collection**: Production-Focused
**Purpose**: Track slot monitoring progress

**Event Data**:
```json
{
  "event_type": "monitoring_poll",
  "timestamp": "2025-11-21T12:00:03Z",
  "event_data": {
    "slotNumber": 12345,
    "pollAttempt": 3,
    "nodeState": "running",
    "success": true
  }
}
```

#### `block_production_detected`
**Platform**: Both
**When**: Block production detected for a slot
**Collection**: Production-Focused
**Purpose**: Confirm block propagation

**Event Data**:
```json
{
  "event_type": "block_production_detected",
  "timestamp": "2025-11-21T12:00:06Z",
  "event_data": {
    "slotNumber": 12345,
    "blockHash": "0x1234...",
    "blockHeight": 567890,
    "detectionTime": "2025-11-21T12:00:06Z"
  }
}
```

#### `node_start_initiated`
**Platform**: Both
**When**: Node start is initiated before slot monitoring
**Collection**: Production-Focused
**Purpose**: Track node startup attempts

**Event Data**:
```json
{
  "event_type": "node_start_initiated",
  "timestamp": "2025-11-21T11:59:50Z",
  "event_data": {
    "reason": "node_stopped",
    "slotNumber": 12345
  }
}
```

#### `node_start_completed`
**Platform**: Both
**When**: Node start completes successfully
**Collection**: Production-Focused
**Purpose**: Track node startup performance

**Event Data**:
```json
{
  "event_type": "node_start_completed",
  "timestamp": "2025-11-21T11:59:55Z",
  "event_data": {
    "slotNumber": 12345,
    "startDurationMs": 5000,
    "peerId": "12D3KooW..."
  }
}
```

#### `node_start_failed`
**Platform**: Both
**When**: Node start fails
**Collection**: Production-Focused
**Purpose**: Diagnose node startup issues

**Event Data**:
```json
{
  "event_type": "node_start_failed",
  "timestamp": "2025-11-21T11:59:55Z",
  "event_data": {
    "slotNumber": 12345,
    "errorMessage": "Failed to bind port 8302",
    "attemptDurationMs": 5000
  }
}
```

---

### Minimal Metrics Collection Events

#### Alarm Events

##### `alarm_scheduled`
**Platform**: Both
**When**: Alarm/notification scheduled for slot
**Collection**: Minimal
**Purpose**: Track alarm scheduling

**Event Data**:
```json
{
  "event_type": "alarm_scheduled",
  "timestamp": "2025-11-21T11:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "alarmTime": "2025-11-21T12:00:00Z",
    "platform": "android",
    "alarmId": "slot_12345"
  }
}
```

##### `alarm_cancelled`
**Platform**: Both
**When**: Alarm cancelled
**Collection**: Minimal
**Status**: Not yet implemented

##### `alarm_missed`
**Platform**: Both
**When**: Expected alarm doesn't fire within tolerance
**Collection**: Minimal
**Purpose**: Detect alarm reliability issues

**Event Data**:
```json
{
  "event_type": "alarm_missed",
  "timestamp": "2025-11-21T12:05:00Z",
  "event_data": {
    "slotNumber": 12345,
    "expectedAlarmTime": "2025-11-21T12:00:00Z",
    "minutesPastExpected": 5
  }
}
```

---

#### Android Foreground Service Events

##### `android_foreground_service_started`
**Platform**: Android
**When**: Foreground service starts to keep app alive
**Collection**: Minimal
**Purpose**: Track service lifecycle

**Event Data**:
```json
{
  "event_type": "android_foreground_service_started",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "wakeLockAcquired": true
  }
}
```

##### `android_foreground_service_stopped`
**Platform**: Android
**When**: Foreground service stops
**Collection**: Minimal
**Purpose**: Track service lifecycle

**Event Data**:
```json
{
  "event_type": "android_foreground_service_stopped",
  "timestamp": "2025-11-21T12:05:00Z",
  "event_data": {
    "slotNumber": 12345,
    "reason": "monitoring_completed"
  }
}
```

##### `android_boot_alarm_rescheduled`
**Platform**: Android
**When**: Alarms rescheduled after device reboot
**Collection**: Minimal
**Purpose**: Verify boot receiver works

**Event Data**:
```json
{
  "event_type": "android_boot_alarm_rescheduled",
  "timestamp": "2025-11-21T10:00:00Z",
  "event_data": {
    "alarmsRescheduled": 8,
    "slotNumbers": [12345, 12346, 12347, 12348, 12349, 12350, 12351, 12352]
  }
}
```

##### `android_boot_reschedule_started`
**Platform**: Android
**When**: Device reboot alarm reschedule process starts
**Collection**: Minimal
**Status**: Not yet implemented

---

#### Android Permission Events

##### `android_exact_alarm_permission_requested`
**Platform**: Android
**When**: Exact alarm permission requested (Android 12+)
**Collection**: Minimal

##### `android_exact_alarm_permission_granted`
**Platform**: Android
**When**: Exact alarm permission granted
**Collection**: Minimal

##### `android_exact_alarm_permission_denied`
**Platform**: Android
**When**: Exact alarm permission denied
**Collection**: Minimal

##### `android_battery_optimization_checked`
**Platform**: Android
**When**: Battery optimization status checked
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "android_battery_optimization_checked",
  "timestamp": "2025-11-21T10:00:00Z",
  "event_data": {
    "isOptimized": false,
    "isWhitelisted": true
  }
}
```

##### `android_battery_optimization_requested`
**Platform**: Android
**When**: User prompted to disable battery optimization
**Collection**: Minimal

##### `android_battery_optimization_disabled`
**Platform**: Android
**When**: Battery optimization disabled
**Collection**: Minimal
**Status**: Not yet implemented

##### `android_notification_permission_requested`
**Platform**: Android
**When**: Notification permission requested (Android 13+)
**Collection**: Minimal

##### `android_notification_permission_granted`
**Platform**: Android
**When**: Notification permission granted
**Collection**: Minimal

##### `android_notification_permission_denied`
**Platform**: Android
**When**: Notification permission denied
**Collection**: Minimal

---

#### iOS Notifications & Background Tasks Events

##### `ios_notification_scheduled`
**Platform**: iOS
**When**: Local notification scheduled for slot
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "ios_notification_scheduled",
  "timestamp": "2025-11-21T11:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "scheduledTime": "2025-11-21T12:00:00Z"
  }
}
```

##### `ios_notification_tapped`
**Platform**: iOS
**When**: User taps iOS notification
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "ios_notification_tapped",
  "timestamp": "2025-11-21T12:00:10Z",
  "event_data": {
    "slotNumber": 12345
  }
}
```

##### `ios_bgtask_scheduled`
**Platform**: iOS
**When**: iOS BGTask scheduled
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "ios_bgtask_scheduled",
  "timestamp": "2025-11-21T11:00:00Z",
  "event_data": {
    "slotNumber": 12345,
    "scheduledTime": "2025-11-21T12:00:00Z"
  }
}
```

##### `ios_bgtask_expired`
**Platform**: iOS
**When**: iOS BGTask expired before completion
**Collection**: Minimal
**Status**: Not yet implemented

---

#### iOS Permission Events

##### `ios_notification_permission_requested`
**Platform**: iOS
**When**: iOS notification permission requested
**Collection**: Minimal

##### `ios_notification_permission_granted`
**Platform**: iOS
**When**: iOS notification permission granted
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "ios_notification_permission_granted",
  "timestamp": "2025-11-21T10:00:00Z",
  "event_data": {
    "alertsEnabled": true,
    "soundEnabled": true,
    "badgeEnabled": true
  }
}
```

##### `ios_notification_permission_denied`
**Platform**: iOS
**When**: iOS notification permission denied
**Collection**: Minimal

##### `ios_background_refresh_status_checked`
**Platform**: iOS
**When**: iOS background refresh status checked
**Collection**: Minimal

**Event Data**:
```json
{
  "event_type": "ios_background_refresh_status_checked",
  "timestamp": "2025-11-21T10:00:00Z",
  "event_data": {
    "status": "available"
  }
}
```

**Possible status values**: `available`, `denied`, `restricted`

---

#### Error Events

##### `error`
**Platform**: Both
**When**: Error occurs in production system
**Collection**: Minimal (but includes error context)

**Event Data**:
```json
{
  "event_type": "error",
  "timestamp": "2025-11-21T12:00:00Z",
  "event_data": {
    "errorType": "slot_monitoring_failed",
    "errorMessage": "Failed to start slot monitoring: Node not running",
    "stackTrace": "..."
  }
}
```

---

## Configuration

### Environment Variables

```bash
# Metrics collection interval (periodic health checks)
METRICS_COLLECTION_INTERVAL_SECONDS=5

# Enable/disable metrics
METRICS_ENABLED=true

# Metrics API endpoint
METRICS_ENDPOINT=https://api.topo.usernodelabs.org/api/v1/metrics
```

### Event Listener Setup

The event-driven metrics are automatically connected during app startup in `metrics_lifecycle_provider.dart`:

```dart
// Start metrics reporting service
MetricsReportingService.instance.start();

// Connect to orchestrator event stream
MetricsReportingService.instance.startListeningToEvents(
  BackgroundBlockProductionOrchestrator.instance.events,
);
```

---

## Event Flow Diagram

```
┌─────────────────────────────────────┐
│  BackgroundBlockProductionOrchestrator │
└──────────────┬──────────────────────┘
               │ emits BlockProductionEvent
               ▼
┌─────────────────────────────────────┐
│  MetricsReportingService             │
│  - Listens to event stream           │
│  - Determines collection strategy    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  MetricsCollectorService             │
│  - Collects targeted metrics         │
│  - Full / Lightweight / Production  │
│    / Minimal strategies              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  MetricsRepository                   │
│  - Sends to API backend              │
│  - https://api.topo...               │
└─────────────────────────────────────┘
```

---

## Implementation Status

| Status | Count | Event Types |
|--------|-------|-------------|
| ✅ Implemented | 37 | All production events working |
| 🚧 Not Yet Implemented | 5 | `app_suspended`, `alarm_cancelled`, `android_boot_reschedule_started`, `android_boot_reschedule_completed`, `android_battery_optimization_disabled`, `ios_notification_delivered`, `ios_bgtask_expired` |

---

## Related Documentation

- [METRICS_FEATURE.md](./METRICS_FEATURE.md) - Metrics feature overview
- [METRICS_API_SPEC.md](./METRICS_API_SPEC.md) - API specification and payload structure
- [background-block-production.md](./background-block-production.md) - Background production architecture
- [PERMISSIONS.md](./PERMISSIONS.md) - Permission handling guide

---

**Last Updated**: 2025-11-21
**Version**: 1.0.0
