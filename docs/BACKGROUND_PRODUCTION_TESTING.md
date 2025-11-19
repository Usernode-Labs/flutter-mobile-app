# Background Block Production Testing & Validation Guide

## Overview

This guide provides comprehensive testing procedures for the unified Background Block Production system. The system consists of the `BackgroundBlockProductionOrchestrator` with event-driven metrics collection.

## Prerequisites

Before testing, ensure:

1. **Environment Configuration**: Create `.env` file with required variables
```bash
cp .env.example .env
# Edit .env and set:
METRICS_ENABLED=true
METRICS_ENDPOINT=https://your-metrics-endpoint.com/v1/metrics
METRICS_COLLECTION_INTERVAL_SECONDS=30
BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS=60
EPOCH_MONITOR_BASE_INTERVAL_SECONDS=900
```

2. **Build with Configuration**:
```bash
flutter run --dart-define-from-file=.env
```

3. **Required Permissions**:
   - Android: Exact alarm permission, notification permission, battery optimization disabled
   - iOS: Background fetch enabled, notification permission granted

## Test Categories

### 1. Basic Orchestrator Lifecycle

**Test 1.1: Orchestrator Initialization**

**Purpose**: Verify orchestrator starts correctly and initializes all components

**Steps**:
1. Launch app
2. Navigate to Node screen
3. Start node
4. Observe logs for orchestrator initialization

**Expected Results**:
- Log: "BackgroundBlockProductionOrchestrator initialized"
- `isInitialized` returns `true`
- State repository loads previous state (if any)
- Metrics service starts listening to events

**Validation**:
```dart
// Check via debug screen or logs
final orchestrator = BackgroundBlockProductionOrchestrator.instance;
assert(orchestrator.isInitialized == true);
final snapshot = await orchestrator.getStateSnapshot();
print(snapshot); // Should show current state
```

**Test 1.2: Orchestrator Shutdown**

**Purpose**: Verify clean shutdown and resource cleanup

**Steps**:
1. With orchestrator running
2. Stop node
3. Observe logs for shutdown sequence

**Expected Results**:
- All timers cancelled
- Event subscriptions cancelled
- State persisted to SharedPreferences
- Metrics service stops listening
- No memory leaks or orphaned timers

---

### 2. VRF-Aware Epoch Monitoring

**Test 2.1: VRF Not Started**

**Purpose**: Verify smart polling when VRF hasn't started

**Steps**:
1. Start node at beginning of new epoch
2. Observe epoch monitoring logs
3. Note polling interval

**Expected Results**:
- Initial epoch check happens immediately
- Subsequent checks every 15 minutes (900s base interval)
- Log: "VRF not started, checking again in 15m0s"
- No slots scheduled

**Test 2.2: VRF In Progress**

**Purpose**: Verify increased polling frequency during VRF calculation

**Steps**:
1. Wait for VRF calculation to start
2. Observe monitoring interval changes

**Expected Results**:
- Polling interval reduces to 5 minutes (300s)
- Log: "VRF in progress, checking again in 5m0s"
- Still no slots scheduled

**Test 2.3: VRF Complete**

**Purpose**: Verify slot scheduling when VRF finishes

**Steps**:
1. Wait for VRF calculation to complete
2. Observe slot scheduling

**Expected Results**:
- Polling interval reduces to 2 minutes (120s)
- Log: "VRF complete, scheduling X slots"
- Slots scheduled with alarms
- Notifications scheduled atomically
- Event emitted: `epoch_transition`
- Metrics event captured with VRF completion

**Test 2.4: VRF Error**

**Purpose**: Verify handling of VRF calculation failures

**Steps**:
1. Simulate or observe VRF error state
2. Observe recovery behavior

**Expected Results**:
- Polling interval increases to 10 minutes (600s)
- Log: "VRF error, will retry in 10m0s"
- No slots scheduled
- Error event emitted with details

---

### 3. Slot Scheduling & Alarms

**Test 3.1: Normal Slot Scheduling**

**Purpose**: Verify slots are scheduled correctly with alarms

**Setup**: VRF complete with won slots

**Steps**:
1. Ensure VRF is complete
2. Trigger epoch check
3. Verify scheduled slots

