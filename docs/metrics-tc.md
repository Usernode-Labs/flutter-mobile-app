## Part 1: Metrics Collected

### A. Device Information

| Data Point          | Description                           | Privacy       |
| ------------------- | ------------------------------------- | ------------- |
| Device ID           | SHA-256 hashed, truncated to 16 chars | Pseudonymized |
| Device Manufacturer | e.g., Samsung, Apple                  | Not PII       |
| Device Model        | e.g., Galaxy S23, iPhone 15           | Not PII       |
| OS Version          | Android/iOS version                   | Not PII       |
| Architecture        | CPU architecture (arm64, etc.)        | Not PII       |
| Physical Device     | Boolean (vs. emulator)                | Not PII       |

### B. Battery & Power Metrics

- Battery level (percentage 0-100%)
- Battery state (charging, discharging, full)
- Battery optimization disabled status (Android)
- Power save mode status
- Low power mode status

### C. Network Metrics

- Network type (WiFi, cellular, ethernet, none)
- Network connectivity status (connected/disconnected)

### D. App State Metrics

- App lifecycle state (foreground, background, inactive)
- App version and build number
- App uptime (milliseconds)
- Wakelock/keep-alive mode status
- Notifications status
- Foreground service running status (Android)
- Native wakelock held status (Android)

### E. Blockchain Node Metrics

- Peer ID (node network identity)
- Node running status
- Node sync status (connecting, syncing, synced, error)
- Connected peers count
- Best tip slot number and block hash
- Blockchain height
- Latest block hash, slot, and timestamp
- Current epoch and global slot
- Won slots in current epoch
- Blocks produced/failed counts (current epoch)
- Total lifetime won slots
- Total lifetime blocks produced/failed
- VRF evaluation status (current and next epoch)
- Evaluated slots count (current epoch and since start)
- Background production enabled status

### F. Wallet Metrics (Optional)

- Wallet balance (BigInt value)
- Wallet address (bech32m format)

### G. Event Tracking

Used for understanding the behaviour of the application in different states and modes.

- App lifecycle events (wake-up, resume, suspend)
- Alarm events (scheduled, fired, missed)
- Block production events (start, success, failure)
- Permission events (requested, granted, denied)
- Platform-specific events (foreground service, background tasks)

### H. Connected Peers Data

For each metric submission, data about connected peers is also collected:

