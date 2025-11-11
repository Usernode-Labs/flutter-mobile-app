# Block Production Documentation Index

This directory contains comprehensive documentation about the block production implementation in the Flutter mobile app.

## Documents Overview

### 1. BLOCK_PRODUCTION_SUMMARY.md (Quick Reference - 274 lines)
**Start here if you have 15 minutes.**

- Current implementation status (Option B - Partially Implemented)
- What works and what doesn't
- Block production flow diagram
- All critical files with absolute paths
- Key hardcoded values that need to be fixed
- Provider dependency graph
- Next steps with effort estimates

**Best for:** Understanding the current state, identifying gaps, planning improvements

---

### 2. BLOCK_PRODUCTION_ANALYSIS.md (Detailed Analysis - 672 lines)
**Deep dive for architects and senior developers.**

- Executive summary with system diagram
- Complete architecture overview with all components
- Detailed implementation status for each feature
- What IS implemented (Option B foundation)
- What IS NOT implemented (missing for A, C, D)
- Key files and their responsibilities (table)
- Detailed provider descriptions
- Platform-specific constraints (Android & iOS)
- Block production flow (5 sequential diagrams)
- Which strategies are currently implemented
- Critical gaps with impact/effort analysis
- RPC interface specifications
- Hardcoded configuration locations
- Recommendations by phase (Phase 1-4)
- Strategy comparison table

**Best for:** Comprehensive understanding, decision making, architecture planning

---

## Quick Navigation

### By Question

**"What's working right now?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "What Works Now"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Current Implementation Status"

**"Why can't blocks be produced in the background?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "Critical Gaps"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Platform-Specific Constraints & Realities"

**"Which files do I need to modify?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "Key Files"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Key Files & Their Responsibilities"

**"How do I implement foreground service?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "To Implement Option A"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Critical Gaps for Block Production Reliability" #1

**"What about cloud failover (Option C)?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "To Implement Option C"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Option C - Hybrid Local + Cloud Co-Producer"

**"How do the providers work?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "Provider Dependency Graph"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Providers (State Management)"

**"What are the hardcoded secrets?"**
- See: BLOCK_PRODUCTION_SUMMARY.md → "Hardcoded Configuration to Replace"
- See: BLOCK_PRODUCTION_ANALYSIS.md → "Hardcoded Configuration & Secrets"

---

## Key Findings Summary

### Current Status
- **Strategy:** Option B (Opportunistic Local + Scheduled Sync)
- **Completeness:** 60% - Core framework in place, critical gaps remain
- **Production Ready:** NO - Multiple critical blockers

### What Works
1. Active session (app open) - node runs continuously
2. Background task scheduling (15 min Android, 30 sec iOS)
3. Smart notification batching
4. Account lifecycle management
5. Slot monitoring and detection

### What Doesn't Work (Critical Blockers)
1. **No foreground service** - Node killed when app backgrounded on Android
2. **Hardcoded block producer key** - Not account-specific, security risk
3. **No state persistence** - Full resync required on every restart
4. **Limited iOS** - Only 30 seconds per background task

### Recommended Priority

#### Phase 1 (Immediate - 4-5 weeks)
1. Move block producer key to secure storage (2-3 weeks)
2. Implement Android foreground service (1-2 weeks)
3. Add block production telemetry (1 week)

#### Phase 2 (Short-term - 4 weeks)
1. State persistence for fast resume (2-3 weeks)
2. Background task reliability (1 week)

#### Phase 3+ (Medium/Long-term)
1. Battery awareness and thermal throttling
2. Cloud failover architecture (Option C)
3. Advanced diagnostics dashboard

---

## Key Files (All Absolute Paths)

### Core Business Logic
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/data/repositories/rust_backend_service.dart` - Node lifecycle, RPC facade
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/services/background_task_service.dart` - Background task framework
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/services/slot_notification_manager.dart` - Smart notifications
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/core/providers/providers.dart` - Lifecycle management

