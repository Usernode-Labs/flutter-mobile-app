# Background Block Production - Implementation Plan

## Executive Summary

**Android**: Full continuous background block production via Foreground Service (95%+ reliability)

**iOS**: Legitimate background modes required for continuous operation. Without server coordination and with 5-second latency requirement, pure background scheduling (BGProcessingTask) will **not meet your requirements**. We must use one of:
1. VoIP background mode (if P2P networking justifies it)
2. Audio background mode (risky for App Store)
3. Foreground-only mode with user education

---

## PLATFORM LIMITATIONS & CONSTRAINTS

### Android Constraints

| Constraint | Impact | Workaround | Severity |
|------------|--------|------------|----------|
| **Persistent Notification Required** | User always sees notification while service runs | Cannot hide; must be visible and non-dismissible | Medium |
| **Battery Drain Concerns** | 15-25% additional battery usage | Request battery optimization whitelist; educate users | Medium |
| **OEM-Specific Killing** | Xiaomi, Oppo, OnePlus aggressively kill background apps | Auto-restart via START_STICKY; user must whitelist app in OEM settings | High |
| **Android 12+ FGS Restrictions** | Cannot start FGS from background without user interaction | Must start from foreground; boot receiver handles restarts | Medium |
| **Doze Mode** | System may still restrict network in deep sleep | Use WAKE_LOCK; request battery optimization exemption | Low |
| **Memory Limits** | Service can be killed under extreme memory pressure | Save state every 30s; implement graceful restart | Medium |
| **User Can Force Stop** | User can manually stop service from settings | Detect and prompt user; cannot prevent | Low |
| **Data Usage** | P2P networking may consume significant data | Monitor usage; warn users; provide Wi-Fi-only option | Low |
| **Android 14+ Exact Alarm Restrictions** | User must grant SCHEDULE_EXACT_ALARM permission | Request at runtime; degrade gracefully if denied | Low |
| **Thermal Throttling** | CPU intensive VRF checks may trigger throttling | Monitor temperature; reduce frequency under thermal stress | Medium |

### iOS Constraints

| Constraint | Impact | Workaround | Severity |
|------------|--------|------------|----------|
| **No True Background Services** | Cannot run indefinitely without special entitlements | Use VoIP mode or require foreground | **Critical** |
| **BGProcessingTask Unreliable** | Latency: minutes to hours, not seconds | Cannot meet 5-second requirement; only for sync tasks | **Critical** |
| **VoIP Mode Abuse Detection** | Apple terminates apps misusing VoIP | Must have legitimate P2P networking justification | High |
| **App Store Review Risk** | Rejection if background mode unjustified | Document P2P networking clearly; be prepared for rejection | High |
| **Memory Limits (Strict)** | Background apps get ~50MB; terminated if exceeded | Aggressive memory management; save state frequently | **Critical** |
| **Suspension After 30s** | Without background mode, app suspended after 30s in background | Must use VoIP/audio mode or stay in foreground | **Critical** |
| **No Persistent Notifications** | Cannot show Android-style persistent notification | Users have no visual indicator service is running | Medium |
| **Low Power Mode** | Disables most background activity | Detect and warn users; cannot override | High |
| **Background Time Limits** | Even with VoIP, system may terminate under pressure | Save state constantly; auto-restart not guaranteed | High |
| **Network Quality of Service** | Background tasks get lower network priority | May affect P2P performance; cannot override | Medium |
| **PushKit Requirements** | VoIP push must trigger CallKit or face penalties | Register for PushKit but don't require push notifications | Medium |
| **Thermal Throttling** | More aggressive than Android on mobile | Monitor and reduce activity; no override capability | High |
| **No Boot Receiver** | Cannot auto-start on device boot | User must manually open app after restart | High |
| **Focus Modes** | Do Not Disturb and Focus can restrict background activity | Cannot override; users must configure manually | Medium |

### Cross-Platform Constraints

| Constraint | Both Platforms | Workaround | Severity |
|------------|----------------|------------|----------|
| **Battery Life Impact** | Continuous operation drains battery significantly | Educate users; recommend keeping device plugged in | High |
| **Network Dependency** | P2P connections require internet; cellular data costs | Provide offline mode indicators; support Wi-Fi-only | Medium |
| **Checkpoint Overhead** | Frequent state saves impact performance | Optimize serialization; use incremental checkpoints | Low |
| **User Expectations** | Users expect mobile apps to be lightweight | Clear communication about validator requirements | Medium |
| **App Updates** | Updates kill running service; manual restart needed | Detect version change; prompt user to restart service | Medium |
| **State Restoration Complexity** | Complex to restore exact node state after kill | Design for eventual consistency; accept minor gaps | High |

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Rust Core - State Persistence