- Peer ID (peer's network identity)
- Wallet address
- Best tip height (peer's blockchain height)
- Best tip global slot
- Connection status
- Connection direction (incoming/outgoing)
- Connection timestamp

---

## Part 2: Collection Frequency

| Type          | Frequency                            |
| ------------- | ------------------------------------ |
| Health Check  | Every 30 seconds (configurable)      |
| Event-Driven  | Immediate on block production events |
| Sentry Errors | On crash/exception                   |
| Feedback      | On user submission only              |

---

## Part 3: Third-Party Services

### Sentry (Error Tracking)

- **Data Sent**: Crash reports, stack traces, app lifecycle breadcrumbs
- **Server Location**: Germany (EU)
- **PII Setting**: Disabled (`sendDefaultPii: false`)
- **Opt-in**: Enabled via environment configuration

### GitHub (Feedback System)

- **Data Sent**: User feedback, device info, optional screenshots
- **When**: Only when user submits feedback
- **Repository**: `Usernode-Labs/flutter-mobile-app`

### Usernode Labs API (Metrics & Registration)

- **Endpoints**:
  - `https://api.topo.usernodelabs.org/api/v1/register` (registration during the onboarding on the Mobile Application)
  - `https://api.topo.usernodelabs.org/api/v1/metrics` (metrics collected above sent to this endpoint)
- **Data Sent**: All metrics listed above
- **Encryption**: HTTPS/TLS

---

## Part 4: Permissions Required

### Android Permissions

| Permission                     | Purpose                               |
| ------------------------------ | ------------------------------------- |
| `INTERNET`                     | Network communication                 |
| `ACCESS_NETWORK_STATE`         | Detect connectivity                   |
| `POST_NOTIFICATIONS`           | Slot production alerts                |
| `SCHEDULE_EXACT_ALARM`         | Precise wake-up for block production  |
| ~~`USE_EXACT_ALARM`~~          | ~~Alternative alarm API~~ (removed for Google Play compliance) |
| `WAKE_LOCK`                    | Prevent sleep during block production |
| `RECEIVE_BOOT_COMPLETED`       | Reschedule alarms after reboot        |
| `FOREGROUND_SERVICE`           | Background block monitoring           |
| `FOREGROUND_SERVICE_DATA_SYNC` | Data sync service type                |
| Battery Optimization Exemption | Reliable background execution         |

### iOS Permissions

| Permission            | Purpose                     |
| --------------------- | --------------------------- |
| Notifications         | Slot production alerts      |
| Background Processing | Block production monitoring |

---

## Part 5: Data Storage

### Local Storage (Mobile App)

| Data                   | Storage Type                       | Encryption |
| ---------------------- | ---------------------------------- | ---------- |
| Private Keys           | Secure Storage (Keychain/Keystore) | OS-level   |
| Public Keys            | Secure Storage                     | OS-level   |
| Wallet Addresses       | Secure Storage                     | OS-level   |
| Account Metadata       | SharedPreferences                  | Plain text |
| User Preferences       | SharedPreferences                  | Plain text |
| Block Production State | Local files                        | Plain text |

### Server-Side Storage (Usernode Labs API)

| Data                 | Storage Type        | Encryption               |
| -------------------- | ------------------- | ------------------------ |
| Metrics data         | PostgreSQL database | Plain (HTTPS in transit) |
| Connected peers data | PostgreSQL database | Plain (HTTPS in transit) |
| User sessions        | Database-backed     | Plain                    |

### Data Retention

- **Sentry**: 90 days (Sentry default)
- **Metrics Server**: Configured for 30-day retention (cleanup scheduled)
- **Local Data**: Until app uninstalled or manually cleared
- **GitHub Issues**: Permanent

---

## Part 6: Data Management & Access Control

### Who Has Access to Metrics Data

#### 1. Public Access (Unauthenticated Users)

Anyone can view metrics data via public API endpoints, but only see **filtered fields**:

**Public Fields (19 fields):**

- Identifiers: `id`, `device_id`, `peer_id`
- Event: `event_type`, `event_timestamp`
- App info: `app_state`, `app_version`, `app_build_number`
- Platform: `platform`, `platform_version`, `system_architecture`
- Node status: `node_running`, `node_state`, `node_sync_status`
- Production: `current_epoch`, `current_epoch_won_slots`, `current_epoch_produced`, `current_epoch_failed`
- Wallet: `wallet_address` (address only, not balance)

#### 2. Admin Access (Authenticated Admin Users)

Admins see **all fields** including sensitive operational data:

**Additional Admin-Only Fields (36+ fields):**

- Device details: `device_manufacturer`, `device_model`, `is_physical_device`
- Battery: `battery_level`, `battery_state`, `battery_optimization_disabled`, `power_save_mode`, `low_power_mode`
- Network: `network_type`, `network_connected`
- Permissions: `permission_notifications`, `permission_exact_alarms`, `permission_battery_optimization_exempt`
- Services: `foreground_service_running`, `wakelock_held`
- Blockchain: `blockchain_height`, `blockchain_latest_block_hash`, `blockchain_latest_block_slot`, `blockchain_latest_block_timestamp`
- Consensus: `total_won_slots`, `total_blocks_produced`, `total_blocks_failed`
- VRF: `evaluated_current_epoch`, `evaluated_slots_since_start`, `current_epoch_vrf_evaluation_status`, `next_epoch_vrf_evaluation_status`
- Wallet: `wallet_balance`

#### 3. External Services

- Activity API uses separate API key authentication
- No access to metrics data

### Authentication Methods

| Endpoint Type      | Auth Method               | Who Can Access                   |
| ------------------ | ------------------------- | -------------------------------- |
| Metrics submission | None                      | Mobile devices                   |
| Registration       | None                      | Mobile devices                   |
| Metrics read (API) | Optional Bearer token     | Anyone (filtered) / Admin (full) |
| Admin panel        | Bearer token + admin flag | Admin users only                 |
