# Flutter Mobile App - Block Production Implementation Analysis

## Executive Summary

The Flutter mobile app currently implements **Option B (Opportunistic Local + Scheduled Sync)** as its primary strategy, with foundational components for potentially advancing toward higher-availability modes. The Rust node runs within the Flutter app process, with background task support via WorkManager (Android) and BGProcessingTask (iOS) for slot monitoring and notification scheduling.

---

## Current Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                          │
│  (Dashboard, Wallet, Rewards, Node Status, Won Slots screens)   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│               Riverpod Provider Layer (State Management)         │
│  - nodeStatusProvider, nodeRawStatusProvider                    │
│  - epochRewardsUiProvider, nodeEpochRewardsProvider             │
│  - nodeMempoolProvider, nodeBlockchainProvider                  │
│  - backendLifecycleProvider (watches account state)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│              Services Layer (Core Infrastructure)               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ RustBackendService (rust_backend_service.dart - 904 LOC) │  │
│  │ - init() - Initializes flutter_rust_bridge              │  │
│  │ - startNode() - Builds and starts Rust node             │  │
│  │ - stopNode() - Stops node                               │  │
│  │ - startForActiveAccount() - Conditional start           │  │
│  │ - getStatus() - Fetches node/blockchain/block producer  │  │
│  │ - epochRewards() - Fetches won slots & rewards          │  │
│  │ - listBlockchain() - Fetches produced blocks            │  │
│  │ - listMempool() - Fetches pending transactions          │  │
│  │ - transferFunds() - Submits transactions to mempool     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  BackgroundTaskService (WorkManager Integration)         │  │
│  │  - initialize() - Register WorkManager                   │  │
│  │  - registerSlotMonitoringTask() - 15-min periodic task  │  │
│  │  - callbackDispatcher() - Runs in separate isolate      │  │
│  │  - _performSlotMonitoring() - Fetches epoch data        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  LocalNotificationService                                │  │
│  │  - initialize() - Sets up notification channels         │  │
│  │  - requestPermissions() - Requests Android 13+ perms    │  │
│  │  - showNotification() - Display local notifications     │  │
│  │  - scheduleNotification() - Schedule future alerts      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  SlotNotificationManager (Smart Batching)                │  │
│  │  - scheduleNotificationsForSlots() - Schedule alerts    │  │
│  │  - Smart batching algorithm (groups 3+ slots)          │  │
│  │  - Track missed vs produced slots                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  NotificationStateRepository (Persistence)               │  │
│  │  - Save/load notification preferences                   │  │
│  │  - Track scheduled notifications                        │  │
│  │  - Epoch state management                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│         Flutter Rust Bridge (FFI to Native Rust Code)           │
│  - rpc.dart - RPC client definitions                            │
│  - node.dart - Node lifecycle (start/stop/run)                  │
│  - node/builder.dart - NodeBuilder with config options         │
│  - Auto-generated bindings (frb_generated.dart, .io.dart, etc) │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│           Rust Node Runtime (In-App Process)                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ NodeService (usernode/crates/node_service)              │  │
│  │ - Effects: Block production state machine               │  │
│  │ - RPC HTTP server (optional, port configurable)         │  │
│  │ - P2P network connection & block sync                   │  │
│  │ - Mempool management                                    │  │
│  │ - UTXO database worker                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ BlockProducer State Machine                              │  │
│  │ States: WonSlot, WaitForSlot, Produce, Batching,        │  │
│  │         Assembly, Signing, Produced, Injected           │  │
│  │                                                           │  │
│  │ Fixed block producer key: configured at startup         │  │
│  │ (hardcoded hex in rust_backend_service.dart:89-91)      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Network Layer (P2P)                                      │  │
│  │ - Connect to peers, sync blocks, broadcast txs         │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Current Implementation Status

### What IS Implemented (Option B Foundation)

#### 1. **Node Lifecycle Management**
- **File:** `/lib/features/node/data/repositories/rust_backend_service.dart`
- **Key Methods:**
  - `init()` - Loads flutter_rust_bridge library (one-time)
  - `startNode()` - Builds NodeBuilder with config, starts in background thread via `runForeverInNewThread()`
  - `stopNode()` - Drops node reference (no graceful shutdown available yet)
  - `startForActiveAccount()` - Conditional start based on account existence
  - `restartForActiveAccount()` - Stop + restart