#### Rust Persistence Module
- [ ] Create `usernode/crates/usernode/src/persistence.rs`
- [ ] Define `NodeCheckpoint` struct with all necessary state fields
  - [ ] `last_processed_slot: u64`
  - [ ] `block_producer_state: BlockProducerState`
  - [ ] `mempool_snapshot: Vec<Transaction>`
  - [ ] `peer_list: Vec<PeerInfo>`
  - [ ] `timestamp: SystemTime`
- [ ] Implement atomic save using temp file + rename pattern
- [ ] Implement checkpoint deserialization with error handling
- [ ] Add checkpoint versioning for future compatibility
- [ ] Write unit tests for save/restore cycle

#### Node Lifecycle Updates
- [ ] Update `usernode/crates/usernode/src/node/mod.rs`
- [ ] Add `checkpoint_manager: CheckpointManager` field to `Node`
- [ ] Add `last_checkpoint: Instant` field
- [ ] Implement `save_checkpoint()` method
- [ ] Implement `restore_from_checkpoint()` method
- [ ] Add periodic checkpoint logic to `run_forever()` event loop (every 30s)
- [ ] Implement `handle_memory_warning()` for immediate checkpoint save
- [ ] Add graceful shutdown with checkpoint save
- [ ] Test checkpoint/restore cycle doesn't corrupt state

#### Cargo Dependencies
- [ ] Add `jni` crate to `Cargo.toml` for Android JNI bridge
- [ ] Ensure `serde` and `bincode`/`serde_json` for serialization
- [ ] Add any platform-specific dependencies

---

### Phase 2: Android Implementation

#### Android Native Bridge (JNI)
- [ ] Create `usernode/crates/usernode/src/jni_bridge.rs`
- [ ] Implement `Java_..._startNode()` JNI function
  - [ ] Accept config path parameter
  - [ ] Initialize and return node handle (pointer)
  - [ ] Handle errors gracefully
- [ ] Implement `Java_..._stopNode()` JNI function
  - [ ] Graceful shutdown
  - [ ] Save checkpoint before stopping
- [ ] Implement `Java_..._getStatus()` JNI function for status queries
- [ ] Implement `Java_..._saveCheckpoint()` for manual checkpoint
- [ ] Add proper error handling and logging
- [ ] Test JNI functions with minimal Android app

#### Kotlin Native Bridge Wrapper
- [ ] Create `android/app/src/main/kotlin/com/usernode_labs/usernode/NativeBridge.kt`
- [ ] Declare external native methods matching Rust JNI functions
- [ ] Load native library in static block
- [ ] Add Kotlin wrapper methods with proper types
- [ ] Handle JNI exceptions and convert to Kotlin exceptions

#### Android Foreground Service
- [ ] Create `android/app/src/main/kotlin/com/usernode_labs/usernode/BlockProducerService.kt`
- [ ] Extend `Service` class
- [ ] Implement `onCreate()` - start foreground immediately
- [ ] Implement `onStartCommand()` with `START_STICKY` return
- [ ] Handle `ACTION_START` and `ACTION_STOP` intents
- [ ] Call native bridge to start/stop node
- [ ] Implement notification builder
  - [ ] Basic persistent notification
  - [ ] Show block producer status
  - [ ] Add action buttons (Pause, Stop)
- [ ] Implement `onDestroy()` with graceful shutdown
- [ ] Handle low memory conditions
- [ ] Add service lifecycle logging

#### Android Notification Updates
- [ ] Create notification channel for foreground service
- [ ] Design notification layout with status info
- [ ] Implement periodic notification updates with latest status
- [ ] Add notification actions (View, Pause, Stop)
- [ ] Handle notification action button clicks

#### Boot Receiver
- [ ] Create `android/app/src/main/kotlin/com/usernode_labs/usernode/BootReceiver.kt`
- [ ] Extend `BroadcastReceiver`
- [ ] Implement `onReceive()` to start foreground service on boot
- [ ] Check user preferences before auto-starting
- [ ] Add logging for boot events

#### Android Manifest Configuration
- [ ] Update `android/app/src/main/AndroidManifest.xml`
- [ ] Add `FOREGROUND_SERVICE` permission
- [ ] Add `FOREGROUND_SERVICE_DATA_SYNC` permission
- [ ] Add `POST_NOTIFICATIONS` permission
- [ ] Add `WAKE_LOCK` permission
- [ ] Add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission
- [ ] Add `RECEIVE_BOOT_COMPLETED` permission
- [ ] Declare `BlockProducerService` with `foregroundServiceType="dataSync"`
- [ ] Set `android:stopWithTask="false"` on service
- [ ] Declare `BootReceiver` with `BOOT_COMPLETED` intent filter

#### MainActivity Method Channel
- [ ] Update `android/app/src/main/kotlin/com/usernode_labs/usernode/MainActivity.kt`
- [ ] Create method channel `com.usernode_labs.usernode/block_producer`
- [ ] Implement `startForegroundService` method handler
- [ ] Implement `stopForegroundService` method handler
- [ ] Implement `getServiceStatus` method handler
- [ ] Implement `requestBatteryOptimizationExemption` method handler
- [ ] Add proper error handling and responses

