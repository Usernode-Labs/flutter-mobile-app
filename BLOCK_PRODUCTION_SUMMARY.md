# Block Production Implementation - Quick Reference

## Current Status: Option B (Opportunistic Local + Scheduled Sync) - PARTIALLY IMPLEMENTED

### What Works Now

1. **Active Session (App Open)**
   - Rust node runs continuously in background thread
   - Block producer state machine fully operational
   - 3-5 second refresh cycle for UI updates
   - All node metrics available: peers, blocks, rewards, mempool

2. **Background Task Framework**
   - WorkManager on Android (15-minute periodic)
   - BGProcessingTask on iOS (30-second limit per invocation)
   - Smart notification batching (3+ slots grouped)
   - Epoch-aware slot monitoring

3. **Account Lifecycle**
   - Auto-start node when account created
   - Auto-stop when all accounts deleted
   - Watch account state via Riverpod providers

4. **Notifications**
   - Won slots, produced blocks, missed slots
   - Configurable advance warnings (5-30 min)
   - Smart batching to reduce notification spam
   - Persistent state saved to SharedPreferences

### Critical Gaps - Block This from Production

1. **No Foreground Service (Android)**
   - Node killed when app backgrounded
   - 15-minute background tasks may fail entirely
   - No persistent notification
   - No wake locks
   - **Fix effort:** 1-2 weeks, HIGH IMPACT

2. **Hardcoded Block Producer Key**
   - Same key for all instances
   - Not account-specific
   - Security risk in source code
   - No key rotation support
   - **Fix effort:** 2-3 weeks, HIGH IMPACT

3. **No State Persistence**
   - Full resync required on every restart
   - No snapshot/checkpoint mechanism
   - Can take several minutes to catch up
   - **Fix effort:** 2-3 weeks, MEDIUM IMPACT

4. **Limited iOS Background**
   - Only 30 seconds per background task
   - System controls execution frequency
   - No reliable way to produce blocks
   - **Fix effort:** 3-4 weeks for VoIP mode, MEDIUM IMPACT

### Block Production Flow

```
App Startup
  ├─ Load flutter_rust_bridge
  ├─ Check if accounts exist
  └─ Start Rust node in background thread
       ├─ Configure with hardcoded block producer key
       └─ Connect to P2P network, sync blocks

Active Session (UI Open)
  ├─ Providers refresh every 3-5 seconds
  ├─ Node continuously produces blocks when assigned slots
  └─ UI shows real-time status

Background (App Backgrounded)
  ├─ WorkManager fires every 15 minutes (best effort)
  ├─ Background task:
  │   ├─ Fetch current epoch & won slots
  │   ├─ List recently produced blocks
  │   ├─ Schedule notifications for upcoming slots
  │   └─ Complete (node may or may not still be running)
  └─ On Android: Node typically killed within 1-5 minutes
     On iOS: Task only runs for 30 seconds max

Block Production (Rust Layer)
  ├─ Wait for assigned slot time
  ├─ Assemble batch from mempool
  ├─ Generate ZK proof
  ├─ Sign block
  ├─ Broadcast to peers
  └─ Update state to "Produced"
```

### Key Files (Absolute Paths)

**Core Services:**
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/data/repositories/rust_backend_service.dart` (904 LOC)
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/services/background_task_service.dart` (206 LOC)
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/services/slot_notification_manager.dart` (~300 LOC)

**State Management (Riverpod):**
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/presentation/controllers/node_raw_status_provider.dart`
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/presentation/controllers/node_status_provider.dart`
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/providers/providers.dart` (backendLifecycleProvider)
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/rewards/presentation/controllers/epoch_rewards_provider.dart`

**Platform Configuration:**
- Android: `/Users/salah/Dev/lingash/flutter-mobile-app/android/app/src/main/AndroidManifest.xml`
- Android: `/Users/salah/Dev/lingash/flutter-mobile-app/android/app/build.gradle`
- iOS: `/Users/salah/Dev/lingash/flutter-mobile-app/ios/Runner/Info.plist`
- iOS: `/Users/salah/Dev/lingash/flutter-mobile-app/ios/Runner/AppDelegate.swift`

**Rust Integration:**
- Node builder: `/Users/salah/Dev/lingash/flutter-mobile-app/lib/rust/node/builder.dart`
- RPC client: `/Users/salah/Dev/lingash/flutter-mobile-app/lib/rust/rpc.dart`
- Block producer key: Line 89-91 in rust_backend_service.dart (HARDCODED)

### Hardcoded Configuration to Replace

```dart
// Location: rust_backend_service.dart:89-91
builder.blockProducerHex(
    skHex: "def170e8016858220fe64bd78baa863c15b50d35f8308545210d0a4d2550881b");