- **Block Producer Configuration:**
  ```dart
  // Line 89-91 in rust_backend_service.dart
  builder.blockProducerHex(
      skHex: "def170e8016858220fe64bd78baa863c15b50d35f8308545210d0a4d2550881b");
  ```
  - **Status:** HARDCODED (not account-aware, not configurable per user)
  - **Risk:** Single validator key for all instances; no key rotation support

#### 2. **Active Session Mode (Foreground)**
- When app UI is open, the Rust node runs continuously in a background thread
- **Refresh Pattern:** 3-second auto-refresh in `NodeWonSlotsScreen` (lines 50-54)
- **Metrics Available:**
  - Connected peers, block height, epoch, global slot
  - Mempool state (transactions, orphans, total size)
  - Block production status (won slot info, state, progress)
  - Sync progress (block fetch/apply counters)

#### 3. **Background Task Scheduling (Option B Core)**
- **File:** `/lib/core/services/background_task_service.dart`
- **Platform Support:**
  - **Android:** WorkManager with 15-minute periodic frequency
  - **iOS:** BGProcessingTask registered in Info.plist (lines 43-51)
- **Constraints:**
  - Network connected (required)
  - No battery/charging/device idle constraints
  - Exponential backoff on failure (5-minute delays)
- **Limitations:**
  - iOS: No guarantee of execution; system decides based on usage patterns
  - Android: May be throttled when battery saver is ON or app rarely opened
  - No persistent notification/foreground service on Android yet

#### 4. **Slot Monitoring in Background**
- **File:** `/lib/core/services/background_task_service.dart`, `callbackDispatcher()` (lines 98-205)
- **What it does:**
  1. Initializes services in isolated background thread
  2. Fetches current epoch from Rust backend
  3. Retrieves won slots via `epochRewards()`
  4. Gets recently produced blocks via `listBlockchain()`
  5. Schedules notifications for upcoming slots
  6. Cleans up old notifications
- **Limitations:**
  - Rust backend may not be running if app was fully killed
  - No recovery mechanism if backend was stopped

#### 5. **Smart Notification System**
- **File:** `/lib/core/services/slot_notification_manager.dart`
- **Features:**
  - Batches 3+ slots in 30-minute window into single grouped notification
  - Separate notification types: upcoming, produced, missed
  - Advance warning configurable (5, 10, 15, 30 minutes)
  - Notification persistence in SharedPreferences
  - Rate limiting per type
- **Status Tracking:**
  - Won slots from `epochRewards()` RPC
  - Produced slots from blockchain history
  - Compares to determine missed slots

#### 6. **Account-Aware Lifecycle**
- **File:** `/lib/core/providers/providers.dart`, lines 35-60
- **How it works:**
  - Watches `hasAnyAccountProvider` for account creation/deletion
  - Auto-starts node when first account is created
  - Auto-stops node when last account is deleted
- **Limitation:** Assumes single fixed block producer key (no per-account key support)

#### 7. **Rewards Tracking & Notifications**
- **File:** `/lib/features/rewards/presentation/controllers/epoch_rewards_provider.dart`
- **Features:**
  - Cache current epoch rewards to disk
  - Fetch live data from Rust backend
  - Detect and notify when rewards increase
  - Tracks: produced blocks, wins, earned, expected total, reward per block
- **Status:** Only supports display; no on-chain rewards claimed yet

### What IS NOT Implemented (Missing for Full Options)

#### 1. **Foreground Service (Android) - Needed for Option A/B+**
- No `startForeground()` call with persistent notification
- No wake locks to keep CPU/WiFi active during background
- No battery optimization exemption mechanism
- Result: Cannot keep node running when app is backgrounded on Android

#### 2. **Key Management**
- Block producer key is hardcoded in code (security risk, not scalable)
- No support for multiple validators per device
- No secure key storage (currently in Rust service memory only)
- No key rotation mechanism

#### 3. **Graceful Shutdown**
- Rust node is simply dropped without cleanup
- No snapshot/checkpoint persistence for fast resume
- No heartbeat mechanism to detect liveness
- Result: On restart, node must resync from genesis or latest peer state

#### 4. **Cloud Failover (Option C)**
- No heartbeat to remote backend
- No state replication mechanism
- No failover API contract
- No reconciliation logic for conflicts

#### 5. **Remote Signer (Option D)**
- Entire block production is on-device only
- No MPC or threshold signing support
- No delegation mechanism