**Expected Results**:
- All won slots scheduled
- Alarms set for (slot_time - WAKE_BEFORE_SLOT_SECONDS)
- Notifications scheduled for same time
- State persisted with scheduled slots
- Log shows: "Scheduled X slots with alarms and notifications"

**Validation**:
```dart
final slots = BackgroundBlockProductionOrchestrator.instance.scheduledSlots;
assert(slots.isNotEmpty);
for (final slot in slots) {
  assert(slot.alarmScheduled == true);
  assert(slot.notificationScheduled == true);
  // Wake time should be 60s before slot (default)
  final expectedWakeTime = slot.slotTime.subtract(Duration(seconds: 60));
  assert(slot.wakeTime.difference(expectedWakeTime).abs() < Duration(seconds: 1));
}
```

**Test 3.2: Alarm Firing (Wake Up)**

**Purpose**: Verify alarm fires and triggers slot monitoring

**Prerequisites**: At least one slot scheduled

**Steps**:
1. Wait for alarm to fire (or use manual trigger for testing)
2. Observe wake-up behavior
3. Check background activity

**Expected Results**:
- App wakes up (foreground service starts on Android)
- Log: "Alarm fired for slot X"
- Event emitted: `app_wake_up` with battery level
- Metrics collected immediately (lightweight)
- Metrics payload includes:
  - Event type: "app_wake_up"
  - Battery level (proof alarm worked!)
  - Timestamp
- Node checked/started if needed
- Slot monitoring begins

**Proof of Reliability**:
The `app_wake_up` event with battery level proves the alarm actually fired! Check metrics endpoint for these events.

**Test 3.3: Multiple Slot Scheduling**

**Purpose**: Load test with many slots

**Setup**: Epoch with 10+ won slots

**Steps**:
1. Schedule epoch with many slots
2. Verify all alarms set correctly
3. Check alarm manager (Android) or bg tasks (iOS)

**Expected Results**:
- All slots scheduled without errors
- Alarms don't interfere with each other
- State contains all slots
- Platform limits respected (Android: no limit, iOS: check BGTaskScheduler)

---

### 4. Slot Monitoring & Block Production

**Test 4.1: Successful Block Production**

**Purpose**: Verify complete production flow from wake to success

**Steps**:
1. Wait for alarm to fire
2. Let monitoring complete successfully
3. Observe success flow

**Expected Results**:
- Monitoring starts: Event `monitoring_start`
- Node remains running throughout
- Block produced successfully
- Event emitted: `slot_produced` with result
- Metrics collected (production-focused):
  - Node state
  - Consensus info
  - Production details
- Success notification shown
- Slot marked as completed in state
- Foreground service stops (Android)

**Test 4.2: Failed Block Production**

**Purpose**: Verify error handling during production

**Steps**:
1. Simulate production failure (e.g., node crash)
2. Observe failure flow

**Expected Results**:
- Monitoring detects failure
- Event emitted: `slot_failed` with error
- Metrics collected with failure details
- Failure notification shown (optional)
- Slot marked as failed in state
- System recovers gracefully

**Test 4.3: Monitoring Timeout**

**Purpose**: Verify timeout handling

**Steps**:
1. Let monitoring run past slot time
2. Observe timeout behavior

**Expected Results**:
- Monitoring cancelled after timeout
- Event emitted: `slot_failed` (timeout)
- Resources cleaned up
- State updated

---

### 5. Event-Driven Metrics

**Test 5.1: Event Stream Connection**

**Purpose**: Verify metrics service receives events

**Steps**:
1. Start orchestrator
2. Start metrics service
3. Connect event listener
4. Trigger various events

**Expected Results**:
- Metrics service subscribes to event stream
- All events received by metrics handler
- Log: "Started listening to block production events for metrics"

**Validation**:
```dart
// Enable trace logging to see all events
LoggingService.instance.setLogLevel(LogLevel.trace);

// Trigger epoch check
await BackgroundBlockProductionOrchestrator.instance.onAppResumed();

// Should see:
// - Epoch transition event (if epoch changed)
// - Metrics collection triggered
// - Metrics sent to API
```

**Test 5.2: Lightweight Metrics (app_wake_up)**

**Purpose**: Verify minimal metrics on alarm wake-up