### State Management
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/presentation/controllers/node_raw_status_provider.dart`
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/presentation/controllers/node_status_provider.dart`
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/node/presentation/controllers/node_data_providers.dart`
- `/Users/salah/Dev/lingash/flutter-mobile-app/lib/features/rewards/presentation/controllers/epoch_rewards_provider.dart`

### Platform Configuration
- **Android Manifest:** `/Users/salah/Dev/lingash/flutter-mobile-app/android/app/src/main/AndroidManifest.xml`
- **Android Build:** `/Users/salah/Dev/lingash/flutter-mobile-app/android/app/build.gradle`
- **iOS Plist:** `/Users/salah/Dev/lingash/flutter-mobile-app/ios/Runner/Info.plist`
- **iOS AppDelegate:** `/Users/salah/Dev/lingash/flutter-mobile-app/ios/Runner/AppDelegate.swift`

### Rust Integration
- Node builder: `/Users/salah/Dev/lingash/flutter-mobile-app/lib/rust/node/builder.dart`
- RPC definitions: `/Users/salah/Dev/lingash/flutter-mobile-app/lib/rust/rpc.dart`
- **CRITICAL:** Block producer key hardcoded at `rust_backend_service.dart:89-91`

---

## How the System Works

### Startup Sequence
1. `main.dart` initializes Sentry, feature flags, notifications
2. `_bootstrapAsync()` starts background task service
3. `RustBackendService.init()` loads flutter_rust_bridge
4. `RustBackendService.startForActiveAccount()` checks for accounts
5. If accounts exist: `startNode()` builds and starts Rust node in background thread
6. Node connects to P2P network, syncs blocks, waits for assigned slots

### Active Session
- Providers refresh every 3-5 seconds
- UI shows real-time node status
- Rust node continuously monitors for assigned slots
- When slot arrives: assemble batch → ZK proof → sign → broadcast

### Background Execution
- WorkManager (Android) or BGProcessingTask (iOS) fires periodically
- `callbackDispatcher()` runs in isolated background thread
- Fetches current epoch, won slots, produced blocks
- Schedules notifications for upcoming slots
- **BUT:** On Android, node is typically killed within 1-5 minutes
- **BUT:** On iOS, task only runs for 30 seconds max

---

## Critical Issues to Fix

### Issue 1: Hardcoded Block Producer Key
**Location:** `rust_backend_service.dart:89-91`
```dart
builder.blockProducerHex(
    skHex: "def170e8016858220fe64bd78baa863c15b50d35f8308545210d0a4d2550881b");
```
**Problem:** Same key for all instances, in source code, not configurable
**Solution:** Load from secure storage per account
**Effort:** 2-3 weeks

### Issue 2: No Foreground Service
**Problem:** Node killed when app backgrounded on Android
**Solution:** Implement `startForeground()` with persistent notification
**Effort:** 1-2 weeks

### Issue 3: No State Persistence
**Problem:** Full resync required on every restart
**Solution:** Save/load state snapshots, implement fast-resume path
**Effort:** 2-3 weeks

### Issue 4: Limited iOS Background
**Problem:** Only 30 seconds per background task
**Solution:** Implement VoIP background mode or push-triggered wakeup
**Effort:** 3-4 weeks + Apple entitlement

---

## Testing Checklist

### Active Session
- [ ] Start app, open Node Status screen
- [ ] See node syncing and connecting to peers
- [ ] See block producer waiting for slots
- [ ] Refresh rate should be smooth (3-5 sec)

### Background Tasks
- [ ] Start app, enter background (swipe away)
- [ ] On Android: `adb shell dumpsys jobscheduler` shows task scheduled
- [ ] Wait 15 minutes (or force task with `adb shell cmd jobscheduler run`)
- [ ] Notifications should be scheduled correctly

### Block Production
- [ ] Wait for assigned slot time
- [ ] Monitor `blockProducer.status` - should show state transitions
- [ ] Should transition: WaitForSlot → ProduceInit → Batching → Signing → Produced
- [ ] Check `listBlockchain()` after slot - block should be in history

### Recovery
- [ ] Kill app forcefully: `adb shell am force-stop org.usernode.app`
- [ ] Restart app
- [ ] Node should catch up quickly (seconds, not minutes)

---

## Dependencies

From `pubspec.yaml`:
- `workmanager: ^0.5.2` - Background tasks
- `flutter_local_notifications: ^17.0.0` - Notifications
- `flutter_riverpod: ^2.5.1` - State management
- `flutter_rust_bridge: git@` - FFI to Rust code
- `shared_preferences: ^2.2.3` - Local persistence
- `flutter_secure_storage: ^9.2.2` - Secure key storage

---

## Next Steps

1. **Read BLOCK_PRODUCTION_SUMMARY.md** (15 min) for quick overview
2. **Read BLOCK_PRODUCTION_ANALYSIS.md** (45 min) for detailed understanding
3. **Identify your use case:**
   - User validator: Start with foreground service (Phase 1)
   - Enterprise validator: Plan for cloud failover (Option C)
   - Mobile-first: Evaluate costs/benefits of Option A vs Option B+
4. **Create detailed implementation plan** based on findings
5. **Set up continuous testing** for background execution

---

## Document Metadata

- **Created:** November 11, 2025
- **Current App Status:** On branch `55-CI`
- **Flutter Version:** ≥3.35.0
- **Dart Version:** ≥3.3.0
- **Rust Bridge:** Custom flutter_rust_bridge fork
- **Node Backend:** Separate `usernode/` monorepo

For questions or updates, refer to the main documentation files.