---

### Phase 3: iOS Implementation

#### iOS Native Bridge (Swift/Objective-C)
- [ ] Create `ios/Runner/NodeBridge.swift`
- [ ] Import Rust FFI functions from static library
- [ ] Create Swift wrapper class `NodeBridge`
- [ ] Implement `startNode(configPath:)` method
- [ ] Implement `stopNode()` method
- [ ] Implement `getStatus()` method
- [ ] Implement `saveCheckpoint()` method
- [ ] Add memory warning observer
- [ ] Handle app lifecycle events (background/foreground)

#### iOS VoIP Background Mode
- [ ] Update `ios/Runner/Info.plist`
- [ ] Add `voip` to `UIBackgroundModes` array
- [ ] Update `ios/Runner/AppDelegate.swift`
- [ ] Import `PushKit` framework
- [ ] Create `PKPushRegistry` instance
- [ ] Implement `PKPushRegistryDelegate` protocol
- [ ] Implement `pushRegistry(_:didUpdate:for:)` for credentials
- [ ] Implement `pushRegistry(_:didReceiveIncomingPushWith:for:)` for pushes
- [ ] Start node when VoIP is registered
- [ ] Test background execution with VoIP mode

#### iOS Foreground-Only Mode (Fallback)
- [ ] Create `ios/Runner/ValidatorMode.swift` helper
- [ ] Implement screen wake lock (`isIdleTimerDisabled = true`)
- [ ] Implement screen dimming support
- [ ] Add foreground monitoring
- [ ] Warn user when app moves to background

#### iOS Memory Management
- [ ] Add memory warning observer in AppDelegate
- [ ] Call Rust checkpoint save on memory warning
- [ ] Implement aggressive memory cleanup
- [ ] Monitor memory usage and log warnings
- [ ] Test memory limits in background mode

#### iOS State Persistence
- [ ] Choose storage location (Documents directory)
- [ ] Ensure checkpoint path is accessible from Rust
- [ ] Test restore after app kill
- [ ] Test restore after device reboot

---

### Phase 4: Flutter Platform Integration

#### Abstract Service Interface
- [ ] Create `lib/core/services/block_producer_service.dart`
- [ ] Define abstract `BlockProducerService` class
- [ ] Define methods: `start()`, `stop()`, `getStatus()`
- [ ] Define `ServiceCapabilities` data class
- [ ] Create factory method `BlockProducerService.create()`

#### Android Service Implementation
- [ ] Create `lib/core/services/android_block_producer_service.dart`
- [ ] Implement `BlockProducerService` interface
- [ ] Create method channel instance
- [ ] Implement `startForegroundService()` via platform channel
- [ ] Implement `stopForegroundService()` via platform channel
- [ ] Implement `getServiceStatus()` via platform channel
- [ ] Implement `requestBatteryOptimizationExemption()`
- [ ] Create status stream from native callbacks
- [ ] Add error handling and logging

#### iOS Service Implementation
- [ ] Create `lib/core/services/ios_block_producer_service.dart`
- [ ] Implement `BlockProducerService` interface
- [ ] Create method channel instance
- [ ] Implement mode detection (VoIP vs foreground-only)
- [ ] Implement `start()` with appropriate mode
- [ ] Implement `stop()` method
- [ ] Implement wake lock for foreground mode
- [ ] Create status stream
- [ ] Add iOS-specific warnings and checks

#### Service Capabilities
- [ ] Implement `getCapabilities()` for Android
  - [ ] Set `supportsBackground: true`
  - [ ] Set `backgroundMode: 'foreground-service'`
  - [ ] Set `estimatedReliabilityPercent: 95`
- [ ] Implement `getCapabilities()` for iOS
  - [ ] Detect VoIP vs foreground mode
  - [ ] Set reliability estimates accordingly
  - [ ] Return iOS-specific limitations

#### Update RustBackendService
- [ ] Open `lib/features/node/data/repositories/rust_backend_service.dart`
- [ ] Remove direct `runForeverInNewThread()` call
- [ ] Delegate to platform-specific `BlockProducerService`
- [ ] Keep RPC communication working
- [ ] Handle service disconnections gracefully
- [ ] Add service health checks

---

### Phase 5: Flutter UI Updates

#### Settings Page - Block Production Section
- [ ] Open `lib/features/settings/presentation/pages/settings_page.dart`
- [ ] Add "Block Production" section
- [ ] Add toggle switch for enabling/disabling service
- [ ] Add platform-specific warnings
- [ ] Add battery optimization button (Android)
- [ ] Add capability info display
- [ ] Show current service status (running/stopped)
- [ ] Add manual restart button
- [ ] Show statistics: uptime %, missed slots

#### Android-Specific UI
- [ ] Add battery optimization exemption request dialog
- [ ] Show notification requirement warning
- [ ] Add OEM-specific instructions (Xiaomi, Oppo, etc.)
- [ ] Link to battery settings

