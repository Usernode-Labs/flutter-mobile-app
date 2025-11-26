# Metrics Fields Reference

This document provides a detailed reference for all JSON fields extracted from the app's metrics system, including platform-specific availability and behavior differences between iOS and Android.

## Table of Contents

- [Detailed Field Reference](#detailed-field-reference)
- [Key Platform Differences](#key-platform-differences)
  - [iOS Limitations](#ios-limitations)
  - [Android Advantages](#android-advantages)
  - [Cross-Platform Considerations](#cross-platform-considerations)
  - [Caching Strategy](#caching-strategy)
- [Related Documentation](#related-documentation)

---

## Detailed Field Reference

| UI Column | JSON Field | iOS | Android | Description |
|-----------|------------|:---:|:-------:|-------------|
| **Background Prod** | `background_production_enabled` | ✅ | ✅ | Boolean indicating if app is configured for background block production. Currently hardcoded to `true` in `metrics_collector_service.dart:667`. On **iOS**, relies on wakelock + heartbeat timer (requires foreground). On **Android**, uses persistent foreground service (`SlotMonitoringService`) that survives backgrounding. |
| **Battery %** | `battery_level` | ✅ | ✅ | Integer 0-100 representing current battery percentage. Uses `battery_plus` plugin (cross-platform). Returns `0` on simulators/emulators or when unavailable. Collected fresh each time (no caching). Source: `metrics_collector_service.dart:324-330`. |
| **Battery State** | `battery_state` | ✅ | ✅ | String enum: `"charging"`, `"discharging"`, `"full"`, `"unknown"`. Uses `battery_plus` plugin. Converted via `batteryState.toString().split('.').last`. Available on physical devices only. Source: `metrics_collector_service.dart:358`. |
| **Batt Opt Disabled** | `battery_optimization_disabled` | ❌ | ✅ | Boolean indicating if app is exempted from battery optimization. **iOS**: Always returns `false` (concept doesn't exist). **Android**: Checks `PowerManager.isIgnoringBatteryOptimizations()` via native `AlarmMethodChannelHandler.kt:306-312`. Requires Android 6.0+ (API 23). **Cached for 5 minutes** to reduce native calls. |
| **Power Save** | `power_save_mode` / `low_power_mode` | ✅ | ✅ | Two derived booleans: `power_save_mode` = `batteryLevel < 20 && !charging`; `low_power_mode` = `batteryLevel < 20`. Calculated from `battery_plus` data, not from native power save APIs. Returns `false` when battery data unavailable. Source: `metrics_collector_service.dart:349-362`. |
| **Notifications** | `permission_notifications` (fallback: `notification_permission`) | ✅ | ✅ | Boolean (`permission_notifications`) and string (`notification_permission`: `"authorized"`/`"denied"`). Uses `permission_handler` plugin. **iOS**: Handled via `AppDelegate.swift:132-249` using `UNUserNotificationCenter`. **Android**: Requires explicit permission on Android 13+ (API 33); auto-granted on older versions. Native check in `AlarmMethodChannelHandler.kt:244-252`. **Cached for 1 minute**. |
| **Exact Alarms** | `permission_exact_alarms` (fallback: `exact_alarms_permission`) | ⚠️ | ✅ | Boolean indicating if app can schedule exact alarms. **iOS**: Concept doesn't exist; uses `notification_permission` as fallback/proxy. **Android**: Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+ (API 31); auto-granted on older versions. Checks `AlarmManager.canScheduleExactAlarms()` via `AlarmMethodChannelHandler.kt:210-216`. |
| **Batt Exempt** | `permission_battery_optimization_exempt` | ❌ | ✅ | Boolean indicating battery optimization exemption status. **iOS**: Always `false`. **Android**: Uses `PowerManager.isIgnoringBatteryOptimizations()`. Request flow opens `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` dialog. Reuses battery optimization cache if available. Source: `metrics_collector_service.dart:411-425`. |
| **FG Service** | `foreground_service_running` | ❌ | ✅ | Boolean indicating if Android foreground service is running. **iOS**: Returns `null` (not applicable). **Android**: Checks if `SlotMonitoringService` is in running services via `ActivityManager.getRunningServices()`. Shows persistent notification (ID 1001) while active. Native: `AlarmMethodChannelHandler.kt:355-364`. |
| **Wakelock** | `wakelock_held` | ❌ | ✅ | Boolean indicating if wakelock is held. **iOS**: Returns `null` (not applicable). **Android**: Approximate check via `PowerManager` - returns `!isDeviceIdleMode && !isPowerSaveMode` on Android 6+. Cannot check app-specific wakelocks without root. Native: `AlarmMethodChannelHandler.kt:366-375`. |
| **Notif Enabled** | `notifications_enabled` | ✅ | ✅ | Boolean indicating if notifications are enabled. Uses `permission_handler` plugin's `Permission.notification.status.isGranted`. **Always fresh** (no caching, unlike `permission_notifications`). Part of `RuntimeMetrics`, checked each collection cycle. Source: `metrics_collector_service.dart:219-221`. |
| **Keep Alive** | `keep_alive_mode_active` | ✅ | ✅ | Boolean indicating if wakelock is active via `WakelockPlus.enabled`. **iOS**: Uses `IOSForegroundKeepAliveService` - wakelock + 30s heartbeat timer. Requires app in foreground (~99% reliability). **Android**: Uses `AndroidForegroundKeepAliveService` - persistent foreground service + wakelock + 30s heartbeat. Survives backgrounding (100% reliability). |

**Legend:** ✅ = Fully supported | ⚠️ = Partial/fallback | ❌ = Not applicable (returns `false` or `null`)

---

## Key Platform Differences

### iOS Limitations

- **No battery optimization concept** — `battery_optimization_disabled` and `permission_battery_optimization_exempt` always return `false`
- **No foreground service** — `foreground_service_running` and `wakelock_held` return `null`
- **Keep-alive requires foreground** — App must remain visible; ~99% reliability
- **Exact alarms don't exist** — Uses `BGTaskSchedulerManager` for background tasks; notification permission used as proxy
- **Background execution limited** — iOS aggressively suspends background apps

### Android Advantages

- **Full battery optimization control** — Can request exemption via `PowerManager` API
- **Persistent foreground service** — `SlotMonitoringService` survives app backgrounding/swiping
- **Keep-alive works in background** — 100% reliability even when app not visible
- **Granular permissions** — Exact alarms (12+), notifications (13+), battery optimization (6+)

### Cross-Platform Considerations

| Aspect | iOS | Android |
|--------|-----|---------|
| Keep-alive reliability | ~99% (foreground only) | 100% (background capable) |
| Battery drain | ~5-10%/hour | ~5-10%/hour |
| User action required | Keep app open, use Guided Access | Grant battery optimization exemption |
| Recommended setup | Connect charger, disable auto-lock | Connect charger, disable battery optimization |

### Caching Strategy

| Field | Cache TTL | Reason |
|-------|-----------|--------|
| `battery_optimization_disabled` | 5 minutes | Expensive native call |
| `permission_notifications` | 1 minute | Reduces permission checks |
| `notifications_enabled` | None | Runtime state, needs fresh data |
| Battery metrics | None | Values change frequently |

---

## Related Documentation

- [METRICS.md](./METRICS.md) — Complete metrics system documentation with event types and API specs
- [BACKGROUND_PRODUCTION.md](./BACKGROUND_PRODUCTION.md) — Background block production architecture
- [ANDROID_BACKGROUND_BLOCK_PRODUCTION_WORKFLOW.md](./ANDROID_BACKGROUND_BLOCK_PRODUCTION_WORKFLOW.md) — Android-specific implementation details
