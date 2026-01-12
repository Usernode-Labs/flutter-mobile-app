# Android Background Block Production Workflow

## Overview

The Android background block production system supports **two modes**:

1. **Event-Driven Mode** (Default) - Uses AlarmManager with exact alarms to wake the device only when needed. Battery efficient but may miss slots on aggressive OEMs.

2. **Persistent Foreground Mode** (Optional) - Keeps the app running continuously with a persistent notification. 100% reliable but uses more battery.

---

## Operating Modes Comparison

| Feature       | Event-Driven Mode           | Persistent Foreground Mode |
| ------------- | --------------------------- | -------------------------- |
| Reliability   | ~95% (varies by OEM)        | 100%                       |
| Battery Usage | Low                         | Higher (~5-10%/hour)       |
| Notification  | Only during slot monitoring | Always visible             |
| App Survival  | May be killed between slots | Always alive               |
| Best For      | Normal use                  | Critical block production  |

---

## Architecture Diagram

```mermaid
flowchart TB
    subgraph UI["Settings Screen - UI"]
        EventMode["Event-Driven Mode<br/>Default"]
        PersistMode["Persistent Foreground Mode<br/>Toggle in Settings"]
    end

    subgraph Flutter["Flutter Layer"]
        ForegroundTask["AndroidForegroundTaskController<br/>VRF monitoring<br/>Adaptive alarm scheduling"]
        PlatformAlarm["PlatformAlarmService - Dart<br/>scheduleAlarm() / startForegroundService()<br/>startPersistentForeground / stopPersistentForeground<br/>MethodChannel: com.usernode.app/alarm"]
    end

    subgraph Android["Android Native - Kotlin"]
        ChannelHandler["AlarmMethodChannelHandler<br/>scheduleExactAlarm / startForegroundService / cancelAlarm<br/>startPersistentForegroundSvc / stopPersistentForegroundSvc<br/>isPersistentForegroundRunning"]
        AlarmScheduler["AlarmScheduler<br/>Alarm Clock API<br/>setAlarmClock()"]
        SlotService["SlotMonitoringService<br/>ACTION_START_MONITORING<br/>ACTION_STOP_MONITORING<br/>ACTION_START_PERSISTENT<br/>ACTION_STOP_PERSISTENT"]
        AlarmReceiver["AlarmReceiver<br/>SLOT_ALARM<br/>BOOT_COMPLETED"]
    end

    EventMode --> Orchestrator
    PersistMode --> KeepAlive
    Orchestrator --> PlatformAlarm
    KeepAlive --> PlatformAlarm
    PlatformAlarm -->|"MethodChannel"| ChannelHandler
    ChannelHandler --> AlarmScheduler
    ChannelHandler --> SlotService
    AlarmScheduler --> AlarmReceiver
```

---

## Mode 1: Event-Driven (Default)

### Workflow

```mermaid
flowchart TB
    subgraph Step1["1. App Initialization"]
        A1["AndroidForegroundTaskController.onNodeStarted()"] --> A2["Start VRF polling + wakelock"]
    end

    subgraph Step2["2. Epoch Monitoring - every N minutes, VRF-aware"]
        B1["Query RustBackendService.getEpochInfo()"]
        B1 --> B2{"VRF Status?"}
        B2 -->|Complete| B3["Schedule alarms for won slots"]
        B2 -->|In Progress| B4["Retry in 2-10 min"]
    end

    subgraph Step3["3. Alarm Scheduling"]
        C1["PlatformAlarmService.scheduleAlarm()"] --> C2["AlarmManager.setAlarmClock()"]
        C2 --> C3["Save alarm ID to SharedPreferences"]
    end

    subgraph Step4["4. Alarm Fires"]
        D1["AlarmReceiver.onReceive(SLOT_ALARM)"] --> D2["Start SlotMonitoringService - foreground"]
        D2 --> D3["Send 'android_alarm_fired' to Flutter"]
        D3 --> D4["handleSlotWakeUp() in Orchestrator"]
    end

    subgraph Step5["5. Slot Monitoring - ~2 minutes"]
        E1["SlotMonitorService polls backend every 10s"] --> E2["Detect block production success/failure"]
        E2 --> E3["Stop foreground service when done"]
    end

    subgraph Step6["6. Boot Recovery"]
        F1["AlarmReceiver receives BOOT_COMPLETED"] --> F2["BootRescheduleService starts"]
        F2 --> F3["Creates headless Flutter engine"]
        F3 --> F4["Calls rescheduleAfterBoot()"]
    end

    Step1 --> Step2
    Step2 --> Step3
    Step3 --> Step4
    Step4 --> Step5
```