#### iOS-Specific UI
- [ ] Create `lib/features/node/presentation/widgets/ios_validator_mode_explanation.dart`
- [ ] Create explanation dialog for iOS limitations
- [ ] Show VoIP mode status if available
- [ ] Show foreground mode instructions
- [ ] Add mode selection (VoIP vs Foreground)
- [ ] Warn about memory limits
- [ ] Add Low Power Mode detection and warning

#### Service Status Widget
- [ ] Create `lib/features/node/presentation/widgets/service_status_widget.dart`
- [ ] Show real-time service status
- [ ] Display current block production state
- [ ] Show last block produced timestamp
- [ ] Show peer count
- [ ] Color-code status (green/yellow/red)
- [ ] Add refresh button

#### Statistics Dashboard
- [ ] Create `lib/features/node/presentation/pages/validator_stats_page.dart`
- [ ] Show uptime percentage
- [ ] Show total blocks produced
- [ ] Show missed slots count
- [ ] Show service restart history
- [ ] Show battery usage estimate
- [ ] Graph of production over time
- [ ] Export diagnostics button

---

### Phase 6: Background Task Service Updates

#### Update Existing Background Task
- [ ] Open `lib/core/services/background_task_service.dart`
- [ ] Modify `_performSlotMonitoring()` to check native service health
- [ ] Add service restart logic if crashed
- [ ] Update to work with native service instead of direct Rust calls
- [ ] Keep notification scheduling functionality
- [ ] Add service watchdog functionality

---

### Phase 7: Notification System

#### Notification Configuration
- [ ] Update `lib/core/config/notification_config.dart`
- [ ] Add service status notification channels
- [ ] Add block production notification categories
- [ ] Configure priorities and importance levels

#### Local Notification Service
- [ ] Update `lib/core/services/local_notification_service.dart`
- [ ] Add method for service status notifications
- [ ] Add method for block production success notifications
- [ ] Add method for error/warning notifications
- [ ] Handle notification actions (open app, restart service)

---

### Phase 8: Testing & Validation

#### Android Testing
- [ ] Test foreground service starts correctly
- [ ] Test persistent notification appears
- [ ] Test service survives app closure
- [ ] Test service restarts after force kill
- [ ] Test boot receiver starts service on device boot
- [ ] Test battery optimization exemption request
- [ ] Test on multiple Android versions (12, 13, 14)
- [ ] Test on multiple OEM devices (Samsung, Xiaomi, Oppo, OnePlus)
- [ ] Test under low memory conditions
- [ ] Test under Doze mode
- [ ] Test network interruptions
- [ ] Test checkpoint save/restore after crash
- [ ] Measure actual battery drain
- [ ] Measure reliability over 24-hour period

#### iOS Testing
- [ ] Test VoIP mode background execution
- [ ] Test app stays alive in background (if VoIP)
- [ ] Test foreground-only mode with wake lock
- [ ] Test memory pressure handling
- [ ] Test checkpoint save/restore
- [ ] Test app suspension and resume
- [ ] Test Low Power Mode impact
- [ ] Test on multiple iOS versions (15, 16, 17)
- [ ] Test on multiple devices (iPhone, iPad)
- [ ] Test thermal throttling behavior
- [ ] Measure actual battery drain
- [ ] Measure reliability over 24-hour period

#### Cross-Platform Testing
- [ ] Test state persistence across restarts
- [ ] Test RPC communication remains functional
- [ ] Test P2P networking stays connected
- [ ] Test mempool management continues
- [ ] Test block production success rate
- [ ] Test VRF evaluation continuity
- [ ] Verify no data corruption after crashes
- [ ] Test app updates don't break service
- [ ] Performance profiling (CPU, memory, network)

---

### Phase 9: Documentation & App Store Preparation

#### User Documentation
- [ ] Create user guide for enabling block production
- [ ] Document platform-specific requirements
- [ ] Create troubleshooting guide
- [ ] Document battery optimization instructions
- [ ] Create FAQ for common issues
- [ ] Document expected battery usage
- [ ] Create video tutorials (optional)

#### Developer Documentation
- [ ] Document architecture and design decisions
- [ ] Document Rust-native integration
- [ ] Document state persistence format
- [ ] Document troubleshooting for developers
- [ ] Add inline code comments
- [ ] Update README with new features

#### App Store Preparation - Android
- [ ] Update Play Store description
- [ ] Explain persistent notification requirement
- [ ] Document battery usage clearly
- [ ] Add screenshots showing service in action
- [ ] Prepare privacy policy updates
- [ ] Test beta release with TestFlight/Internal Testing

#### App Store Preparation - iOS
- [ ] Update App Store description
- [ ] Write justification for VoIP background mode
- [ ] Prepare App Review notes explaining P2P networking
- [ ] Document why background execution is necessary
- [ ] Emphasize decentralized blockchain validator role
- [ ] Add screenshots showing validator functionality
- [ ] Prepare response to potential rejection
- [ ] Consider fallback plan (foreground-only) if rejected
- [ ] Test beta release with TestFlight

