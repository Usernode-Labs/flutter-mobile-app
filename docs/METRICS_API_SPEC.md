# Metrics API Specification

## API Call Details

**Method:** `POST`

**URL:** Direct endpoint URL configured in `apiMetricsEndpoint`
- Example: `https://your-api.com/v1/metrics`
- The URL is used directly without any path concatenation

**Headers:**
```
Content-Type: application/json
Accept: application/json
```

**Timeout:** 10 seconds

**Retry Policy:** None - failed requests are logged and dropped

---

## JSON Payload Structure

### Top Level (All MANDATORY)
```json
{
  "event": { ... },      // MANDATORY - Event metadata
  "app": { ... },        // MANDATORY - App-related metrics
  "node": { ... }        // MANDATORY - Node-related metrics
}
```

---

## Complete JSON Example with Field Types

```json
{
  "event": {
    "event_type": "health_check",                    // MANDATORY (string)
    "timestamp": "2025-11-17T10:30:45.123Z"         // MANDATORY (ISO 8601 string)
  },

  "app": {
    "runtime": {
      "app_state": "foreground",                    // MANDATORY (string: "foreground"|"inactive"|"background"|"detached"|"hidden")
      "app_version": "1.0.0",                       // MANDATORY (string)
      "app_build_number": "123",                    // MANDATORY (string)
      "app_uptime_ms": 3600000,                     // MANDATORY (integer)
      "keep_alive_mode_active": true,               // MANDATORY (boolean)
      "notifications_enabled": true                 // MANDATORY (boolean)
    },

    "platform": {
      "platform": "android",                        // MANDATORY (string: "android"|"ios")
      "platform_version": "13",                     // MANDATORY (string)
      "system_architecture": "arm64-v8a"            // OPTIONAL (string|null)
    },

    "device": {
      "device_id": "abc123...",                     // MANDATORY (string)
      "device_manufacturer": "Samsung",             // MANDATORY (string)
      "device_model": "SM-G991B",                   // MANDATORY (string)
      "is_physical_device": true                    // MANDATORY (boolean)
    },

    "battery": {
      "battery_level": 85,                          // MANDATORY (integer: 0-100)
      "battery_state": "discharging",               // MANDATORY (string: "full"|"charging"|"discharging"|"unknown")
      "battery_optimization_disabled": true,        // MANDATORY (boolean)
      "power_save_mode": false,                     // MANDATORY (boolean)
      "low_power_mode": false                       // MANDATORY (boolean)
    },

    "network": {
      "network_type": "wifi",                       // MANDATORY (string: "wifi"|"cellular"|"ethernet"|"none")
      "network_connected": true                     // MANDATORY (boolean)
    },

    "permissions": {
      "permission_notifications": true,             // MANDATORY (boolean)
      "permission_exact_alarms": true,              // MANDATORY (boolean)
      "permission_battery_optimization_exempt": true, // MANDATORY (boolean)
      "exact_alarms_permission": true,              // MANDATORY (boolean)
      "notification_permission": "authorized"       // MANDATORY (string: "authorized"|"denied"|"permanently_denied")
    },

    "foreground_service": {                         // OPTIONAL - Android only (entire object)
      "foreground_service_running": true,           // MANDATORY if object present (boolean)
      "wakelock_held": true                         // MANDATORY if object present (boolean)
    }
  },

  "node": {
    "identity": {
      "peer_id": "12D3KooW..."                      // OPTIONAL (string|null)
    },

    "status": {
      "node_running": true,                         // MANDATORY (boolean)
      "node_state": "running",                      // MANDATORY (string: "running"|"stopped"|"error")
      "node_sync_status": "synced",                 // OPTIONAL (string: "synced"|"syncing"|null)
      "node_best_tip_slot": 123456,                 // OPTIONAL (integer|null)
      "node_best_tip_hash": "3NKxyz...",           // OPTIONAL (string|null)
      "node_connected_peers": 42                    // MANDATORY (integer)
    },

    "consensus": {
      "current_epoch": 50,                          // OPTIONAL (integer|null)
      "current_global_slot": 123456,                // OPTIONAL (integer|null)
      "current_epoch_won_slots": 5,                 // OPTIONAL (integer|null)
      "current_epoch_produced": 4,                  // OPTIONAL (integer|null)
      "current_epoch_failed": 1,                    // OPTIONAL (integer|null)
      "total_won_slots": 250,                       // OPTIONAL (integer|null)
      "total_blocks_produced": 240,                 // OPTIONAL (integer|null)
      "total_blocks_failed": 10                     // OPTIONAL (integer|null)
    },

    "blockchain": {
      "blockchain_height": 123456,                  // OPTIONAL (integer|null)
      "blockchain_latest_block_hash": "3NKxyz...",  // OPTIONAL (string|null)
      "blockchain_latest_block_slot": 123456,       // OPTIONAL (integer|null)
      "blockchain_latest_block_timestamp": "2025-11-17T10:30:45.000Z" // OPTIONAL (ISO 8601 string|null)
    },

    "production": {
      "background_production_enabled": true         // MANDATORY (boolean)
    },

    "wallet": {
      "wallet_balance": 1234.56,                    // OPTIONAL (double|null)
      "wallet_address": "B62qxyz..."                // OPTIONAL (string|null)
    },

    "peers": [                                      // MANDATORY (array, can be empty)
      {
        "peer_id": "12D3KooW...",                   // MANDATORY (string)
        "address": "/ip4/1.2.3.4/tcp/8302",        // OPTIONAL (string|null)
        "best_tip": null,                           // OPTIONAL (string|null) - Not available in current implementation
        "best_tip_height": 123450,                  // OPTIONAL (integer|null)
        "best_tip_global_slot": 123450,             // OPTIONAL (integer|null)
        "best_tip_timestamp": null,                 // OPTIONAL (integer|null) - Not available in current implementation
        "connection_status": "connected",           // MANDATORY (string: "connected"|"connecting"|"disconnected")
        "connecting_details": null,                 // OPTIONAL (string|null) - Not available in current implementation
        "incoming": false,                          // MANDATORY (boolean)
        "time": 1700217045123                       // MANDATORY (integer - milliseconds since epoch)
      }
    ]
  }
}
```

