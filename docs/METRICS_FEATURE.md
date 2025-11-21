# Metrics Collection and Reporting Feature

## Overview

The metrics collection feature enables the app to automatically collect and report health metrics to a centralized API. This provides visibility into node performance, app state, device conditions, and blockchain synchronization across all running instances.

## Features

- **Compile-Time Configuration**: Metrics configured via environment variables at build time
- **Event-Driven + Periodic Reporting**: Metrics sent on specific events (alarm fired, slot produced, etc.) plus periodic health checks (configurable via METRICS_COLLECTION_INTERVAL_SECONDS, default: 5 seconds)
- **Cross-Platform**: Works on both Android and iOS, in all app states (foreground, background, terminated)
- **Comprehensive Metrics**: Collects 15 categories of metrics including app state, device info, battery, network, permissions, node status, blockchain data, and more
- **Failed Upload Handling**: Failed metrics are dropped (no retry mechanism)
- **Stats UI**: View-only interface showing configuration and real-time statistics

## Architecture

### Components

1. **MetricsCollectorService** (`lib/features/metrics/domain/services/metrics_collector_service.dart`)
   - Singleton service responsible for collecting all metrics from various sources
   - Uses parallel collection for efficiency
   - Integrates with platform channels, device plugins, and Rust backend

2. **MetricsReportingService** (`lib/features/metrics/domain/services/metrics_reporting_service.dart`)
   - Manages periodic reporting using Timer.periodic
   - Handles metrics upload to configured endpoint
   - Tracks success/failure statistics
   - Lifecycle methods: `start()`, `stop()`, `reportNow()`

3. **MetricsRepository** (`lib/features/metrics/data/repositories/metrics_repository.dart`)
   - HTTP client for API communication
   - Methods: `sendMetrics()`, `testConnection()`
   - 10-second timeouts, drops failed requests

4. **MetricsConfig** (`lib/features/metrics/presentation/controllers/metrics_config_provider.dart`)
   - Configuration provider using Riverpod
   - Reads from compile-time environment variables (AppConfig)
   - Auto-starts service at app initialization if enabled

5. **MetricsSettingsScreen** (`lib/features/metrics/presentation/screens/metrics_settings_screen.dart`)
   - Read-only UI showing current configuration
   - Real-time statistics display
   - Manual send functionality for testing

### Event-Driven Architecture

The metrics system uses **two collection strategies**:

1. **Periodic Health Checks** (Timer-based)
   - Triggered every 5 seconds by default (configurable via `METRICS_COLLECTION_INTERVAL_SECONDS`)
   - Collects **full metrics** with all 15 categories for comprehensive system state
   - Runs in all app states (foreground, background, terminated)

2. **Event-Driven Metrics** (Reactive)
   - Triggered by specific BlockProductionEvent emissions from BackgroundBlockProductionOrchestrator
   - Uses **targeted collection strategies** based on event type for optimal performance:
     - **Full**: Complete system state for critical events (epoch_transition, app lifecycle)
     - **Lightweight**: Battery + timestamp only for alarm proof-of-life (android_alarm_fired, ios_notification_delivered)
     - **Production-Focused**: Node status + consensus for slot monitoring (slot_produced, slot_failed, monitoring_poll)
     - **Minimal**: Event + peer ID only for lifecycle events (permissions, service start/stop)
   - Connected via `MetricsReportingService.startListeningToEvents()` in metrics_lifecycle_provider.dart
   - Listens to BackgroundBlockProductionOrchestrator.instance.events stream
   - Enables real-time tracking of **42 distinct event types**

**Complete Event Catalog**: See [METRICS_EVENTS.md](./METRICS_EVENTS.md) for comprehensive documentation of all 42 event types organized by collection strategy.

**Sync Status Collection**: The metrics collector reuses the existing `syncStatusProvider` from the UI layer (via ProviderContainer) to ensure consistency between displayed sync status and reported metrics. This eliminates calculation drift and handles all edge cases (null syncBlocks, peer height fallback, etc.).

### Platform Integration

#### Android
- Extended `AlarmMethodChannelHandler.kt` with methods:
  - `isForegroundServiceRunning()`: Check if foreground service is active
  - `isWakelockHeld()`: Check wakelock status
  - `getBackgroundTaskStats()`: Retrieve execution statistics
  - `incrementBackgroundTaskCount()`: Track task executions