#### 6. **Block Production Telemetry**
- No local logging of produced blocks with timestamps
- No missed slot analysis (only notifications)
- No block production success rate metrics
- No performance/latency tracking

#### 7. **iOS Background Execution**
- Info.plist declares fetch + processing modes (lines 43-51)
- AppDelegate.swift registers background fetch (lines 19-33)
- BUT: No VoIP/Audio background mode (would require entitlements + significant architecture)
- Result: iOS execution is severely time-limited (≈30 seconds per wake)

#### 8. **Recovery & Rehydration**
- No broadcast receiver for device shutdown
- No persistent state checkpoints
- No fast-resume mechanism
- No app force-stop detection

---

## Key Files & Their Responsibilities

### Core Services

| File | LOC | Purpose | Status |
|------|-----|---------|--------|
| `rust_backend_service.dart` | 904 | Node lifecycle, RPC facade, initialization | Core |
| `background_task_service.dart` | 206 | WorkManager integration, background callbacks | Core (Option B) |
| `slot_notification_manager.dart` | ~300 | Smart batching, schedule notifications | Implemented |
| `local_notification_service.dart` | ~200 | Push notifications | Implemented |
| `notification_state_repository.dart` | ~150 | Persistence layer for notifications | Implemented |

### Providers (State Management)

| Provider | File | Purpose |
|----------|------|---------|
| `nodeRawStatusProvider` | `node_raw_status_provider.dart` | Low-level node status (peers, blocks, sync) |
| `nodeStatusProvider` | `node_status_provider.dart` | Derived, high-level status |
| `nodeEpochRewardsProvider` | `node_data_providers.dart` | Won slots & rewards for current epoch |
| `nodeBlockchainProvider` | `node_data_providers.dart` | Produced blocks from blockchain |
| `nodeMempoolProvider` | `node_data_providers.dart` | Pending transactions |
| `backendLifecycleProvider` | `providers.dart` | Auto-start/stop on account changes |
| `epochRewardsUiProvider` | `epoch_rewards_provider.dart` | Rewards with caching & notifications |

### Platform-Specific Configuration

#### Android
- **Manifest:** `/android/app/src/main/AndroidManifest.xml`
  - Permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`
  - WorkManager provider (auto-init disabled, then manual in code)
  - No foreground service declaration
- **Build Config:** `/android/app/build.gradle`
  - Target SDK 34, Min SDK 21 (from flutter config)
  - Kotlin enabled

#### iOS
- **Info.plist:** `/ios/Runner/Info.plist`
  - Background modes: `fetch`, `processing` (lines 43-51)
  - BGTaskScheduler permitted IDs: `be.tramckrijte.workmanager.slot_monitoring_task`
  - Camera & Biometric permissions for ID verification
- **AppDelegate.swift:** `/ios/Runner/AppDelegate.swift`
  - Registers WorkManager for background fetch
  - Sets minimum background fetch interval to system default
  - No VoIP or Audio background mode

### Rust Integration

- **Entry Point:** `lib/rust/` and `lib/src/rust/` (both exist, imports use `src/rust/`)
- **Generated Bindings:** `frb_generated.dart`, `frb_generated.io.dart`, `frb_generated.web.dart`
- **Node API:** `/lib/rust/node/builder.dart` - NodeBuilder interface
- **RPC API:** `/lib/rust/rpc.dart` - RPC client definitions
- **External Rust:** `usernode/` directory (separate monorepo)

---

## Block Production Flow (Current)

### 1. **App Startup**
```
main.dart:19-37
  → SentryUtil.bootstrap() → runApp() → _bootstrapAsync()
    ├─ Load feature flags
    ├─ Initialize notifications
    ├─ Initialize BackgroundTaskService
    │  └─ Register 15-min background task
    ├─ RustBackendService.init()
    └─ RustBackendService.startForActiveAccount()
       └─ Check if accounts exist
          └─ If yes: startNode()
             └─ NodeBuilder.blockProducerHex(hardcoded_key)
             └─ node.runForeverInNewThread()
```

### 2. **Active Session (App Open)**
```
UI renders → Riverpod providers refresh
  ├─ nodeRawStatusProvider.refresh() → RustBackendService.getStatus()
  │  └─ Returns: peers, block heights, block producer status
  ├─ nodeEpochRewardsProvider.refresh() → RustBackendService.epochRewards()
  │  └─ Returns: won slots, produced blocks count, rewards
  └─ UI updates every 3-5 seconds in screen refresh timer