**Steps**:
1. Wait for alarm to fire
2. Observe metrics payload

**Expected Results**:
- Event type: "app_wake_up"
- Minimal payload:
  - Battery level (proof!)
  - App state
  - Timestamp
- No full node metrics
- No wallet data
- Fast collection (< 1 second)

**Test 5.3: Production Metrics (slot_produced/failed)**

**Purpose**: Verify detailed metrics for production events

**Steps**:
1. Complete a slot production (success or failure)
2. Observe metrics payload

**Expected Results**:
- Event type: "slot_produced" or "slot_failed"
- Production-focused payload:
  - Node state
  - Consensus info
  - Slot details
  - Production result
  - Battery level
- App metrics included
- Wallet data if available

**Test 5.4: Health Check Metrics**

**Purpose**: Verify full metrics on periodic health checks

**Steps**:
1. Wait for periodic timer (default 30s)
2. Observe metrics payload

**Expected Results**:
- Event type: "health_check"
- Complete payload:
  - All app metrics
  - All node metrics
  - Wallet data
  - System info
- Sent every METRICS_COLLECTION_INTERVAL_SECONDS

---

### 6. Lifecycle & App State

**Test 6.1: App Backgrounded**

**Purpose**: Verify system continues when app backgrounds

**Steps**:
1. Schedule slots
2. Background app (press home)
3. Wait for alarm
4. Check metrics for wake-up event

**Expected Results**:
- Alarm still fires (check metrics endpoint)
- `app_wake_up` event received
- Production completes in background
- App doesn't crash or suspend
- iOS: BGTaskScheduler keeps app alive briefly
- Android: Foreground service keeps app alive

**Test 6.2: App Resumed**

**Purpose**: Verify orchestrator checks epoch on resume

**Steps**:
1. Background app for extended time
2. Resume app
3. Observe lifecycle handler

**Expected Results**:
- Log: "Handling app resume..."
- Node restarted if needed (Android)
- Epoch check triggered: `onAppResumed()`
- If epoch changed: slots rescheduled
- Alarms verified still exist
- Log: "App resume handling complete"

**Test 6.3: Epoch Transition While Backgrounded**

**Purpose**: Verify epoch changes detected on resume

**Steps**:
1. Background app before epoch end
2. Wait for epoch to roll over
3. Resume app
4. Observe epoch detection

**Expected Results**:
- Lifecycle detects epoch change
- Old slots cancelled
- New epoch checked
- New slots scheduled (if VRF complete)
- Event: `epoch_transition`
- Metrics captured

---

### 7. Platform-Specific Tests

**Test 7.1: Android Exact Alarms**

**Purpose**: Verify Android alarm behavior

**Prerequisites**: SCHEDULE_EXACT_ALARM permission granted

**Steps**:
1. Schedule slots
2. Check Android alarm manager
3. Verify alarms set exactly at target time

**Expected Results**:
- Alarms use AlarmManager.setExactAndAllowWhileIdle()
- Alarms survive app closure
- Alarms fire even with battery optimization
- Foreground service starts on wake

**Validation**:
```bash
# Check scheduled alarms
adb shell dumpsys alarm | grep crypto_mobile_app
```

**Test 7.2: Android Battery Optimization**

**Purpose**: Verify alarms work despite battery restrictions

**Steps**:
1. Schedule slots
2. Enable battery optimization for app
3. Wait for alarm

**Expected Results**:
- Warning shown to user about battery optimization
- Alarms still fire (exact alarms exempt from Doze)
- Metrics prove alarm fired

**Test 7.3: iOS Background Tasks**

**Purpose**: Verify iOS BGTaskScheduler behavior

**Prerequisites**: Background fetch enabled in Info.plist

**Steps**:
1. Schedule slots
2. Background app
3. Wait for BGTaskScheduler to fire

**Expected Results**:
- BGTask registered for each slot
- Task fires approximately on time (iOS decides exact time)
- Task completes within time limit (30 seconds)
- Task sets success/failure result

**Note**: iOS is less reliable than Android for exact timing. Consider this in architecture.

**Test 7.4: Android Boot Completed**

**Purpose**: Verify slots rescheduled after device reboot

**Steps**:
1. Schedule slots
2. Reboot device
3. Launch app
4. Check scheduled slots