---

### Phase 10: Monitoring & Iteration

#### Production Monitoring
- [ ] Add analytics for service reliability
- [ ] Track restart frequency
- [ ] Track crash reports
- [ ] Monitor battery usage complaints
- [ ] Track App Store review feedback
- [ ] Monitor network performance
- [ ] Track block production success rate

#### Iteration & Improvements
- [ ] Address crash reports
- [ ] Optimize checkpoint size and frequency
- [ ] Improve memory management based on data
- [ ] Optimize battery usage based on feedback
- [ ] Add user-requested features
- [ ] Improve notification UX based on feedback
- [ ] Add advanced settings for power users

---

## ARCHITECTURE DETAILS

### Android: Foreground Service Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App                         │
│  ┌──────────────────────────────────────────────┐   │
│  │  RustBackendService (Dart)                   │   │
│  │  - Delegates to AndroidBlockProducerService  │   │
│  └──────────────┬───────────────────────────────┘   │
│                 │ Method Channel                     │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  MainActivity (Kotlin)                       │   │
│  │  - Handles method channel calls              │   │
│  └──────────────┬───────────────────────────────┘   │
└─────────────────┼───────────────────────────────────┘
                  │ startService()
┌─────────────────▼───────────────────────────────────┐
│  BlockProducerService (Android Foreground Service)  │
│  ┌──────────────────────────────────────────────┐   │
│  │  Lifecycle:                                  │   │
│  │  - onCreate() → startForeground()           │   │
│  │  - onStartCommand() → START_STICKY          │   │
│  │  - Persistent Notification                   │   │
│  └──────────────┬───────────────────────────────┘   │
│                 │ JNI Call                           │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  NativeBridge (Kotlin)                       │   │
│  │  - startNode() / stopNode()                  │   │
│  └──────────────┬───────────────────────────────┘   │
└─────────────────┼───────────────────────────────────┘
                  │ FFI
┌─────────────────▼───────────────────────────────────┐
│  Rust Backend (libusernode.so)                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  jni_bridge.rs                               │   │
│  │  - Java_..._startNode()                      │   │
│  │  - Java_..._stopNode()                       │   │
│  └──────────────┬───────────────────────────────┘   │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  Node (Rust)                                 │   │
│  │  - run_forever_with_persistence()           │   │
│  │  - VRF evaluation                            │   │
│  │  - Block production                          │   │
│  │  - P2P networking                            │   │
│  │  - Mempool management                        │   │
│  └──────────────┬───────────────────────────────┘   │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  Persistence                                 │   │
│  │  - Auto-checkpoint every 30s                 │   │
│  │  - Save on memory warning                    │   │
│  │  - Restore on service restart                │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### iOS: VoIP Background Mode Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App                         │
│  ┌──────────────────────────────────────────────┐   │
│  │  RustBackendService (Dart)                   │   │
│  │  - Delegates to IOSBlockProducerService      │   │
│  └──────────────┬───────────────────────────────┘   │
│                 │ Method Channel                     │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  AppDelegate (Swift)                         │   │
│  │  - Handles method channel calls              │   │
│  │  - PKPushRegistryDelegate                    │   │
│  └──────────────┬───────────────────────────────┘   │
└─────────────────┼───────────────────────────────────┘
                  │ VoIP Registration
┌─────────────────▼───────────────────────────────────┐
│  PushKit (iOS Framework)                             │
│  - PKPushRegistry                                    │
│  - Grants background execution capability            │
│  - App can run in background via VoIP entitlement    │
└─────────────────┬───────────────────────────────────┘
                  │ Background Execution Enabled
┌─────────────────▼───────────────────────────────────┐
│  NodeBridge (Swift)                                  │
│  ┌──────────────────────────────────────────────┐   │
│  │  - startNode()                               │   │
│  │  - stopNode()                                │   │
│  │  - Memory warning handler                    │   │
│  │  - Lifecycle observer                        │   │
│  └──────────────┬───────────────────────────────┘   │
└─────────────────┼───────────────────────────────────┘
                  │ FFI
┌─────────────────▼───────────────────────────────────┐
│  Rust Backend (libusernode.a)                       │
│  ┌──────────────────────────────────────────────┐   │
│  │  Node (Rust)                                 │   │
│  │  - run_forever_with_persistence()           │   │
│  │  - VRF evaluation                            │   │
│  │  - Block production                          │   │
│  │  - P2P networking (justifies VoIP)          │   │
│  │  - Mempool management                        │   │
│  │  - Aggressive memory management (<50MB)     │   │
│  └──────────────┬───────────────────────────────┘   │
│  ┌──────────────▼───────────────────────────────┐   │
│  │  Persistence                                 │   │
│  │  - Auto-checkpoint every 30s                 │   │
│  │  - Save on memory warning (critical!)       │   │
│  │  - Restore on app resume                     │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### State Persistence Format