```

### 3. **Background Execution (App Backgrounded)**
```
WorkManager triggers every 15 minutes (best effort)
  ├─ callbackDispatcher() runs in isolated background thread
  ├─ Initialize services (notifications, notification state)
  ├─ RustBackendService.getStatus() → May succeed if node still running
  │                                    May fail if node was killed
  ├─ RustBackendService.epochRewards() → Get current epoch data
  ├─ RustBackendService.listBlockchain() → Get recently produced blocks
  ├─ SlotNotificationManager.scheduleNotificationsForSlots()
  │  └─ Smart batch and schedule notifications
  └─ Done - background task completes
```

### 4. **Won Slot Detection**
```
Rust node (running in background thread)
  → Network receives new blocks
  → Local ledger updates
  → Block producer STM checks: "Is my key in this slot?"
  → RPC exposes via epochRewards() → wonSlots array
  → Backend task calls epochRewards() every 15 minutes
  → Compares with previous epoch's wonSlots
  → Schedules notifications for upcoming won slots
```

### 5. **Block Production**
```
Rust block producer STM
  → Wait until assigned slot time
  → Pull mempool transactions
  → Assemble batch
  → Run ZK proof
  → Sign block
  → Broadcast to peers
  → Update state to "Produced"
  → RPC exposes via listBlockchain() 
  → Available to UI within seconds (if polling)
```

---

## Which Strategies Are Currently Implemented?

### Option A: Always-On Local Producer
- **Status:** NOT IMPLEMENTED
- **Missing:** Foreground service, wake locks, persistent notification, battery exemption
- **Risk:** Without foreground service, node is killed when app backgrounded on Android

### Option B: Opportunistic Local + Scheduled Sync
- **Status:** PARTIALLY IMPLEMENTED (Core Framework Ready)
- **Implemented:**
  - Runs node when app UI is open (active session)
  - Background task scheduled every 15 minutes
  - Slot monitoring in background
  - Smart notification batching
  - Graceful degradation when backend unavailable
- **Gaps:**
  - No foreground service means background execution unreliable on Android
  - No fast-resume snapshot mechanism
  - 15-minute task frequency may miss slots (slots are ~4 minutes apart)
  - iOS execution severely limited (≈30 seconds per task)
  - No mechanism to keep user informed when delegating

### Option C: Hybrid Local + Cloud Co-Producer
- **Status:** NOT IMPLEMENTED
- **Missing:** Cloud failover, heartbeat, state replication, reconciliation

### Option D: Remote Producer with Mobile Signer
- **Status:** NOT IMPLEMENTED
- **Missing:** Remote node API, signing orchestration, delegation UI

---

## Platform-Specific Constraints & Realities

### Android

#### Current Limitations
- **Background execution:** Killed when app is swiped away or device is idle
- **Battery saver:** Background tasks disabled entirely
- **OEM task killers:** Some manufacturers (Samsung, Huawei) aggressively kill background processes
- **Time-to-wake:** Can take 30+ seconds for WorkManager to fire after network event

#### What Works
- Active session (app open): Continuous block production possible
- Exact alarms: Can schedule notifications at specific times (API 31+)
- Foreground service: Would allow ≈indefinite background runtime (if implemented)

#### What Would Help (Not Yet Done)
- Add foreground service with persistent notification (Option A)
- Battery optimization exemption intent
- Per-device block producer key configuration
- Heartbeat to backend for failover detection

### iOS

#### Current Limitations
- **BGProcessingTask:** Runs ≈30 seconds per invocation, scheduled by iOS based on usage
- **Background fetch:** Similar 30-second limit
- **No arbitrary daemons:** Cannot run indefinite background threads
- **VoIP/Audio:** Available but requires VoIP app entitlement + significant architecture change
- **No WorkManager guarantee:** iOS does not promise periodic execution

#### What Works
- Active session (app open): Continuous block production possible
- Push notifications: Can wake app for a brief moment (≈30 seconds)
- Background fetch callback: Can poll for updates in declared 30-second window

#### What Would Help (Not Yet Done)
- Implement VoIP background mode (requires entitlement + significant work)
- Backend push notifications when slot is about to happen
- AppKit background task API for longer execution (still capped at ~3 minutes)
- CloudKit sync as alternative (overly complex for this use case)

---

## Critical Gaps for Block Production Reliability

### 1. **Foreground Service (Android)**
- **Impact:** HIGH
- **Effort:** MEDIUM (1-2 weeks)
- **What:** Add `startForeground()` with persistent notification in Android native layer
- **Benefit:** Keeps node running when app is backgrounded
- **Trade-off:** User sees persistent notification; battery usage increases

### 2. **Key Management**
- **Impact:** HIGH
- **Effort:** MEDIUM (2-3 weeks)
- **Current:** Hardcoded single key
- **What:** 
  - Move key from code to secure storage (KeyStore on Android, Keychain on iOS)
  - Support multiple validators per device
  - Allow user to toggle which key is active
- **Benefit:** Scalable, secure, multi-validator support

### 3. **Graceful Shutdown & Recovery**
- **Impact:** MEDIUM
- **Effort:** MEDIUM (2-3 weeks)
- **What:**
  - Persist block production state to disk periodically
  - Implement `resumeFromSnapshot()` to avoid full resync
  - Detect app force-stop and graceful shutdown
  - Save heartbeat timestamp for recovery analysis
- **Benefit:** Faster startup, clearer diagnostics on failures

### 4. **Block Production Telemetry**
- **Impact:** MEDIUM
- **Effort:** SMALL (1 week)
- **What:**
  - Log every produced block with timestamp to disk
  - Track missed slots with reason (app backgrounded, network, etc.)
  - Expose via diagnostics screen
  - Send to backend for analytics
- **Benefit:** Observability for users and operations team

### 5. **Cloud Failover (Option C) - For Enterprise**
- **Impact:** HIGH (for production validators)
- **Effort:** HIGH (4-6 weeks)
- **What:**
  - Heartbeat API to backend
  - Cloud node in standby mode
  - Automatic failover after T_failover (e.g., 45 seconds)
  - Reconciliation on recovery
  - UI to show delegation status
- **Benefit:** Near-24/7 availability for professional operators

### 6. **Push-Triggered Background Wake (Future)**
- **Impact:** MEDIUM
- **Effort:** HIGH (3-4 weeks, mostly iOS complexity)
- **What:**
  - Backend sends push notification before each slot
  - App wakes for 30 seconds to produce block
  - If background task fires early, node is already running
- **Benefit:** On iOS, can achieve >95% slot production
- **Trade-off:** Requires backend infrastructure, push service reliability

---

## Data Structures & RPC Interfaces

### Key RPC Responses

#### `getStatus()` Response
```rust
struct RpcStatusResp {
  peers: Vec<RpcPeerInfo>,
  blockchain: RpcStatusBlockchain,
  blockProducer: RpcStatusBlockProducer?,
  mempool: RpcStatusMempool,
  vrfEvaluator: RpcStatusVrfEvaluator?,
}