**Expected Results**:
- BOOT_COMPLETED receiver fires (if implemented)
- App reschedules alarms on boot
- Or: Alarms rescheduled when app next launches
- State restored from SharedPreferences

---

### 8. Error Scenarios & Edge Cases

**Test 8.1: No Network Connection**

**Purpose**: Verify graceful degradation without network

**Steps**:
1. Disable network
2. Trigger metrics collection
3. Observe error handling

**Expected Results**:
- Metrics collection completes
- API request fails gracefully
- Error logged (not crash)
- Retry on next interval
- Event still processed locally

**Test 8.2: Metrics Endpoint Down**

**Purpose**: Verify resilience to API failures

**Steps**:
1. Configure invalid metrics endpoint
2. Trigger metrics
3. Observe behavior

**Expected Results**:
- Connection test fails on start
- Warning logged
- Service continues anyway
- Periodic retries attempt
- App functionality unaffected

**Test 8.3: Insufficient Permissions**

**Purpose**: Verify handling of missing permissions

**Steps**:
1. Revoke exact alarm permission (Android)
2. Try to schedule slots
3. Observe error handling

**Expected Results**:
- Permission check fails
- Error logged clearly
- User notified
- No crash
- Graceful degradation

**Test 8.4: State Corruption**

**Purpose**: Verify recovery from corrupted state

**Steps**:
1. Manually corrupt SharedPreferences
2. Launch app
3. Observe recovery

**Expected Results**:
- Corrupted state detected
- State reset to default
- Log: "Failed to load state, using default"
- App initializes fresh
- No crash

**Test 8.5: Rapid Epoch Changes**

**Purpose**: Stress test with quick epoch transitions

**Steps**:
1. Use testnet with short epochs (if available)
2. Observe rapid scheduling/cancellation
3. Check for race conditions

**Expected Results**:
- Old slots cancelled cleanly
- New slots scheduled without overlap
- No duplicate alarms
- State remains consistent
- No memory leaks

---

## Validation Checklist

Use this checklist to ensure comprehensive testing:

### Core Functionality
- [ ] Orchestrator initializes successfully
- [ ] State persists across app restarts
- [ ] VRF status detected correctly
- [ ] Epoch monitoring intervals adjust based on VRF status
- [ ] Slots scheduled when VRF completes
- [ ] Alarms fire at correct time
- [ ] Notifications delivered with alarms
- [ ] Block production completes successfully
- [ ] Failed production handled gracefully

### Event System
- [ ] All 8 event types emit correctly
- [ ] Metrics service receives all events
- [ ] Event data includes required fields
- [ ] Event stream doesn't leak memory

### Metrics Collection
- [ ] Lightweight metrics on app_wake_up
- [ ] Production metrics on slot_produced/failed
- [ ] Full metrics on health_check
- [ ] Periodic timer works (every 30s default)
- [ ] Event-driven metrics work immediately
- [ ] Metrics sent to API successfully
- [ ] API failures handled gracefully

### Platform Compatibility
- [ ] Android exact alarms fire reliably
- [ ] Android foreground service works
- [ ] iOS BGTasks schedule correctly
- [ ] iOS background execution time sufficient
- [ ] Both platforms handle app lifecycle
- [ ] Both platforms survive device sleep

### Reliability
- [ ] No crashes during normal operation
- [ ] No memory leaks after extended use
- [ ] State remains consistent
- [ ] Recovery from errors works
- [ ] Permissions handled correctly
- [ ] Network failures handled gracefully

### Migration
- [ ] Old services deprecated but functional
- [ ] Migration guide followed successfully
- [ ] No breaking changes for existing users
- [ ] State migrates from old format (if applicable)

---

## Performance Benchmarks

Expected performance targets:

| Operation | Target Time | Acceptable Range |
|-----------|-------------|------------------|
| Orchestrator initialization | < 500ms | 100ms - 1s |
| Epoch check (VRF complete) | < 2s | 1s - 5s |
| Slot scheduling (10 slots) | < 1s | 500ms - 2s |
| Alarm wake-up to monitoring start | < 5s | 3s - 10s |
| Lightweight metrics collection | < 500ms | 100ms - 1s |
| Full metrics collection | < 3s | 2s - 5s |
| Event emission | < 10ms | 1ms - 50ms |