```

This should be loaded from:
- Android: `AndroidKeyStore` via `flutter_secure_storage`
- iOS: `Keychain` via `flutter_secure_storage`
- Per-account storage in local database

### Provider Dependency Graph

```
backendLifecycleProvider (accounts)
  ├─ Watches: hasAnyAccountProvider
  ├─ Auto-starts: RustBackendService.startForActiveAccount()
  └─ Auto-stops: RustBackendService.stopNode()

nodeRawStatusProvider
  ├─ Calls: RustBackendService.getStatus()
  ├─ Returns: peers, block heights, block producer status
  └─ Used by: nodeStatusProvider, nodeBlockchainProvider

nodeStatusProvider
  ├─ Derives from: nodeRawStatusProvider
  ├─ Returns: high-level NodeStatus entity
  └─ Used by: UI screens

nodeEpochRewardsProvider
  ├─ Calls: RustBackendService.epochRewards()
  ├─ Returns: won slots, rewards, produced blocks
  └─ Used by: NodeWonSlotsScreen, RewardsBreakdownScreen

epochRewardsUiProvider
  ├─ Calls: nodeEpochRewardsProvider
  ├─ Adds: caching, change detection, notifications
  └─ Used by: Home screen, rewards widgets
```

### To Implement Option A (Always-On)

1. **Add Android Foreground Service**
   - Create NotificationService.java
   - Call `startForeground()` with notification
   - Add wake locks for CPU/WiFi
   - Request battery optimization exemption

2. **Add iOS Background Modes**
   - Implement VoIP mode (requires Apple entitlement)
   - Use `CallKit` framework for background execution
   - Handle 30+ minute background execution

3. **Battery Awareness**
   - Monitor `BatteryManager` (Android)
   - Monitor `NSProcessInfo.thermalState` (iOS)
   - Pause production if overheating

### To Implement Option C (Cloud Failover)

1. **Heartbeat Service**
   - Send heartbeat every 30-60 seconds
   - Include node status, produced blocks, last slot

2. **Backend Failover API**
   - `/api/validator/heartbeat` - receive status
   - `/api/validator/failover` - trigger standby node
   - `/api/validator/reconcile` - catch up on recovery

3. **State Synchronization**
   - Persist produced blocks to backend
   - Download missing blocks on recovery
   - Detect and resolve forks

4. **UI Changes**
   - Show delegation status
   - Alert user when failover happens
   - Provide recovery controls

### RPC Interfaces Used

**`getStatus()`** - Comprehensive node status
- Peers: count, connection status, sync progress
- Blockchain: best tip, sync progress, block producer status
- Mempool: entries, orphans, total size
- Block Producer: public key, current state (WonSlot, Producing, etc.)

**`epochRewards()`** - Won slots and rewards for current epoch
- Epoch number
- Won slots: array of {globalSlot, expectedTimeMs}
- Produced in epoch: count
- Wins in epoch: count
- Earned so far: BigInt
- Expected total: BigInt

**`listBlockchain()`** - Recently produced blocks
- Total blocks
- Items: array of {height, epoch, globalSlot, hash, producer, batches}
- Used to track which slots were produced

**`listMempool()`** - Pending transactions
- Entries: count and list
- Orphans: count
- Total size

### Testing Considerations

1. **Foreground Service Test**
   - Start app, open NodeStatus screen
   - Background app (swipe away)
   - Wait 5 minutes
   - Foreground app - should still be synced

2. **Block Production Test**
   - Wait for assigned slot
   - Monitor `blockProducer.status` in getStatus()
   - Should transition: WaitForSlot -> ProduceInit -> Batching -> Signing -> Produced

3. **Background Task Test**
   - On Android: `adb shell dumpsys jobscheduler` to monitor WorkManager
   - On iOS: Background app, wait for task trigger, check logs
   - Verify notifications are scheduled correctly

4. **Recovery Test**
   - Shut down app forcefully (adb shell kill)
   - Restart app
   - Verify node catches up quickly (should take seconds, not minutes)

### Dependencies Used

- `workmanager: ^0.5.2` - Background tasks
- `flutter_local_notifications: ^17.0.0` - Notifications
- `flutter_riverpod: ^2.5.1` - State management
- `flutter_rust_bridge: git@` - FFI to Rust code
- `shared_preferences: ^2.2.3` - Local persistence
- `flutter_secure_storage: ^9.2.2` - Secure key storage (should use more)

---

## Next Steps

### Immediate (Fix Critical Issues)
1. Move block producer key to secure storage - 2-3 weeks
2. Implement Android foreground service - 1-2 weeks
3. Add block production telemetry - 1 week

### Short-term (Stabilize Option B)
1. State persistence for fast resume - 2-3 weeks
2. Background task reliability improvements - 1 week
3. Better error handling and recovery - 1 week

### Medium-term (Explore Option A/C)
1. Battery and thermal awareness - 2 weeks
2. Cloud failover infrastructure - 4-6 weeks
3. Advanced diagnostics dashboard - 2 weeks

For detailed analysis, see: `BLOCK_PRODUCTION_ANALYSIS.md` in project root