---

## Field Type Summary

### Mandatory Fields (Always Present)
- `event.*` - All fields
- `app.runtime.*` - All fields
- `app.platform.platform` - OS name
- `app.platform.platform_version` - OS version
- `app.device.*` - All fields
- `app.battery.*` - All fields
- `app.network.*` - All fields
- `app.permissions.*` - All fields
- `node.status.node_running` - Running state
- `node.status.node_state` - State string
- `node.status.node_connected_peers` - Peer count
- `node.production.background_production_enabled` - Flag
- `node.peers[]` - Array (can be empty)
- `node.peers[].peer_id` - Peer identifier
- `node.peers[].connection_status` - Connection state
- `node.peers[].incoming` - Direction flag
- `node.peers[].time` - Timestamp

### Optional Fields (May Be Null/Absent)
- `app.platform.system_architecture` - CPU architecture
- `app.foreground_service.*` - Entire object (Android only)
- `node.identity.peer_id` - Node's peer ID
- `node.status.node_sync_status` - Sync state
- `node.status.node_best_tip_slot` - Latest slot
- `node.status.node_best_tip_hash` - Latest block hash
- `node.consensus.*` - All consensus fields
- `node.blockchain.*` - All blockchain fields
- `node.wallet.*` - All wallet fields
- `node.peers[].address` - Peer address
- `node.peers[].best_tip` - Not implemented yet
- `node.peers[].best_tip_height` - Peer's block height
- `node.peers[].best_tip_global_slot` - Peer's slot
- `node.peers[].best_tip_timestamp` - Not implemented yet
- `node.peers[].connecting_details` - Not implemented yet

---

## Configuration

Metrics are configured via **environment variables** at compile-time using `--dart-define-from-file=.env`:

### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `METRICS_ENABLED` | boolean | `false` | Enable/disable metrics collection |
| `METRICS_ENDPOINT` | string | `''` (empty) | Full metrics endpoint URL (e.g., https://api.example.com/v1/metrics) |
| `METRICS_INTERVAL` | integer | `30` | Reporting interval in seconds (1-3600) |

### Configuration Method

1. **Create/Edit `.env` file:**
   ```bash
   METRICS_ENABLED=true
   METRICS_ENDPOINT=https://metrics.myapp.com/v1/metrics
   METRICS_INTERVAL=30
   ```

2. **Build with environment variables:**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

3. **Validation:**
   - Endpoint must be non-empty when metrics are enabled
   - Interval is clamped to 1-3600 seconds
   - Configuration cannot be changed at runtime (requires rebuild)

### UI Access

- **Metrics Status Screen:** View-only interface showing current configuration and statistics
- **Statistics:** Success/failure counts, last report time, success rate
- **Manual Actions:** "Send Now" button for manual metric reporting, "Reset Stats" button

---

## Response Handling

**Success:** HTTP status 200-299
- Increments success counter
- Updates last report timestamp
- Logs at TRACE level

**Failure:** Any other status or exception
- Increments failure counter
- Logs at WARN/ERROR level
- Metrics are dropped (no retry)

---

## Data Sources

- **App Metrics:** device_info_plus, battery_plus, connectivity_plus, permission_handler, wakelock_plus, package_info_plus, PlatformAlarmService
- **Node Metrics:** RustBackendService.instance.getStatus() - provides blockchain state, peers, sync status
- **Wallet Metrics:** Optional callback (WalletDataCallback) if configured