```rust
// NodeCheckpoint structure
pub struct NodeCheckpoint {
    pub version: u32,                       // Format version for future compatibility
    pub last_processed_slot: u64,           // Last slot evaluated
    pub block_producer_state: BlockProducerState,  // Current state machine state
    pub mempool_snapshot: Vec<Transaction>, // Pending transactions
    pub peer_list: Vec<PeerInfo>,          // Connected peers
    pub timestamp: SystemTime,              // Checkpoint creation time
}

// Serialization: bincode or JSON
// Location:
//   Android: /data/data/com.usernode_labs.usernode/files/checkpoint.bin
//   iOS: Documents/checkpoint.bin
```

---

## CODE EXAMPLES

### Android Foreground Service (Kotlin)

```kotlin
// android/app/src/main/kotlin/com/usernode_labs/usernode/BlockProducerService.kt

class BlockProducerService : Service() {
    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "block_producer_service"
        const val ACTION_START = "ACTION_START_BLOCK_PRODUCTION"
        const val ACTION_STOP = "ACTION_STOP_BLOCK_PRODUCTION"
    }

    private var nativeNodeHandle: Long = 0

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Initializing..."))
        Log.d("BlockProducerService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startBlockProduction()
            }
            ACTION_STOP -> {
                stopBlockProduction()
                stopSelf()
            }
        }
        return START_STICKY // Auto-restart if killed
    }

    private fun startBlockProduction() {
        try {
            val configPath = "${filesDir.absolutePath}/node_config.json"
            nativeNodeHandle = NativeBridge.startNode(configPath)
            updateNotification("Running - Active")
            Log.d("BlockProducerService", "Node started with handle: $nativeNodeHandle")
        } catch (e: Exception) {
            Log.e("BlockProducerService", "Failed to start node", e)
            updateNotification("Error: ${e.message}")
        }
    }

    private fun stopBlockProduction() {
        if (nativeNodeHandle != 0L) {
            NativeBridge.stopNode(nativeNodeHandle)
            nativeNodeHandle = 0
            Log.d("BlockProducerService", "Node stopped")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Block Producer Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows block production status"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(status: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Block Producer")
            .setContentText(status)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, buildNotification(status))
    }

    override fun onDestroy() {
        stopBlockProduction()
        super.onDestroy()
        Log.d("BlockProducerService", "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

### Rust JNI Bridge

```rust
// usernode/crates/usernode/src/jni_bridge.rs

use jni::JNIEnv;
use jni::objects::{JClass, JString};
use jni::sys::jlong;
use std::sync::Arc;
use tokio::runtime::Runtime;

#[no_mangle]
pub extern "system" fn Java_com_usernode_1labs_usernode_NativeBridge_startNode(
    mut env: JNIEnv,
    _class: JClass,
    config_path: JString,
) -> jlong {
    // Convert Java string to Rust string
    let config_path: String = env
        .get_string(&config_path)
        .expect("Failed to get config path")
        .into();

    // Create tokio runtime
    let runtime = Runtime::new().expect("Failed to create tokio runtime");

    // Build and start node
    let node = runtime.block_on(async {
        let mut builder = NodeBuilder::new();
        builder.config_path(&config_path);

        // Restore from checkpoint if exists
        if let Ok(checkpoint) = NodeCheckpoint::restore(&config_path) {
            builder.restore_from_checkpoint(checkpoint);
        }

        let mut node = builder.build().expect("Failed to build node");
        node
    });

    // Spawn node in background thread
    let node = Arc::new(Mutex::new(node));
    let node_clone = Arc::clone(&node);

    std::thread::spawn(move || {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let mut node = node_clone.lock().await;
            node.run_forever_with_persistence().await;
        });
    });

    // Return handle (pointer) to node
    Box::into_raw(Box::new(node)) as jlong
}

#[no_mangle]
pub extern "system" fn Java_com_usernode_1labs_usernode_NativeBridge_stopNode(
    _env: JNIEnv,
    _class: JClass,
    node_handle: jlong,
) {
    if node_handle == 0 {
        return;
    }

    // Convert handle back to Box
    let node = unsafe { Box::from_raw(node_handle as *mut Arc<Mutex<Node>>) };

    // Shutdown node
    let rt = Runtime::new().unwrap();
    rt.block_on(async {
        let mut node = node.lock().await;
        node.save_checkpoint().await.expect("Failed to save checkpoint");
        node.shutdown().await;
    });
}

#[no_mangle]
pub extern "system" fn Java_com_usernode_1labs_usernode_NativeBridge_saveCheckpoint(
    _env: JNIEnv,
    _class: JClass,
    node_handle: jlong,
) {
    if node_handle == 0 {
        return;
    }

    let node = unsafe { &*(node_handle as *const Arc<Mutex<Node>>) };
    let rt = Runtime::new().unwrap();
    rt.block_on(async {
        let node = node.lock().await;
        let _ = node.save_checkpoint().await;
    });
}
```

### iOS VoIP Mode (Swift)

```swift
// ios/Runner/AppDelegate.swift