---

## Debugging Tools

### 1. State Snapshot

Get complete orchestrator state:
```dart
final snapshot = await BackgroundBlockProductionOrchestrator.instance.getStateSnapshot();
print(snapshot);
```

### 2. Event Listener

Debug event stream:
```dart
BackgroundBlockProductionOrchestrator.instance.events.listen((event) {
  print('EVENT: ${event.eventType}');
  print('  Time: ${event.timestamp}');
  print('  Data: ${event.toJson()}');
});
```

### 3. Metrics Stats

Check metrics service health:
```dart
final stats = MetricsReportingService.instance.getStats();
print(stats);
// Shows: success_count, failure_count, success_rate, last_report_time
```

### 4. Force Epoch Check

Manually trigger epoch check:
```dart
await BackgroundBlockProductionOrchestrator.instance.onAppResumed();
```

### 5. Log Levels

Enable trace logging to see all details:
```dart
LoggingService.instance.setLogLevel(LogLevel.trace);
```

---

## Known Issues & Limitations

### iOS Background Execution
- BGTaskScheduler doesn't guarantee exact timing
- Background time limited to ~30 seconds
- May be delayed or cancelled by system
- **Mitigation**: Use AlarmManager on Android for critical timing

### Android Battery Optimization
- Some OEMs aggressively kill background apps
- Even with exact alarms and foreground service
- **Mitigation**: Guide users to disable battery optimization

### Metrics Reliability
- Network failures can cause missed metrics
- API downtime affects all reporting
- **Mitigation**: Events still processed locally; metrics sent when possible

### State Persistence
- SharedPreferences can be cleared by system
- Rare but possible on low storage devices
- **Mitigation**: Recover gracefully with default state

---

## Support & Troubleshooting

### Common Issues

**Issue**: Alarms not firing
- Check exact alarm permission (Android)
- Check battery optimization settings
- Verify slots are actually scheduled
- Check `getStateSnapshot()` for scheduled slots

**Issue**: Metrics not being sent
- Verify METRICS_ENABLED=true in .env
- Check METRICS_ENDPOINT is valid
- Check network connectivity
- Look for API errors in logs
- Verify event listener connected

**Issue**: App crashes on wake-up
- Check for errors in handleSlotWakeUp()
- Verify node can restart successfully
- Check for permission issues
- Review crash logs in Sentry

**Issue**: Epoch transitions not detected
- Verify onAppResumed() called in lifecycle
- Check epoch monitoring is running
- Verify backend RPC responding
- Check VRF status in logs

### Log Tags

Search for these tags to debug specific areas:
- `[block_production]` - Orchestrator logs
- `[metrics]` - Metrics collection logs
- `[alarm]` - Platform alarm logs
- `[lifecycle]` - App lifecycle logs
- `[node]` - Rust backend logs

---

## Continuous Monitoring

For production deployment, monitor:

1. **Metrics API**: Check for regular app_wake_up events
   - Proves alarms are firing
   - Shows battery levels
   - Indicates app health

2. **Success Rate**: Track slot_produced vs slot_failed ratio
   - Target: > 95% success rate
   - Alert if drops below threshold

3. **Event Frequency**: Ensure all event types appear
   - app_wake_up should match scheduled slots
   - health_check every 30s (default)
   - epoch_transition once per epoch

4. **Error Patterns**: Monitor error events
   - Group by error type
   - Identify systematic issues
   - Prioritize fixes based on frequency

5. **Platform Distribution**: Compare Android vs iOS reliability
   - Identify platform-specific issues
   - Adjust strategy accordingly

---

## Conclusion

This testing guide covers all aspects of the unified background block production system. Follow the test cases systematically, use the debugging tools provided, and validate against the checklist.

The event-driven metrics provide proof of reliability - if you see `app_wake_up` events in your metrics endpoint, you know the alarms are firing!

For questions or issues, refer to:
- Orchestrator: `lib/core/services/background_block_production_orchestrator.dart`
- Events: `lib/core/models/block_production_event.dart`
- State: `lib/core/models/block_production_state.dart`
- Migration: `docs/BACKGROUND_PRODUCTION_MIGRATION.md`