#### iOS
- Extended `AppDelegate.swift` with methods:
  - `getBackgroundTaskStats()`: Retrieve execution statistics from UserDefaults
  - `incrementBackgroundTaskCount()`: Track task executions
- Extended `BGTaskSchedulerManager.swift`:
  - Added metrics tracking in `handleBGTask()`
  - Increments execution count on every background task

#### Flutter
- Updated `background_task_service.dart`:
  - Integrated metrics tracking in `callbackDispatcher()`
  - Tracks both successful and failed executions
  - Initializes `PlatformAlarmService` for metrics access

## Metrics Categories

The following categories are collected for **periodic health checks** (full metrics). Event-driven metrics use targeted strategies documented in [METRICS_EVENTS.md](./METRICS_EVENTS.md).

### 1. Event Metadata
- Event type (health_check for periodic, or specific event type for event-driven)
- Timestamp (ISO8601)
- Peer ID (if available)

### 2. App Metrics
- App state (foreground/background/inactive/detached/hidden)
- App version and build number
- App uptime (milliseconds)
- Keep-alive mode status

### 3. Platform Metrics
- Operating system
- Platform version
- System architecture

### 4. Device Metrics
- Device ID
- Manufacturer and model
- Physical vs simulator/emulator

### 5. Battery Metrics
- Battery level (percentage)
- Battery state (charging/discharging/full)
- Battery optimization status
- Power save mode
- Low power mode

### 6. Network Metrics
- Network type (wifi/cellular/ethernet/none)
- Connection status

### 7. Permissions Metrics
- Notification permission status
- Exact alarms permission (Android)
- Battery optimization exempt status

### 8. Node Metrics
- Node running status
- Node state (running/stopped/error)
- Sync status (synced/syncing)
- Best tip slot and hash
- Connected peers count

### 9. Consensus Metrics
- Current epoch and global slot
- Won slots statistics
- Block production metrics (successful/failed)

### 10. Blockchain Metrics
- Blockchain height
- Latest block hash, slot, and timestamp

### 11. Background Tasks Metrics
- Background production enabled status

### 12. Foreground Service Metrics (Android only)
- Service running status
- Wakelock held status

### 13. Notifications Metrics
- Notifications enabled status

### 14. Wallet Metrics
- Wallet balance
- Wallet address

### 15. Peers Metrics
- Peer ID, address, connection status
- Best tip information for each peer
- Incoming/outgoing connection type

## Configuration

### Via Environment Variables

Metrics are configured at **compile-time** using environment variables:

1. **Create/Edit `.env` file:**
   ```bash
   METRICS_ENABLED=true
   METRICS_ENDPOINT=https://metrics.myapp.com/v1/metrics
   METRICS_COLLECTION_INTERVAL_SECONDS=5
   ```

2. **Build with environment variables:**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

3. **Environment Variables:**
   - `METRICS_ENABLED` (boolean, default: `false`) - Enable/disable metrics collection
   - `METRICS_ENDPOINT` (string, default: `''`) - Full metrics endpoint URL
   - `METRICS_COLLECTION_INTERVAL_SECONDS` (integer, default: `5`) - Periodic health check interval in seconds (1-3600)

### Viewing Configuration

The Metrics Status screen provides a **read-only** view of:

1. **Configuration**: Current enabled status, endpoint URL, and reporting interval
2. **Statistics**: Success/failure counts, success rate, and last report time
3. **Manual Actions**:
   - "Send Now" button to manually trigger a metrics report
   - "Reset Stats" button to clear statistics counters

**Note**: Configuration cannot be changed at runtime. To modify settings, update the `.env` file and rebuild the app.

### Programmatic Access (Read-Only)

```dart
// Access the config provider (read-only)
final config = ref.read(metricsConfigProvider);

// Check if metrics are enabled
if (config.enabled) {
  print('Metrics endpoint: ${config.apiMetricsEndpoint}');
  print('Interval: ${config.intervalSeconds} seconds');
}

// Access reporting stats
final stats = MetricsReportingService.instance.getStats();
print('Success count: ${stats['success_count']}');
print('Failure count: ${stats['failure_count']}');
```

## API Integration

### Metrics Endpoint

**POST** `{METRICS_ENDPOINT}`

The endpoint URL is configured via the `METRICS_ENDPOINT` environment variable.