import UIKit
import Flutter
import PushKit

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
    private var voipRegistry: PKPushRegistry?
    private var nodeBridge: NodeBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Setup VoIP push
        setupVoIPPush()

        // Setup method channel
        setupMethodChannel()

        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupVoIPPush() {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    private func setupMethodChannel() {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.usernode_labs.usernode/block_producer",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startNode":
                self?.startNode(result: result)
            case "stopNode":
                self?.stopNode(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func startNode(result: FlutterResult) {
        do {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0].path

            nodeBridge = NodeBridge(configPath: "\(documentsPath)/node_config.json")
            try nodeBridge?.start()
            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func stopNode(result: FlutterResult) {
        nodeBridge?.stop()
        nodeBridge = nil
        result(true)
    }

    @objc private func handleMemoryWarning() {
        print("Memory warning received - saving checkpoint")
        nodeBridge?.saveCheckpoint()
    }

    // MARK: - PKPushRegistryDelegate

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        print("VoIP push credentials updated")
        // Store credentials if needed for future server coordination
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        print("VoIP push received")
        // Handle push if needed in future
        completion()
    }
}
```

### Flutter Platform Service

```dart
// lib/core/services/block_producer_service.dart

abstract class BlockProducerService {
  static BlockProducerService create() {
    if (Platform.isAndroid) {
      return AndroidBlockProducerService();
    } else if (Platform.isIOS) {
      return IOSBlockProducerService();
    }
    throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
  }

  Future<void> start();
  Future<void> stop();
  Future<BlockProducerStatus> getStatus();
  Stream<BlockProducerStatus> get statusStream;
  Future<ServiceCapabilities> getCapabilities();
}

class ServiceCapabilities {
  final bool supportsBackground;
  final bool requiresForeground;
  final String backgroundMode;
  final int estimatedReliabilityPercent;
  final List<String> limitations;

  ServiceCapabilities({
    required this.supportsBackground,
    required this.requiresForeground,
    required this.backgroundMode,
    required this.estimatedReliabilityPercent,
    required this.limitations,
  });
}

class BlockProducerStatus {
  final bool isRunning;
  final String state;
  final int? lastBlockSlot;
  final DateTime? lastBlockTime;
  final int peerCount;
  final int mempoolSize;

  BlockProducerStatus({
    required this.isRunning,
    required this.state,
    this.lastBlockSlot,
    this.lastBlockTime,
    required this.peerCount,
    required this.mempoolSize,
  });
}
```

```dart
// lib/core/services/android_block_producer_service.dart

class AndroidBlockProducerService implements BlockProducerService {
  static const platform = MethodChannel('com.usernode_labs.usernode/block_producer');

  final _statusController = StreamController<BlockProducerStatus>.broadcast();

  @override
  Future<void> start() async {
    try {
      await platform.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      throw Exception('Failed to start service: ${e.message}');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await platform.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop service: ${e.message}');
    }
  }

  @override
  Future<BlockProducerStatus> getStatus() async {
    try {
      final result = await platform.invokeMethod('getServiceStatus');
      return BlockProducerStatus(
        isRunning: result['isRunning'],
        state: result['state'],
        lastBlockSlot: result['lastBlockSlot'],
        lastBlockTime: result['lastBlockTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(result['lastBlockTime'])
            : null,
        peerCount: result['peerCount'],
        mempoolSize: result['mempoolSize'],
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to get status: ${e.message}');
    }
  }

  @override
  Stream<BlockProducerStatus> get statusStream => _statusController.stream;

  @override
  Future<ServiceCapabilities> getCapabilities() async {
    return ServiceCapabilities(
      supportsBackground: true,
      requiresForeground: false,
      backgroundMode: 'foreground-service',
      estimatedReliabilityPercent: 95,
      limitations: [
        'Persistent notification required',
        'Battery optimization whitelist recommended',
        'OEM-specific battery management may affect reliability',
      ],
    );
  }

  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await platform.invokeMethod('requestBatteryOptimizationExemption');
    } on PlatformException catch (e) {
      throw Exception('Failed to request exemption: ${e.message}');
    }
  }
}
```

---

## RELIABILITY ESTIMATES

| Platform | Mode | Reliability | Latency | Battery Impact | User Impact |
|----------|------|-------------|---------|----------------|-------------|
| Android | Foreground Service | **95-98%** | < 5s | 15-25% | Persistent notification |
| iOS | VoIP Background | **85-95%** | < 5s | 20-30% | None (silent) |
| iOS | Foreground Only | **99%** | < 1s | 10-15% | Must keep app open |
| iOS | BGProcessingTask | **20-40%** | minutes-hours | 5-10% | Unreliable for time-sensitive tasks |

---

## APP STORE STRATEGY

### Android Play Store ✅

**Status**: Low risk, should pass review easily

**Description Template**:
```
Usernode - Blockchain Validator

Run a blockchain validator node directly from your mobile device.
Participate in network consensus and earn rewards by producing blocks.

Important:
• Background service runs continuously with persistent notification
• Estimated battery usage: 15-25% additional drain
• Best performance when device is plugged in
• Whitelist app in battery optimization for best results

Features:
• Full L1 block producer capabilities
• VRF-based slot evaluation
• P2P networking with network peers
• Mempool management
• Real-time status monitoring
```

### iOS App Store ⚠️

**Status**: Medium risk if using VoIP mode

**VoIP Mode Justification for App Review**:
```
App Review Notes:

This app uses the VoIP background mode to maintain persistent peer-to-peer
network connections required for blockchain consensus participation. The app
functions as a decentralized blockchain validator node that must:

1. Maintain continuous P2P connections with network peers
2. Evaluate cryptographic slot winners using VRF (Verifiable Random Function)
3. Produce and broadcast blocks when slots are won
4. Synchronize mempool and blockchain state with peers

The VoIP background mode is used legitimately to:
- Keep P2P socket connections alive in the background
- Maintain network consensus participation
- Enable time-sensitive block production (5-second window)

This is analogous to how cryptocurrency wallet apps use background modes to
maintain network connectivity. The app implements proper memory management
and respects iOS system resource constraints.
```

**Safe Fallback Strategy** (Foreground-Only):
```
If VoIP mode is rejected:
1. Remove VoIP background mode from Info.plist
2. Enable foreground-only mode as primary iOS option
3. Add clear user documentation about keeping app open
4. Optionally use BGProcessingTask for best-effort sync (not production)
5. Resubmit with clearer documentation about mobile validator limitations
```

---

## RECOMMENDATIONS

### Implementation Priority

1. **Start with Android** (guaranteed to work, clearer path)
   - Implement foreground service
   - Test on multiple OEM devices
   - Validate 24-hour reliability

2. **Test iOS VoIP mode in development**
   - Implement VoIP background mode
   - Test background execution limits
   - Measure actual reliability and battery impact

3. **Prepare iOS foreground-only mode as fallback**
   - Implement wake lock and screen dimming
   - Create clear user education UI
   - Document limitations transparently

4. **Beta testing**
   - TestFlight for iOS
   - Internal testing for Android
   - Gather real-world data on reliability and battery

5. **Iterate based on feedback**
   - Optimize based on crash reports
   - Improve memory management
   - Refine checkpoint frequency

### Critical Success Factors

✅ **Robust state persistence**
- Checkpoint every 30 seconds minimum
- Atomic writes (temp file + rename)
- Version checkpoints for future compatibility

✅ **Aggressive memory management (especially iOS)**
- Monitor memory usage constantly
- Respond immediately to memory warnings
- Keep memory under 50MB on iOS background

✅ **Clear user communication**
- Transparent about platform limitations
- Show real-time reliability statistics
- Provide troubleshooting guides

✅ **Platform-specific optimizations**
- Android: Optimize for OEM battery managers
- iOS: Optimize for memory pressure
- Both: Minimize network usage

✅ **Thorough testing**
- Multiple devices and OS versions
- Real-world 24+ hour tests
- Kill/restart/network interruption scenarios

---

## ADDITIONAL RESOURCES

### Research References

- Android Foreground Services: https://developer.android.com/develop/background-work/services/foreground-services
- Android WorkManager: https://developer.android.com/topic/libraries/architecture/workmanager
- iOS Background Execution: https://developer.apple.com/documentation/backgroundtasks
- iOS VoIP Best Practices: https://developer.apple.com/documentation/pushkit
- Flutter Platform Channels: https://docs.flutter.dev/platform-integration/platform-channels

### Known Issues & Workarounds

**Android**:
- Xiaomi MIUI aggressive killing → User must whitelist in Security app
- Oppo/Realme battery optimization → User must disable battery optimization
- Samsung Ultra Power Saving Mode → Service will be killed, warn user

**iOS**:
- Low Power Mode disables background → Detect and warn user
- Memory limits in background → Checkpoint more frequently (every 15s)
- No boot receiver → User must manually open app after reboot
- Focus modes may limit background → Cannot override, user must configure

---

## CHANGE LOG

| Date | Change | Author |
|------|--------|--------|
| 2025-11-14 | Initial implementation plan created | Claude Code |

---

## NEXT STEPS

Ready to begin implementation:

1. Review and approve this plan
2. Clarify any questions or concerns
3. Begin Phase 1: Rust Core - State Persistence
4. Regular check-ins after each phase completion

**Estimated Total Implementation Effort**: Significant (cross-platform, native code, complex testing)

**Recommended Approach**: Incremental implementation with testing at each phase