### Sequence Diagram: Alarm Scheduling

```mermaid
sequenceDiagram
    participant F as Flutter
    participant H as AlarmMethodChannelHandler
    participant S as AlarmScheduler
    participant M as AlarmManager

    F->>H: scheduleExactAlarm()
    H->>S: scheduleExactAlarm()
    S->>M: setAlarmClock()
    M-->>S:
    S-->>H:
    H-->>F: success
```

### Sequence Diagram: Alarm Firing

```mermaid
sequenceDiagram
    participant AM as AlarmManager
    participant AR as AlarmReceiver
    participant SMS as SlotMonitoringService
    participant F as Flutter

    AM->>AR: broadcast
    AR->>SMS: startForegroundService
    SMS->>SMS: startForeground()
    AR->>F: sendEventToFlutter("android_alarm_fired")
    SMS->>F: sendEventToFlutter("foreground_started")
    F->>F: handleSlotWakeUp()
```

---

## Mode 2: Persistent Foreground (Optional)

### Overview

When enabled via the Settings toggle, this mode:

1. Starts a persistent foreground service that runs continuously
2. Enables WakelockPlus to prevent screen sleep
3. Shows a persistent notification ("Block Production Active")
4. App survives being backgrounded or swiped away

### Workflow

```mermaid
flowchart TB
    subgraph Step1["1. User Enables Toggle in Settings"]
        A1["AndroidForegroundKeepAliveService.startKeepAlive()"]
    end

    subgraph Step2["2. Start Keep-Alive"]
        B1["PlatformAlarmService.startPersistentForegroundService()"]
        B1 --> B2["AlarmMethodChannelHandler handles method call"]
        B2 --> B3["SlotMonitoringService.ACTION_START_PERSISTENT"]
        B3 --> B4["startForeground() with persistent notification"]
        B5["WakelockPlus.enable()"]
        B6["Start heartbeat timer - every 30s"]
    end

    subgraph Step3["3. Running State"]
        C1["Service keeps app alive continuously"]
        C2["Notification: 'Block Production Active'"]
        C3["Event-driven alarms still work alongside"]
    end

    subgraph Step4["4. User Disables Toggle"]
        D1["AndroidForegroundKeepAliveService.stopKeepAlive()"]
        D1 --> D2["stopPersistentForegroundService()"]
        D2 --> D3["WakelockPlus.disable()"]
        D3 --> D4["Cancel heartbeat timer"]
    end

    Step1 --> Step2
    Step2 --> Step3
    Step3 --> Step4
```

### Sequence Diagram: Starting Persistent Mode

```mermaid
sequenceDiagram
    participant UI as Settings UI
    participant KA as AndroidForegroundKeepAliveService
    participant PA as PlatformAlarmService
    participant SMS as SlotMonitoringService

    UI->>KA: toggle ON
    KA->>PA: startPersistentForegroundService()
    PA->>SMS: MethodChannel "startPersistentForegroundService"
    SMS->>SMS: startPersistentMode()
    SMS->>SMS: startForeground()
    SMS-->>PA: success
    PA-->>KA: success
    KA->>KA: WakelockPlus.enable()
    KA-->>UI: success
```

---

## Critical Files & Line Numbers

### Android Native Code (Kotlin)

| File                           | Key Lines | Purpose                                          |
| ------------------------------ | --------- | ------------------------------------------------ |
| `AndroidManifest.xml`          | 14-20     | Background permissions                           |
| `AndroidManifest.xml`          | 77-100    | Service & receiver declarations                  |
| `MainActivity.kt`              | 15-26     | MethodChannel setup                              |
| `AlarmMethodChannelHandler.kt` | 72-173    | Method call handling                             |
| `AlarmMethodChannelHandler.kt` | 146-180   | **Persistent foreground handlers**               |
| `AlarmScheduler.kt`            | 22-91     | Exact alarm scheduling                           |
| `AlarmReceiver.kt`             | 14-28     | Broadcast receiver                               |
| `SlotMonitoringService.kt`     | 16-19     | Action constants (incl. PERSISTENT)              |
| `SlotMonitoringService.kt`     | 25-28     | **isPersistentModeActive flag**                  |
| `SlotMonitoringService.kt`     | 67-74     | Persistent mode action handling                  |
| `SlotMonitoringService.kt`     | 132-178   | **startPersistentMode() / stopPersistentMode()** |
| `BootRescheduleService.kt`     | 109-175   | Boot recovery with Flutter engine                |