Request body: Complete metrics payload with all 15 categories (see Metrics Categories section)

Expected Response: HTTP 200-299 (any 2xx status code is considered success)

**Note**: The API response body is ignored. Only the status code matters for success/failure tracking.

## Usage Example

### 1. Configure Metrics via Environment Variables

1. Create or edit `.env` file in project root:
   ```bash
   METRICS_ENABLED=true
   METRICS_ENDPOINT=https://metrics.myapp.com/v1/metrics
   METRICS_COLLECTION_INTERVAL_SECONDS=5
   ```

2. Build the app with environment variables:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

3. Metrics will automatically start reporting on app launch if:
   - `METRICS_ENABLED=true`
   - `METRICS_ENDPOINT` is not empty
   - Network connectivity is available

### 2. View Metrics Status in App

1. Open the app and navigate to Metrics Status screen (if available in your app's navigation)
2. View current configuration (read-only):
   - Enabled status
   - Endpoint URL
   - Reporting interval
3. Monitor real-time statistics:
   - Status (Running/Stopped)
   - Success/Failure counts
   - Success rate percentage
   - Last report timestamp

### 3. Manual Testing

- Tap "Send Now" to manually trigger a metrics report
- Useful for testing API connectivity
- Snackbar confirms successful send

### 4. Verify Metrics are Being Sent

Check your metrics API logs to verify reports are being received:
- Reports sent every X seconds (as configured)
- Each report contains full metrics payload (2-5 KB)
- Failed uploads are logged but not retried

## Troubleshooting

### Metrics Not Sending

1. **Check Environment Variables**
   - Verify `.env` file contains correct values
   - Ensure `METRICS_ENABLED=true`
   - Verify `METRICS_ENDPOINT` is not empty
   - Confirm `METRICS_COLLECTION_INTERVAL_SECONDS` is valid (1-3600 seconds)

2. **Rebuild the App**
   - Environment variables are compile-time, not runtime
   - After changing `.env`, rebuild: `flutter run --dart-define-from-file=.env`
   - Ensure the build process loads the `.env` file

3. **Check Network Connectivity**
   - Ensure device has internet access
   - Verify endpoint URL is reachable from device
   - Check firewall/network restrictions

4. **Review Statistics in App**
   - Check failure count - high failures indicate API issues
   - Verify last report time is recent
   - Use "Send Now" to test immediate reporting

### Common Issues

**Issue**: Metrics not collected in background (Android)
- **Solution**: Ensure battery optimization is disabled for the app
- **Solution**: Grant "Schedule exact alarms" permission (Android 12+)

**Issue**: Background tasks not executing (iOS)
- **Solution**: iOS controls background execution - frequency is best-effort
- **Solution**: Ensure notification permissions are granted
- **Solution**: Keep app active periodically to maintain background task schedule

**Issue**: High failure rate
- **Solution**: Verify API endpoint is reachable and responding correctly
- **Solution**: Check network connectivity
- **Solution**: Ensure API returns expected status codes (200/201)

## Performance Considerations

- Metrics collection uses parallel execution for efficiency
- Failed uploads are dropped immediately (no retry overhead)
- Background task tracking uses SharedPreferences/UserDefaults (lightweight)
- Timer-based reporting is suspended when app is fully terminated
- Metrics payload size is typically 2-5 KB per report

## Privacy & Security

- Device ID uses platform-specific identifiers (Android ID, iOS Vendor ID)
- No personally identifiable information is collected
- Wallet balance and address are optional fields
- API communication should use HTTPS in production
- Failed metrics are dropped (not persisted to disk)

## Development

### Running Tests

```bash
flutter test
```

### Debugging

Enable detailed logging in `MetricsReportingService`:

```dart
// lib/features/metrics/domain/services/metrics_reporting_service.dart
// Set log level to debug
LoggingService.instance.debug('Metrics report sent successfully', tag: LogTag.metrics);
```

### Adding New Metrics

1. Update `metrics_payload.dart` with new metric class
2. Add collection logic to `MetricsCollectorService`
3. Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
4. Update API documentation with new fields

## Future Enhancements

- Retry mechanism with exponential backoff (optional)
- Batch reporting to reduce API calls
- Configurable metric filtering (select which categories to send)
- Advanced consensus tracking (Phase 3 implementation)
- Metrics visualization in settings UI
- Export metrics to local file for debugging
