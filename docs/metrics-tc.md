## Part 1: Metrics Collected

### A. Device Information
| Data Point | Description | Privacy |
|-----------|-------------|---------|
| Device ID | SHA-256 hashed, truncated to 16 chars | Pseudonymized |
| Device Manufacturer | e.g., Samsung, Apple | Not PII |
| Device Model | e.g., Galaxy S23, iPhone 15 | Not PII |
| OS Version | Android/iOS version | Not PII |
| Architecture | CPU architecture (arm64, etc.) | Not PII |
| Physical Device | Boolean (vs. emulator) | Not PII |

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

### E. Blockchain Node Metrics
- Peer ID (node network identity)
- Node running status
- Node sync status (connecting, syncing, synced, error)
- Connected peers count
- Best tip slot number and block hash
- Blockchain height
- Current epoch and global slot
- Won slots in current epoch
- Blocks produced/failed counts
- VRF evaluation status

### F. Wallet Metrics (Optional)
- Wallet balance (BigInt value)
- Wallet address (bech32m format)

### G. Event Tracking: used for understading the behaviour of the application in different states and modes.
- App lifecycle events (wake-up, resume, suspend)
- Alarm events (scheduled, fired, missed)
- Block production events (start, success, failure)
- Permission events (requested, granted, denied)
- Platform-specific events (foreground service, background tasks)

---

## Part 2: Collection Frequency

| Type | Frequency |
|------|-----------|
| Health Check | Every 30 seconds (configurable) |
| Event-Driven | Immediate on block production events |
| Sentry Errors | On crash/exception |
| Feedback | On user submission only |

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
| Permission | Purpose |
|-----------|---------|
| `INTERNET` | Network communication |
| `ACCESS_NETWORK_STATE` | Detect connectivity |
| `POST_NOTIFICATIONS` | Slot production alerts |
| `SCHEDULE_EXACT_ALARM` | Precise wake-up for block production |
| `USE_EXACT_ALARM` | Alternative alarm API |
| `WAKE_LOCK` | Prevent sleep during block production |
| `RECEIVE_BOOT_COMPLETED` | Reschedule alarms after reboot |
| `FOREGROUND_SERVICE` | Background block monitoring |
| `FOREGROUND_SERVICE_DATA_SYNC` | Data sync service type |
| Battery Optimization Exemption | Reliable background execution |

### iOS Permissions
| Permission | Purpose |
|-----------|---------|
| Notifications | Slot production alerts |
| Background Processing | Block production monitoring |

---

## Part 5: Data Storage

### Local Storage
| Data | Storage Type | Encryption |
|------|--------------|------------|
| Private Keys | Secure Storage (Keychain/Keystore) | ✅ OS-level |
| Public Keys | Secure Storage | ✅ OS-level |
| Wallet Addresses | Secure Storage | ✅ OS-level |
| Account Metadata | SharedPreferences | ❌ Plain text |
| User Preferences | SharedPreferences | ❌ Plain text |
| Block Production State | Local files | ❌ Plain text |

### Data Retention
- **Sentry**: 90 days (Sentry default)
- **Metrics Server**: Data will be kept during all the steps of testing.
- **Local Data**: Until app uninstalled or manually cleared
- **GitHub Issues**: Permanent