struct RpcStatusBlockProducer {
  pubKey: AccountPublicKey,
  status: RpcStatusBlockProducerStatus,
}

enum RpcStatusBlockProducerStatus {
  WonSlot(RpcStatusBlockProducerWonSlotInfo),
  WaitForSlot(RpcStatusBlockProducerWonSlotInfo),
  WonSlotWait(RpcStatusBlockProducerWonSlotInfo),
  WonSlotProduceInit(RpcStatusBlockProducerWonSlotInfo),
  BatchesAssemblePending(RpcStatusBlockProducerWonSlotInfo),
  BatchesAssembleSuccess(RpcStatusBlockProducerWonSlotInfo),
  DbDiffPending(RpcStatusBlockProducerWonSlotInfo),
  DbDiffSuccess(RpcStatusBlockProducerWonSlotInfo),
  StakeProofWait(RpcStatusBlockProducerWonSlotInfo),
  SigningPending(RpcStatusBlockProducerWonSlotInfo),
  Produced(RpcStatusBlockProducerWonSlotInfo),
  Injected(RpcStatusBlockProducerWonSlotInfo),
  WonSlotDiscarded(RpcStatusBlockProducerWonSlotInfo),
}

struct RpcStatusBlockProducerWonSlotInfo {
  globalSlot: int,
  slotTimestamp: Timestamp,
}
```

#### `epochRewards()` Response
```rust
struct RpcEpochRewardsResp {
  epoch: int,
  rewardPerBlock: BigInt,
  producedInEpoch: int,
  winsInEpoch: int,
  earnedSoFar: BigInt,
  expectedTotal: BigInt,
  producerPubkey: String?,
  wonSlots: Vec<RpcEpochWonSlot>?,
}