### Flutter/Dart Code

| File                                            | Key Lines | Purpose                             |
| ----------------------------------------------- | --------- | ----------------------------------- |
| `platform_alarm_service.dart`                   | 23        | MethodChannel definition            |
| `platform_alarm_service.dart`                   | 340-375   | scheduleAlarm()                     |
| `platform_alarm_service.dart`                   | 471-503   | startForegroundService()            |
| `platform_alarm_service.dart`                   | 529-593   | **Persistent foreground methods**   |
| `android_foreground_keepalive_service.dart`     | 1-145     | **NEW: Android keep-alive service** |
| `background_block_production_orchestrator.dart` | 69-104    | initialize()                        |
| `background_block_production_orchestrator.dart` | 341-415   | handleSlotWakeUp()                  |
| `background_production_settings_screen.dart`    | 434-498   | **Android keep-alive UI section**   |
| `background_production_settings_screen.dart`    | 810-823   | **Toggle handler**                  |

---

## MethodChannel API

### Channel: `com.usernode.app/alarm`

#### Flutter -> Android

| Method                                | Parameters                             | Description                               |
| ------------------------------------- | -------------------------------------- | ----------------------------------------- |
| `scheduleExactAlarm`                  | alarmId, alarmTimeMs, slotNumber, data | Schedule exact alarm                      |
| `cancelAlarm`                         | alarmId                                | Cancel specific alarm                     |
| `cancelAllAlarms`                     | -                                      | Cancel all alarms                         |
| `startForegroundService`              | title, message, slotNumber             | Start slot-specific foreground            |
| `stopForegroundService`               | -                                      | Stop slot-specific foreground             |
| `startPersistentForegroundService`    | -                                      | **Start persistent mode**                 |
| `stopPersistentForegroundService`     | -                                      | **Stop persistent mode**                  |
| `isPersistentForegroundRunning`       | -                                      | **Check persistent mode status**          |
| `requestExactAlarmPermission`         | -                                      | Always returns true (SET_ALARM_CLOCK API) |
| `requestBatteryOptimizationExemption` | -                                      | Request battery exemption                 |
| `isBatteryOptimizationDisabled`       | -                                      | Check battery optimization                |

#### Android -> Flutter (Events)

| Event                                   | Data                           | Description                 |
| --------------------------------------- | ------------------------------ | --------------------------- |
| `android_alarm_fired`                   | slotNumber, alarmId, latencyMs | Alarm triggered             |
| `android_foreground_service_started`    | slotNumber                     | Slot monitoring started     |
| `android_foreground_service_stopped`    | slotNumber                     | Slot monitoring stopped     |
| `android_persistent_foreground_started` | -                              | **Persistent mode started** |
| `android_persistent_foreground_stopped` | -                              | **Persistent mode stopped** |
| `android_boot_reschedule_started`       | -                              | Boot recovery started       |
| `android_boot_reschedule_completed`     | slotsRescheduled               | Boot recovery done          |

---

## Permissions Required

```xml
<!-- AndroidManifest.xml:14-20 -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```

---

## UI: Settings Screen

The Background Block Production settings screen includes:

### Android-Specific Sections

1. **Permissions** - Shows exact alarm permission status
2. **Battery Optimization** - Shows/requests battery exemption
3. **Foreground Keep-Alive Mode** - Toggle for persistent mode
   - Status: ACTIVE / INACTIVE
   - Tips when active (charger, notification info)
4. **Won Slots This Epoch** - VRF status and upcoming slots
5. **Production Statistics** - Success/failure counts

---

## Testing Checklist

### Event-Driven Mode

- [ ] Alarms schedule correctly for won slots
- [ ] Alarms fire at correct time
- [ ] Foreground service starts on alarm
- [ ] Block production detected
- [ ] Foreground service stops after monitoring
- [ ] Alarms survive device reboot

### Persistent Foreground Mode

- [ ] Toggle ON starts foreground service
- [ ] Notification shows "Block Production Active"
- [ ] Toggle OFF stops foreground service
- [ ] Service survives app backgrounded
- [ ] Service survives app swiped away
- [ ] State syncs correctly on app resume
- [ ] Works alongside event-driven alarms