struct RpcEpochWonSlot {
  globalSlot: int,
  expectedTimeMs: BigInt,  // milliseconds since epoch
}
```

#### `listBlockchain()` Response
```rust
struct RpcListBlockchainResp {
  totalBlocks: BigInt,
  items: Vec<RpcBlockInfo>,
  rootHash: Hash?,
  tipHash: Hash?,
}

struct RpcBlockInfo {
  height: int,
  epoch: int,
  globalSlot: int,
  hash: Hash,
  producerPubkey: String,
  batches: Vec<RpcBlockBatch>,
  transactions: BigInt,
}
```

---

## Hardcoded Configuration & Secrets

### Critical: Block Producer Key
- **Location:** `/lib/features/node/data/repositories/rust_backend_service.dart`, lines 89-91
- **Current:** `"def170e8016858220fe64bd78baa863c15b50d35f8308545210d0a4d2550881b"`
- **Issue:** 
  - Hardcoded in source code (security risk)
  - Same key for all instances (not user-specific)
  - No way to change without recompiling
- **Should be:** Loaded from secure storage (KeyStore/Keychain) per account

### Other Configuration
- **HTTP Server Port:** Default (can be overridden in `startNode()`)
- **P2P Max Peers:** Default from NodeBuilder
- **Mempool Auto-insert:** Disabled in production (set to 1 second for testing)
- **Initial Peers:** Fetched from network or default list
- **RNG Seed:** Custom seed available in NodeBuilder, currently random

---

## Recommendations for Enhancement

### Phase 1: Stabilize Option B (2-3 weeks)
1. Implement Android foreground service with persistent notification
2. Add block production telemetry (logging + diagnostics screen)
3. Graceful shutdown with state persistence
4. Move block producer key to secure storage (per-account)

### Phase 2: Approach Option A (4-6 weeks)
1. Add battery/thermal awareness (monitor and auto-pause if overheating)
2. Implement heartbeat to backend (daily, for liveness tracking)
3. Add "High Priority Mode" toggle (temp foreground service for K hours)
4. Advanced diagnostics dashboard

### Phase 3: Toward Option C (8-12 weeks)
1. Backend failover service with cloud standby node
2. State replication via heartbeats
3. Failover detection and reconciliation
4. User-facing delegation UI

### Phase 4: Future (Option D, if needed)
1. MPC signing orchestration
2. Validator-as-a-service API
3. Third-party signer integration

---

## Summary Table: Strategy Status

| Aspect | Option A | Option B (Current) | Option C | Option D |
|--------|----------|-------------------|----------|----------|
| **Node Lifecycle** | Not yet | ✓ Partial | ✓ Partial | N/A |
| **Active Session** | Not yet | ✓ Yes | ✓ Yes | UI only |
| **Background Tasks** | Not yet | ✓ Yes | ✓ Yes | Backend only |
| **Foreground Service** | ✗ Missing | ✗ Missing | ✗ Missing | N/A |
| **Cloud Failover** | N/A | ✗ No | ✗ No | ✓ Yes |
| **Key Management** | ✗ Hardcoded | ✗ Hardcoded | ✗ Hardcoded | ✗ Hardcoded |
| **Graceful Shutdown** | ✗ No | ✗ No | ✗ No | N/A |
| **Block Telemetry** | ✗ No | ✗ No | ✗ No | ✗ No |
| **iOS Support** | ✗ Limited | ✗ Very Limited | ✗ Very Limited | Partial |
| **User-Facing** | Good | Good | ✓ Better | ✓ Best |
| **Self-Custody** | ✓ Full | ✓ Full | ✓ Full | ✗ No |
| **Complexity** | High | Medium | High | Medium |

---

## Conclusion

The Flutter mobile app has successfully implemented the **foundation of Option B (Opportunistic Local + Scheduled Sync)**, with core components like WorkManager integration, background task scheduling, and smart notification batching. The Rust node runs reliably during active sessions and can be awakened periodically in the background for slot monitoring.

However, **critical gaps prevent reliable block production in background:**
1. **No foreground service** - Node is killed when app backgrounded on Android
2. **Hardcoded block producer key** - Not user/account-specific, security risk
3. **No state persistence** - Full resync required on restart
4. **Limited iOS support** - Background tasks only 30 seconds per invocation

**Recommended next step:** Implement Android foreground service + key management (2-3 weeks) to stabilize Option B and enable Option A for power users. This provides a solid foundation for future Option C failover architecture.

