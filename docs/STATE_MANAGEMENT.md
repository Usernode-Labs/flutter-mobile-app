# State Management Architecture

> **Last Updated**: 2025-10-21
> **Version**: 1.0.0

This document provides a comprehensive guide to the app's state management architecture, including all providers, data flows, and the central RustBackendService.

---

## Table of Contents

- [Overview](#overview)
- [Architecture Principles](#architecture-principles)
- [RustBackendService](#rustbackendservice)
- [Provider Inventory](#provider-inventory)
- [Data Flow Diagrams](#data-flow-diagrams)
- [Code Examples](#code-examples)
- [Best Practices](#best-practices)
- [Quick Reference](#quick-reference)
- [Troubleshooting](#troubleshooting)

---

## Overview

### State Management Stack

The app uses **Riverpod** for state management with a centralized backend service pattern:

```
┌─────────────────────────────────────────┐
│         UI Layer (Widgets)              │
│  ↓ Watches providers via ref.watch()   │
├─────────────────────────────────────────┤
│      Riverpod Providers (25 total)     │
│  ↓ Fetch data and manage state         │
├─────────────────────────────────────────┤
│       RustBackendService (Singleton)    │
│  ↓ Centralized backend communication   │
├─────────────────────────────────────────┤
│     Rust Backend (via Flutter_Rust_Bridge)
│  Native node, blockchain, wallet operations
└─────────────────────────────────────────┘
```

### Key Components

1. **RustBackendService** - Singleton façade for all Rust backend operations
2. **25 Riverpod Providers** - State management across features
3. **Repository Layer** - Domain interfaces implemented by data layer
4. **Auto-refresh Mechanisms** - Keep UI in sync with backend state

---

## Architecture Principles

### 1. Single Source of Truth
- **RustBackendService** is the single point of contact with the Rust backend
- All RPC calls go through this service
- No direct bridge calls from UI or providers

### 2. Layered Architecture
```
Presentation → Domain → Data → RustBackendService → Rust Backend
```

### 3. Provider Organization
- **Core providers**: App-level state (theme, accounts, lifecycle)
- **Feature providers**: Feature-specific state (wallet, node, rewards)
- **Derived providers**: Computed from other providers (sync status)

### 4. Error Handling
- Defensive error handling in RustBackendService
- PanicException catching from Rust bridge
- Graceful degradation (return null on errors)
- Comprehensive Sentry logging

---

## RustBackendService

### Overview

**Location**: `lib/features/node/data/repositories/rust_backend_service.dart`

**Purpose**: Centralized façade around flutter_rust_bridge generated APIs. Manages the lifecycle of the Rust node and exposes RPC methods.

### Architecture

```dart
class RustBackendService {
  // Singleton pattern
  static RustBackendService get instance => _instance ??= RustBackendService._();

  // State
  bool _initialized = false;
  bool _nodeRunning = false;
  String? _instanceId;
  Node? _node;
  NodeRpcClient? _rpc;

  // Lifecycle methods
  Future<void> init();
  Future<void> startNode({int? httpPort});
  Future<void> stopNode();
  Future<bool> startForActiveAccount();
  Future<void> restartForActiveAccount();

  // RPC methods
  Future<RpcStatusResp?> getStatus();
  Future<RpcListBlockchainResp?> listBlockchain({int? limit, bool? fromTip});
  Future<RpcListMempoolResp?> listMempool({...});
  Future<RpcEpochRewardsResp?> epochRewards({int? epoch});
  Future<RpcListUtxosByOwnerResp?> listUtxosByOwner({required PublicKeyHash owner, int? limit});
  Future<RpcTransferFundsResp?> transferFunds({required PublicKeyHash fromPkHash, required BigInt amount, required PublicKeyHash toPkHash});
}
```

### Lifecycle Management

#### Initialization Flow
```
main.dart startup
    ↓
RustBackendService.init()
    ↓
RustLib.init() (Flutter Rust Bridge)
    ↓
RustBackendService.startForActiveAccount()
    ↓
Check if account exists
    ├─ Yes → startNode()
    └─ No  → skip (return false)
```

#### Auto Lifecycle Management
```
backendLifecycleProvider (watches hasAnyAccountProvider)
    ↓
Account created (false → true)
    → RustBackendService.startForActiveAccount()

Account deleted (true → false)
    → RustBackendService.stopNode()
```

### RPC Methods Detail

#### getStatus()
**Returns**: `RpcStatusResp?`

**Contains**:
- `peers` - List of peer connection info
- `blockchain` - Blockchain best tip and sync status
- `batcher` - Transaction batching statistics (11 fields)
- `blockProducer` - Block production status
- `mempool` - Mempool statistics and reorg info

**Logged Fields** (for telemetry):
- All peer data (address, connectionStatus, incoming, bestTip, etc.)
- Complete blockchain data (bestTip, sync progress)
- All batcher metrics (pendingLeaves, totalIssuedBatches, etc.)
- Block producer status (pubKey, status type, wonSlot info)
- Mempool data (entries, orphans, totalSize, unleased, lastReorg)

**Usage**: 3 locations
- NodeRepositoryImpl
- NodeRawStatusProvider
- BestTipCacheProvider

#### listMempool()
**Parameters**: `owner?`, `limit?`, `idsOnly?`, `cursorAfter?`
**Returns**: `RpcListMempoolResp?`

**Contains**:
- `count` - Total transactions
- `orphans` - Orphaned transaction count
- `totalSize` - Total size in bytes
- `entries` - List of transactions

**Usage**: 5 locations
- WalletMempoolProvider (with owner filter)
- MempoolCacheProvider (all transactions)
- NodeMempoolController
- NodeMempoolResultProvider

#### listBlockchain()
**Parameters**: `limit?`, `fromTip?`
**Returns**: `RpcListBlockchainResp?`

**Contains**:
- `totalBlocks` - Total blockchain height
- `items` - List of block info
- `rootHash`, `tipHash` - Chain anchors

**Usage**: 2 locations
- NodeBlockchainController (limit: 20, fromTip: true)
- NodeBlockchainResultProvider

#### epochRewards()
**Parameters**: `epoch?`, `includeWonSlots?`
**Returns**: `RpcEpochRewardsResp?`

**Contains**:
- `epoch` - Epoch number
- `rewardPerBlock` - Reward amount per block
- `producedInEpoch` - Blocks produced
- `winsInEpoch` - Slots won
- `earnedSoFar` - Total earned so far
- `expectedTotal` - Expected total for epoch
- `wonSlots` - List of won slots with timestamps

**Usage**: 5 locations
- EpochRewardsUiProvider
- NodeEpochRewardsController
- NodeEpochRewardsResultProvider
- ProfileScreen
- RewardsBreakdownScreen

#### listUtxosByOwner()
**Parameters**: `owner` (required), `limit?`
**Returns**: `RpcListUtxosByOwnerResp?`

**Contains**:
- `items` - List of owned UTXOs

**Usage**: 1 location
- WalletUtxosProvider

#### transferFunds()
**Parameters**: `fromPkHash`, `amount`, `toPkHash`
**Returns**: `RpcTransferFundsResp?`

**Contains**:
- `queued` - Boolean success indicator
- `error` - Error message if failed

**Usage**: 1 location
- ReviewSendScreen (transaction submission)

### Usage Statistics

**By RPC Method**:
- `getStatus()`: 3 usages
- `listMempool()`: 5 usages
- `listBlockchain()`: 2 usages
- `epochRewards()`: 5 usages
- `listUtxosByOwner()`: 1 usage
- `transferFunds()`: 1 usage

**By Category**:
- Lifecycle Management: 5 locations
- Node Status/Blockchain: 5 locations
- Wallet/UTXOs: 2 locations
- Mempool: 5 locations
- Rewards: 5 locations
- Transfers: 1 location
- Tests: 6 contract tests

**Total Files Using RustBackendService**: 18

### Complete Usage Map

#### Lifecycle Management (5 locations)

1. **main.dart:59-60** - Application startup
   ```dart
   await RustBackendService.instance.init();
   final started = await RustBackendService.instance.startForActiveAccount();
   ```

2. **core/providers/providers.dart:47** - Backend lifecycle (account created)
   ```dart
   await RustBackendService.instance.startForActiveAccount();
   ```

3. **core/providers/providers.dart:54** - Backend lifecycle (account deleted)
   ```dart
   await RustBackendService.instance.stopNode();
   ```

4. **wallet_screen.dart:67,71** - Manual restart check
   ```dart
   if (_account != null && !RustBackendService.instance.isRunning) {
     await RustBackendService.instance.startForActiveAccount();
   }
   ```

5. **node_repository_impl.dart:17,26** - Repository wrapper
   ```dart
   await RustBackendService.instance.init();
   return await RustBackendService.instance.startForActiveAccount();
   ```

#### Node Status (3 locations)

6. **node_repository_impl.dart:35** - Domain repository
7. **node_raw_status_provider.dart:79** - Main status provider
8. **best_tip_cache_provider.dart:16** - Best tip cache

#### Mempool (5 locations)

9. **wallet/mempool_provider.dart:50** - Wallet pending transactions
10. **node/mempool_cache_provider.dart:16** - Mempool UI state
11. **node_data_providers.dart:24** - Node mempool controller
12. **node_data_providers.dart:42** - Node mempool result provider

#### Blockchain (2 locations)

13. **node_data_providers.dart:66** - Blockchain controller
14. **node_data_providers.dart:84** - Blockchain result provider

#### Epoch Rewards (5 locations)

15. **epoch_rewards_provider.dart:28** - Rewards UI provider
16. **node_data_providers.dart:119** - Epoch rewards controller
17. **node_data_providers.dart:140** - Epoch rewards result provider
18. **profile_screen.dart:86** - Profile screen display
19. **rewards_breakdown_screen.dart:29** - Rewards breakdown

#### Wallet UTXOs (1 location)

20. **utxo_provider.dart:46** - Wallet UTXOs provider

#### Transfers (1 location)

21. **review_send_screen.dart:113** - Transaction submission

#### Onboarding (2 locations)

22. **create_new_account_screen.dart:81** - After account creation
23. **import_seed_phrase_screen.dart:101** - After seed import

---

## Provider Inventory

### Summary Statistics

- **Total Providers**: 25
- **AsyncNotifierProvider**: 9 (with refresh methods)
- **Provider**: 6
- **NotifierProvider**: 1
- **FutureProvider**: 1
- **StateNotifierProvider**: 2

### Core Providers (7)

| Provider | Type | Data | Refresh | Description |
|----------|------|------|---------|-------------|
| `walletRepositoryProvider` | Provider | WalletRepository | No | Singleton wallet repository instance |
| `nodeRepositoryProvider` | Provider | NodeRepository | No | Singleton node repository instance |
| `hasAnyAccountProvider` | FutureProvider | bool | Auto | Checks if any account exists in storage |
| `backendLifecycleProvider` | Provider | void | Auto | Listens to account changes, starts/stops backend |
| `buildEnvProvider` | Provider | BuildInfo | No | Build environment from Rust bindings |
| `useResultProvidersProvider` | Provider | bool | No | Feature flag for Result-based providers |
| `themeModeProvider` | StateNotifierProvider | ThemeMode | No | Theme mode with persistence (system/light/dark) |

**Location**: `lib/core/providers/providers.dart`

### Node Status Providers (7)

| Provider | Type | Data | Refresh | Description |
|----------|------|------|---------|-------------|
| `nodeRawStatusProvider` | AsyncNotifierProvider | NodeRawStatusView? | ✅ Yes | Raw node status from RPC (peers, blockchain, progress) |
| `nodeStatusProvider` | Provider | AsyncValue\<NodeStatus?\> | Derived | Simplified domain entity (derived from nodeRawStatusProvider) |
| `syncStatusProvider` | Provider | SyncStatus | Derived | **Enhanced** sync state with peer awareness (connecting/syncing/synced/error states, considers peer heights) |
| `bestTipUiProvider` | AsyncNotifierProvider | BestTipUiState? | No | Best tip blockchain data (live only, no cache) |
| `mempoolUiProvider` | AsyncNotifierProvider | MempoolUiState? | No | Mempool summary (count, orphans, totalSize) |
| `slotViewPrefsProvider` | StateNotifierProvider | SlotViewPrefs | No | UI preferences for slot view filters |
| `notificationsProvider` | NotifierProvider | NotificationsState | No | App notifications management |

**Locations**:
- `lib/features/node/presentation/controllers/`
- `lib/core/providers/notifications_provider.dart`

### Wallet Providers (4)

| Provider | Type | Data | Refresh | Description |
|----------|------|------|---------|-------------|
| `walletUtxosProvider` | AsyncNotifierProvider | List\<OwnedUtxo\> | ✅ Yes | UTXOs for active account |
| `walletMempoolProvider` | AsyncNotifierProvider | List\<MempoolTxSummary\> | ✅ Yes | Pending transactions from mempool |
| `walletAssetsProvider` | AsyncNotifierProvider | List\<AssetSummary\> | ✅ Yes | Aggregated assets by token_id with USD values |
| `transactionActivityProvider` | AsyncNotifierProvider | List\<TransactionItem\> | ✅ Yes | Combined mempool + confirmed UTXOs (sorted) |

**Location**: `lib/features/wallet/presentation/controllers/`

### Rewards Provider (1)

| Provider | Type | Data | Refresh | Description |
|----------|------|------|---------|-------------|
| `epochRewardsUiProvider` | AsyncNotifierProvider | EpochRewardsUiState? | No | Epoch rewards with notification on increase |

**Location**: `lib/features/rewards/presentation/controllers/epoch_rewards_provider.dart`

### Node Data Providers (6)

| Provider | Type | Data | Refresh | Description |
|----------|------|------|---------|-------------|
| `nodeMempoolProvider` | AsyncNotifierProvider | RpcListMempoolResp? | ✅ Yes | All mempool transactions (raw RPC response) |
| `nodeMempoolResultProvider` | FutureProvider | Result\<RpcListMempoolResp?\> | No | Result-wrapped mempool data |
| `nodeBlockchainProvider` | AsyncNotifierProvider | RpcListBlockchainResp? | ✅ Yes | Recent 20 blocks (raw RPC response) |
| `nodeBlockchainResultProvider` | FutureProvider | Result\<RpcListBlockchainResp?\> | No | Result-wrapped blockchain data |
| `nodeEpochRewardsProvider` | AsyncNotifierProvider | RpcEpochRewardsResp? | ✅ Yes | Epoch rewards (depends on current epoch) |
| `nodeEpochRewardsResultProvider` | FutureProvider | Result\<RpcEpochRewardsResp?\> | No | Result-wrapped epoch rewards |

**Location**: `lib/features/node/presentation/controllers/node_data_providers.dart`

**Note**: Result-wrapped providers are available for uniform error propagation patterns.

### Providers with Refresh Capability

9 providers support manual refresh via `.refresh()` method:

1. `nodeRawStatusProvider`
2. `walletUtxosProvider`
3. `walletMempoolProvider`
4. `walletAssetsProvider`
5. `transactionActivityProvider`
6. `nodeMempoolProvider`
7. `nodeBlockchainProvider`
8. `nodeEpochRewardsProvider`

---

## Data Flow Diagrams

### Application Startup & Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           APPLICATION STARTUP & LIFECYCLE                            │
└─────────────────────────────────────────────────────────────────────────────────────┘

                                    main.dart
                                        │
                        ┌───────────────┼───────────────┐
                        ▼               ▼               ▼
                 RustBackendService  FeatureFlags  AppLifecycleLogger
                      .init()         .load()        .register()
                        │
                        ▼
            RustBackendService.startForActiveAccount()
                        │
                        └──────────────────────────────────────┐
                                                               │
┌──────────────────────────────────────────────────────────────▼─────────────────────┐
│                         CORE BACKEND LIFECYCLE MANAGEMENT                           │
└─────────────────────────────────────────────────────────────────────────────────────┘

     hasAnyAccountProvider                      backendLifecycleProvider
    (FutureProvider<bool>)                         (Provider<void>)
              │                                          │
              │                                    ┌─────┴────watch──────┐
              │                                    │                     │
              └────────────────────────────────────┤                     │
                                                   │    Listen for       │
              ┌────────────────────────────────────┤    account changes  │
              │                                    │                     │
              │                                    └─────┬───────────────┘
              │                                          │
              ▼                                          ▼
    AccountsRepository.hasAny()          ┌───────────────────────────────┐
              │                          │  Account Created (false→true) │
              │                          │  → startForActiveAccount()    │
              │                          │                               │
              │                          │  Account Deleted (true→false) │
              │                          │  → stopNode()                 │
              │                          └───────────────┬───────────────┘
              │                                          │
              └──────────────────────────────────────────┼────────────────┐
                                                         │                │
                                                         ▼                ▼
                                              RustBackendService    [Node Running]
                                                   .instance              │
                                                      │                   │
                                                      └───────────────────┘
```

### RustBackendService Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           RUST BACKEND SERVICE (Singleton)                           │
│                         Central Hub for All Backend Operations                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

                              RustBackendService.instance
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
            State Properties      Lifecycle Methods    RPC Methods (via _rpc)
                    │                   │                   │
         ┌──────────┼─────────┐        │         ┌─────────┼─────────────────┐
         │          │         │        │         │         │         │       │
    _nodeRunning  _node   _rpc │       │    getStatus() listMempool() ...   │
         │          │         │        │         │         │         │       │
         │          │         │        ▼         │         │         │       │
         │          │         │   init()         │         │         │       │
         │          │         │   startNode()    │         │         │       │
         │          │         │   stopNode()     │         │         │       │
         │          │         │   startFor...()  │         │         │       │
         │          │         │                  │         │         │       │
         │          │         └──────────────────┼─────────┼─────────┼───────┘
         │          │                            │         │         │
         └──────────┴────────────────────────────┼─────────┼─────────┼────────┐
                                                 │         │         │        │
                                                 ▼         ▼         ▼        ▼
```

### Node Status Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              NODE STATUS DATA FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘

                         RustBackendService.getStatus()
                                        │
                        ┌───────────────┴───────────────┐
                        │        Returns RpcStatusResp   │
                        │   ┌────────────────────────┐  │
                        │   │ • peers                │  │
                        │   │ • blockchain           │  │
                        │   │ • batcher              │  │
                        │   │ • blockProducer        │  │
                        │   │ • mempool              │  │
                        │   └────────────────────────┘  │
                        └───────────────┬───────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
         NodeRepositoryImpl    nodeRawStatusProvider  bestTipUiProvider
         (domain wrapper)       (main raw data)      (best tip only)
                    │                   │                   │
                    │                   │                   │
                    ▼                   ▼                   │
            NodeStatus          NodeRawStatusView          │
           (simplified)         (full raw data)            │
                    │                   │                   │
                    │         ┌─────────┴─────────┐        │
                    │         │                   │        │
                    │         ▼                   ▼        │
                    │  syncStatusProvider  nodeStatusProvider
                    │   (SyncStatus)       (NodeStatus)    │
                    │         │                   │        │
                    │         └─────────┬─────────┘        │
                    │                   │                  │
                    └───────────────────┼──────────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
                    ▼                                       ▼
            NodeStatusIcon                    NodeStatusSummaryModal
          (app bar indicator)                 (detailed status view)
                    │                                       │
            ┌───────┴────────┐                  ┌──────────┴──────────┐
            │                │                  │                     │
       Error Icon      Synced Icon         Sync Card          Peers Card
       (red, no peers) (green check)       • Progress%        • Connected/Total
            │                │              • Block Height    • Health Status
       Syncing Icon     Rotating           • Sync Speed       │
       (blue, rotating)                    • ETA              Epoch Card
                                                              • Epoch Number
                                                              • Global Slot
```

### Enhanced Sync Status Calculation

The sync status provider now uses an improved algorithm that considers peer connectivity and compares heights across multiple sources:

```
┌──────────────────────────────────────────────────────────────────────────┐
│              IMPROVED SYNC STATUS DETERMINATION FLOW                      │
└──────────────────────────────────────────────────────────────────────────┘

                              Step 1: Check Peer Connectivity
                                            │
                        ┌───────────────────┴───────────────────┐
                        │                                       │
                        ▼                                       ▼
            ┌─────────────────────┐              ┌──────────────────────┐
            │ connectedPeers == 0 │              │ connectedPeers > 0   │
            └──────────┬──────────┘              └──────────┬───────────┘
                       │                                    │
                       ▼                                    ▼
            ┌─────────────────────┐              ┌──────────────────────┐
            │ State: CONNECTING   │              │ Step 2: Gather Heights│
            │ Icon: Grey Hourglass│              └──────────┬───────────┘
            │ Progress: 0%        │                         │
            └─────────────────────┘                         │
                                                            ▼
                                            ┌────────────────────────────┐
                                            │ A. Local Height            │
                                            │    = blockchain.best_tip   │
                                            │                            │
                                            │ B. Network Sync Height     │
                                            │    = blockchain.sync.blocks│
                                            │      .best_tip (if exists) │
                                            │                            │
                                            │ C. Peer Heights            │
                                            │    = max(peer.best_tip     │
                                            │        for connected peers)│
                                            └────────────┬───────────────┘
                                                         │
                                                         ▼
                                            ┌────────────────────────────┐
                                            │ Step 3: Calculate Network  │
                                            │                            │
                                            │ networkHeight = max(       │
                                            │   networkSyncHeight,       │
                                            │   highestPeerHeight        │
                                            │ )                          │
                                            └────────────┬───────────────┘
                                                         │
                                                         ▼
                                            ┌────────────────────────────┐
                                            │ Step 4: Compare            │
                                            │                            │
                                            │ local >= network?          │
                                            └────────────┬───────────────┘
                                                         │
                                    ┌────────────────────┴────────────────────┐
                                    │                                         │
                                    ▼                                         ▼
                        ┌────────────────────┐                  ┌────────────────────┐
                        │ State: SYNCED      │                  │ State: SYNCING     │
                        │ Icon: Green Check  │                  │ Icon: Blue Sync    │
                        │ Progress: 100%     │                  │ Progress: local/net│
                        └────────────────────┘                  └────────────────────┘


Status States:

  State        │ Condition               │ Icon        │ Color │ Progress
  ─────────────┼─────────────────────────┼─────────────┼───────┼─────────
  CONNECTING   │ connectedPeers == 0     │ Hourglass   │ Grey  │ 0.0
  SYNCING      │ local < network         │ Sync (spin) │ Blue  │ local/net
  SYNCED       │ local >= network        │ Check       │ Green │ 1.0
  ERROR        │ Backend error/no data   │ Error       │ Red   │ 0.0


Example Calculation:

  Given:
    - blockchain.best_tip.height = 1000 (local)
    - blockchain.sync.blocks.best_tip.height = 1050 (network sync)
    - Peer 1: best_tip_height = 1040
    - Peer 2: best_tip_height = 1055
    - Peer 3: best_tip_height = 1045
    - connectedPeers = 3

  Calculation:
    networkHeight = max(1050, max(1040, 1055, 1045)) = max(1050, 1055) = 1055
    localHeight (1000) < networkHeight (1055)

  Result:
    State: SYNCING
    Progress: 1000 / 1055 = 0.947 (94.7%)
    Label: "Syncing (94.7%)"
    Icon: Blue rotating sync icon
```

**Key Improvements:**
- ✅ Explicit "Connecting" state when no peers are connected
- ✅ Considers individual peer best tip heights in addition to network sync
- ✅ Uses maximum of network sync and peer heights for accurate comparison
- ✅ Better progress calculation based on real network state
- ✅ Comprehensive logging for debugging sync issues

### Wallet & Transaction Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          WALLET & TRANSACTION DATA FLOW                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

                         AccountsRepository.getActive()
                                        │
                                        ▼
                              [Active Account Address]
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
                    ▼                                       ▼
    RustBackendService.listUtxosByOwner()    RustBackendService.listMempool()
                    │                                       │
                    ▼                                       ▼
          walletUtxosProvider                   walletMempoolProvider
       (List<OwnedUtxo>)                     (List<MempoolTxSummary>)
                    │                                       │
         ┌──────────┴──────────┐                          │
         │                     │                           │
         ▼                     ▼                           │
   walletAssetsProvider  transactionActivityProvider◄─────┘
   (List<AssetSummary>)  (List<TransactionItem>)
         │                     │
         │                     ├─ Combines mempool + UTXOs
         │                     ├─ Sorts: pending first
         │                     └─ Filters by owner
         │
         ▼                     ▼
    Assets Screen         Activity Screen
    • Token balances      • Pending transactions
    • USD values          • Confirmed transactions
    • 24h changes         • Sent/Received status
```

### Rewards & Epoch Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          REWARDS & EPOCH DATA FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘

                     RustBackendService.epochRewards()
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
                    ▼                                       ▼
         epochRewardsUiProvider              nodeEpochRewardsProvider
      (EpochRewardsUiState?)                (RpcEpochRewardsResp?)
                    │                                       │
                    │                          ┌────────────┤
                    │                          │            │
                    │                          ▼            ▼
                    │              nodeEpochRewardsResultProvider
                    │              (Result<RpcEpochRewardsResp?>)
                    │                          │
                    │                          │
                    ├──────────────────────────┘
                    │
                    ├─ Tracks reward changes
                    ├─ Sends notifications when rewards increase
                    │
                    ▼
         notificationsProvider
         (NotificationsState)
                    │
                    ├─ Add notification
                    ├─ Mark as read
                    ├─ Delete notification
                    └─ Clear all
                    │
                    ▼
         [Notifications UI]
         • Reward earned alerts
         • Unread count
         • Notification list
```

### Transaction Send Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          TRANSACTION SEND FLOW                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

                         [User Action: Send Tokens]
                                        │
                                        ▼
                            ReviewSendScreen
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
                    ▼                                       ▼
         Get fromPkHash                          Get toPkHash
         (from active account)                   (from recipient)
                    │                                       │
                    └───────────────────┬───────────────────┘
                                        │
                                        ▼
                    RustBackendService.transferFunds(
                       fromPkHash, amount, toPkHash
                    )
                                        │
                                        ▼
                            RpcTransferFundsResp
                                        │
                            ┌───────────┴───────────┐
                            │                       │
                            ▼                       ▼
                      queued: true            queued: false
                      (success)               (failed, with error)
                            │                       │
                            ▼                       ▼
                    [Show success]          [Show error message]
                    [Navigate back]
```

### Auto-Refresh Mechanism

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            AUTO-REFRESH MECHANISMS                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘

                    NodeStatusSummaryModal (when open)
                                        │
                                        ├─ Timer: every 5 seconds
                                        │
                                        ▼
                    nodeRawStatusProvider.refresh()
                                        │
                                        ▼
                    RustBackendService.getStatus()
                                        │
                                        ▼
                    [UI updates with new data]
                    • Sync progress
                    • Block height
                    • Peer count
                    • Sync speed calculation
                    • ETA estimation
```

### Complete Provider Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            DATA DEPENDENCIES SUMMARY                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘

                         RustBackendService (Singleton)
                                        │
                ┌───────────────────────┼───────────────────────┐
                │                       │                       │
                ▼                       ▼                       ▼
         [Node Status]            [Wallet Data]          [Rewards Data]
                │                       │                       │
        ┌───────┼───────┐       ┌──────┼──────┐       ┌────────┼────────┐
        ▼       ▼       ▼       ▼      ▼      ▼       ▼        ▼        ▼
      Status  Mempool  Best   UTXOs  Mempool Assets  Epoch   Won     Rewards
      Data    (Node)   Tip    (Wallet)(Wallet)      Rewards Slots   Breakdown
        │       │       │       │      │      │       │        │        │
        └───────┴───────┴───────┴──────┴──────┴───────┴────────┴────────┘
                                        │
                                        ▼
                              [UI Components consume data]

Provider Dependencies:

hasAnyAccountProvider
    ↓
backendLifecycleProvider (starts/stops RustBackendService)
    ↓
RustBackendService.getStatus()
    ↓
nodeRawStatusProvider
    ├─→ nodeStatusProvider
    └─→ syncStatusProvider
            ↓
        NodeStatusIcon (UI)

walletUtxosProvider
    ├─→ walletAssetsProvider (aggregates by token)
    └─→ transactionActivityProvider
            ↑
    walletMempoolProvider
```

---

## Code Examples

### Using Providers in Widgets

#### Basic Provider Usage

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a provider (rebuilds when data changes)
    final nodeStatusAsync = ref.watch(nodeRawStatusProvider);

    // Handle async state
    return nodeStatusAsync.when(
      data: (status) {
        if (status == null) return Text('No data');
        return Text('Peers: ${status.totalPeers}');
      },
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

#### Reading Provider Once (No Rebuild)

```dart
class MyActionButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        // Read provider value once without watching
        final status = ref.read(nodeStatusProvider).value;
        if (status != null) {
          print('Current epoch: ${status.epoch}');
        }
      },
      child: Text('Check Status'),
    );
  }
}
```

#### Manual Refresh

```dart
class RefreshableList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utxosAsync = ref.watch(walletUtxosProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger manual refresh
        await ref.read(walletUtxosProvider.notifier).refresh();
      },
      child: utxosAsync.when(
        data: (utxos) => ListView.builder(
          itemCount: utxos.length,
          itemBuilder: (ctx, i) => ListTile(
            title: Text('UTXO ${i + 1}'),
          ),
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('Error: $err'),
      ),
    );
  }
}
```

### Using RustBackendService Directly

#### Calling RPC Methods

```dart
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

class MyService {
  Future<void> checkNodeStatus() async {
    final backend = RustBackendService.instance;

    // Check if backend is running
    if (!backend.isRunning) {
      print('Backend not running');
      return;
    }

    // Call getStatus
    final status = await backend.getStatus();
    if (status == null) {
      print('Failed to get status');
      return;
    }

    // Access data
    print('Connected peers: ${status.peers.length}');
    print('Best height: ${status.blockchain.bestTip.height}');
  }
}
```

#### Starting Backend for Account

```dart
Future<void> onAccountCreated() async {
  final backend = RustBackendService.instance;

  // Initialize if not already done
  if (!backend.isRunning) {
    await backend.init();
  }

  // Start for active account
  final started = await backend.startForActiveAccount();
  if (started) {
    print('Backend started successfully');
  } else {
    print('No account found, backend not started');
  }
}
```

### Creating Custom Providers

#### Simple Derived Provider

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Derive peer health from raw status
final peerHealthProvider = Provider<String>((ref) {
  final raw = ref.watch(nodeRawStatusProvider).value;
  if (raw == null) return 'Unknown';

  final connected = raw.connectedPeers;
  final total = raw.totalPeers;

  if (connected == 0) return 'No peers';
  if (connected == total) return 'All connected';
  return '$connected/$total connected';
});
```

#### AsyncNotifier with Refresh

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyDataController extends AsyncNotifier<MyData?> {
  @override
  Future<MyData?> build() async {
    return await _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<MyData?> _fetch() async {
    try {
      final backend = RustBackendService.instance;
      final status = await backend.getStatus();
      // Transform data...
      return MyData.fromStatus(status);
    } catch (e, st) {
      LoggingService.instance.error('Fetch failed',
        tag: 'MY_DATA', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final myDataProvider = AsyncNotifierProvider<MyDataController, MyData?>(
  MyDataController.new,
);
```

### Error Handling Patterns

#### Defensive Error Handling

```dart
class SafeDataController extends AsyncNotifier<Data?> {
  @override
  Future<Data?> build() async {
    try {
      final result = await RustBackendService.instance.getStatus();
      if (result == null) {
        // Graceful null handling
        return null;
      }
      return Data.from(result);
    } on PanicException catch (e, st) {
      // Rust panic - log and return null
      LoggingService.instance.error('Rust panic',
        tag: 'DATA', error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'panic_getData');
      return null;
    } catch (e, st) {
      // Other errors - log but rethrow to show error UI
      LoggingService.instance.error('Data fetch failed',
        tag: 'DATA', error: e, stackTrace: st);
      rethrow;
    }
  }
}
```

#### Result-based Error Handling

```dart
import 'package:crypto_mobile_app/core/result.dart';

final myResultProvider = FutureProvider<Result<Data>>((ref) async {
  try {
    final status = await RustBackendService.instance.getStatus();
    if (status == null) {
      return Err(BackendError('Status is null'));
    }
    return Ok(Data.from(status));
  } catch (e, st) {
    LoggingService.instance.error('Failed', error: e, stackTrace: st);
    return Err(BackendError('Failed to load', cause: e, stackTrace: st));
  }
});

// Usage in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(myResultProvider);

    return resultAsync.when(
      data: (result) => result.when(
        ok: (data) => Text('Data: $data'),
        err: (error) => Text('Error: ${error.message}'),
      ),
      loading: () => CircularProgressIndicator(),
      error: (err, _) => Text('Unexpected error: $err'),
    );
  }
}
```

---

## Best Practices

### 1. Provider Organization

#### DO ✅
- Keep providers close to their feature
- Use descriptive, specific names
- Document provider purpose and data shape
- Group related providers together

```dart
// ✅ Good
final walletUtxosProvider = ...;
final walletMempoolProvider = ...;
final walletAssetsProvider = ...;
```

#### DON'T ❌
- Create global "god" providers
- Mix unrelated data in one provider
- Use generic names like `dataProvider`

```dart
// ❌ Bad
final allDataProvider = ...;
final stuffProvider = ...;
```

### 2. Provider Dependencies

#### DO ✅
- Use `ref.watch()` for dependencies that should rebuild
- Use `ref.read()` for one-time reads in callbacks
- Keep dependency chains shallow (2-3 levels max)

```dart
// ✅ Good
final derivedProvider = Provider((ref) {
  final base = ref.watch(baseProvider);
  return base.transform();
});
```

#### DON'T ❌
- Create circular dependencies
- Watch providers in `onPressed` callbacks
- Create deep dependency chains (4+ levels)

```dart
// ❌ Bad - watching in callback
onPressed: () {
  final data = ref.watch(provider); // Use ref.read() instead
}
```

### 3. State Refresh Strategies

#### Automatic Refresh (Polling)
Use timers when data must be fresh:

```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 5), (_) {
      ref.read(nodeRawStatusProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

#### Manual Refresh (Pull-to-Refresh)
Use RefreshIndicator for user-initiated refresh:

```dart
RefreshIndicator(
  onRefresh: () async {
    await ref.read(walletUtxosProvider.notifier).refresh();
  },
  child: ListView(...),
)
```

#### Event-Based Refresh
Refresh when specific events occur:

```dart
Future<void> onTransactionSent() async {
  // Refresh wallet data after sending transaction
  await ref.read(walletUtxosProvider.notifier).refresh();
  await ref.read(walletMempoolProvider.notifier).refresh();
}
```

### 4. Error Handling Guidelines

#### Always Handle Errors Gracefully
```dart
// ✅ Good - graceful degradation
return statusAsync.when(
  data: (status) => status != null
    ? StatusDisplay(status)
    : EmptyState('No data'),
  loading: () => LoadingIndicator(),
  error: (err, _) => ErrorDisplay(err),
);
```

#### Log Errors for Debugging
```dart
catch (e, st) {
  LoggingService.instance.error(
    'Operation failed',
    tag: 'MY_FEATURE',
    error: e,
    stackTrace: st,
  );
  await SentryUtil.captureError(e, st, tag: 'my_feature_error');
}
```

#### Don't Silently Swallow Errors
```dart
// ❌ Bad
try {
  await something();
} catch (e) {
  // Silent failure - user has no idea what happened
}

// ✅ Good
try {
  await something();
} catch (e, st) {
  LoggingService.instance.error('Failed', error: e, stackTrace: st);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operation failed: $e')),
    );
  }
}
```

### 5. Performance Optimization

#### Use `.select()` for Specific Fields
Rebuild only when specific fields change:

```dart
// ✅ Rebuilds only when epoch changes
final epoch = ref.watch(nodeStatusProvider.select((s) => s.value?.epoch));
```

#### Avoid Unnecessary Watches
```dart
// ❌ Bad - rebuilds entire widget on any status change
final status = ref.watch(nodeRawStatusProvider);

// ✅ Good - only watch what you need
final peerCount = ref.watch(
  nodeRawStatusProvider.select((s) => s.value?.totalPeers)
);
```

#### Cache Expensive Computations
```dart
final expensiveDataProvider = Provider((ref) {
  final raw = ref.watch(rawDataProvider);
  // This computation only runs when rawDataProvider changes
  return expensiveComputation(raw);
});
```

### 6. Testing Providers

#### Override Providers in Tests
```dart
testWidgets('Shows peer count', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nodeRawStatusProvider.overrideWith((ref) => AsyncValue.data(
          NodeRawStatusView(/* mock data */),
        )),
      ],
      child: MyApp(),
    ),
  );

  expect(find.text('5 peers'), findsOneWidget);
});
```

---

## Quick Reference

### Provider Lookup Table

| Need | Provider | Import |
|------|----------|--------|
| Node status (full) | `nodeRawStatusProvider` | `features/node/presentation/controllers/node_raw_status_provider.dart` |
| Node status (simple) | `nodeStatusProvider` | `features/node/presentation/controllers/node_status_provider.dart` |
| Sync status | `syncStatusProvider` | `features/node/presentation/controllers/sync_status_provider.dart` |
| UTXOs | `walletUtxosProvider` | `features/wallet/presentation/controllers/utxo_provider.dart` |
| Pending transactions | `walletMempoolProvider` | `features/wallet/presentation/controllers/mempool_provider.dart` |
| Asset balances | `walletAssetsProvider` | `features/wallet/presentation/controllers/assets_provider.dart` |
| Transaction activity | `transactionActivityProvider` | `features/wallet/presentation/controllers/transaction_activity_provider.dart` |
| Epoch rewards | `epochRewardsUiProvider` | `features/rewards/presentation/controllers/epoch_rewards_provider.dart` |
| Theme mode | `themeModeProvider` | `core/providers/providers.dart` |
| Notifications | `notificationsProvider` | `core/providers/notifications_provider.dart` |

### Common Patterns Cheat Sheet

#### Watch and Display Data
```dart
final data = ref.watch(provider);
return data.when(
  data: (d) => Text('$d'),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

#### Manual Refresh
```dart
await ref.read(provider.notifier).refresh();
```

#### Read Once in Callback
```dart
onPressed: () {
  final value = ref.read(provider).value;
  print(value);
}
```

#### Select Specific Field
```dart
final field = ref.watch(provider.select((s) => s.value?.field));
```

#### Check Backend Running
```dart
if (RustBackendService.instance.isRunning) {
  // Backend is ready
}
```

#### Call RPC Method
```dart
final status = await RustBackendService.instance.getStatus();
```

---

## Logging

The app uses an enhanced logging system built on the `logger` package with additional features for production debugging and performance tracking.

### Features

#### 1. Type-Safe Tags
Use `LogTag` enum instead of strings to prevent typos:

```dart
import 'package:crypto_mobile_app/core/utils/log_tag.dart';

LoggingService.instance.debug('Message', tag: LogTag.rust);
LoggingService.instance.info('User action', tag: LogTag.ui);
```

**Available tags**: rust, provider, wallet, sync, ui, navigation, auth, notifications, rewards, node, mempool, blockchain, performance, etc.

#### 2. Structured Context
Add metadata to logs for better debugging:

```dart
LoggingService.instance.info('Transaction sent',
  tag: LogTag.wallet,
  context: {
    'amount': 100,
    'recipient': address,
    'txId': txId,
  }
);
```

**Output**: `ℹ️  [WALLET] Transaction sent {amount: 100, recipient: ut1..., txId: abc123}`

#### 3. Performance Timing
Measure operation duration automatically:

```dart
final timer = LoggingService.instance.startTimer('rpc_call', tag: LogTag.rust);
final result = await rpc.getStatus();
timer.stop(context: {'peers': result.peers.length});
```

**Auto log levels**:
- < 500ms → DEBUG
- 500ms - 1s → INFO
- > 1s → WARNING (marked as SLOW)

#### 4. Log Level Control

**Per-Tag Levels** (edit `logger.dart`):
```dart
static final Map<LogTag, Level> _tagLevels = {
  LogTag.rust: Level.debug,      // Show all RUST logs
  LogTag.provider: Level.warning, // Only warnings+ for providers
};
```

**Environment-Based**:
- **Debug mode**: All logs shown (unless VERBOSE_LOGGING=false)
- **Release mode**: Only warnings and errors
- **VERBOSE_LOGGING flag**: Control debug/trace logs

Run with verbose logging:
```bash
flutter run --dart-define=VERBOSE_LOGGING=true
```

#### 5. Custom Printer

**Debug mode format**:
```
14:32:45.123 🐛 [RUST] getStatus called
14:32:45.345 ℹ️  [WALLET] Transaction sent {amount: 100}
14:32:45.567 ⚠️  [RUST] rpc_call took 1234ms (SLOW) {duration_ms: 1234}
```

**Release mode format** (no emojis):
```
14:32:45.123 [DEBUG] [RUST] getStatus called
14:32:45.345 [INFO] [WALLET] Transaction sent {amount: 100}
```

### Usage Examples

#### Basic Logging
```dart
// Simple message
LoggingService.instance.debug('Operation started', tag: LogTag.wallet);

// With context
LoggingService.instance.info('Sync progress',
  tag: LogTag.sync,
  context: {'height': 1234, 'progress': 0.75}
);
```

#### Error Logging
```dart
try {
  await operation();
} catch (e, st) {
  LoggingService.instance.error(
    'Operation failed',
    tag: LogTag.wallet,
    error: e,
    stackTrace: st,
    context: {'userId': user.id},
  );
}
```

#### Performance Tracking
```dart
Future<void> fetchData() async {
  final timer = LoggingService.instance.startTimer('fetchData', tag: LogTag.network);

  try {
    final data = await api.fetch();
    timer.stop(context: {'items': data.length});
  } catch (e) {
    timer.stop(context: {'error': e.toString()});
    rethrow;
  }
}
```

### Backward Compatibility

Old string-based tags still work:
```dart
// Still works
LoggingService.instance.debug('Message', tag: 'RUST');

// New way (recommended)
LoggingService.instance.debug('Message', tag: LogTag.rust);
```

### Best Practices

1. **Use LogTag enum** for autocomplete and type safety
2. **Add context** to important logs (errors, RPC calls)
3. **Use timers** for performance-critical operations (> 100ms)
4. **Appropriate levels**:
   - `trace`: Very verbose, rarely used
   - `debug`: Development debugging
   - `info`: Important state changes
   - `warn`: Recoverable issues
   - `error`: Failures requiring attention

5. **Structured context** over string interpolation:
   ```dart
   // ❌ Bad
   logger.info('User ${user.id} logged in at ${DateTime.now()}', tag: 'AUTH');

   // ✅ Good
   logger.info('User logged in', tag: LogTag.auth, context: {
     'userId': user.id,
     'timestamp': DateTime.now().toIso8601String(),
   });
   ```

### Configuration

Edit `lib/core/utils/logger.dart` to configure per-tag log levels:

```dart
static final Map<LogTag, Level> _tagLevels = {
  LogTag.rust: Level.debug,       // Always show RUST debug logs
  LogTag.provider: Level.warning, // Only show provider warnings+
  LogTag.sync: Level.info,        // Show sync info+
};
```

## Troubleshooting

### Common Issues

#### Provider Returns Null

**Problem**: Provider returns null when data is expected.

**Solutions**:
1. Check if backend is running: `RustBackendService.instance.isRunning`
2. Verify account exists: `hasAnyAccountProvider`
3. Check logs for RPC errors
4. Ensure `startForActiveAccount()` was called

```dart
// Debug code
debugPrint('Backend running: ${RustBackendService.instance.isRunning}');
final hasAccount = await ref.read(hasAnyAccountProvider.future);
debugPrint('Has account: $hasAccount');
```

#### UI Not Updating

**Problem**: UI doesn't rebuild when data changes.

**Solutions**:
1. Use `ref.watch()` not `ref.read()` in build method
2. Check if using ConsumerWidget or Consumer
3. Verify provider is actually changing (add logging)

```dart
// ❌ Bad - won't rebuild
final data = ref.read(provider);

// ✅ Good - rebuilds on change
final data = ref.watch(provider);
```

#### Circular Dependency Error

**Problem**: "Circular dependency detected" error.

**Solution**: Providers are depending on each other in a loop.

```dart
// ❌ Bad - circular dependency
final providerA = Provider((ref) {
  final b = ref.watch(providerB);
  return b + 1;
});

final providerB = Provider((ref) {
  final a = ref.watch(providerA);
  return a + 1;
});

// ✅ Good - linear dependency
final baseProvider = Provider((ref) => 1);

final providerA = Provider((ref) {
  final base = ref.watch(baseProvider);
  return base + 1;
});

final providerB = Provider((ref) {
  final a = ref.watch(providerA);
  return a + 1;
});
```

#### Backend Not Starting

**Problem**: Backend doesn't start after account creation.

**Solutions**:
1. Verify `backendLifecycleProvider` is watched in main app
2. Check `hasAnyAccountProvider` invalidates after account creation
3. Verify account was saved to storage
4. Check Sentry/logs for startup errors

```dart
// Ensure this is in main app
ref.watch(backendLifecycleProvider);
```

#### Stale Data

**Problem**: Data is outdated and not refreshing.

**Solutions**:
1. Call `.refresh()` on provider
2. Implement polling with Timer
3. Invalidate provider: `ref.invalidate(provider)`

```dart
// Force refresh
await ref.read(nodeRawStatusProvider.notifier).refresh();

// Or invalidate to reload
ref.invalidate(nodeRawStatusProvider);
```

### Debugging Tips

#### Enable Verbose Logging
```bash
flutter run --dart-define=VERBOSE_LOGGING=true
```

#### Check Provider State
```dart
// Log current state
final state = ref.read(provider);
debugPrint('Provider state: $state');
```

#### Monitor RPC Calls
All RPC calls are logged to Sentry. Check:
- `tag: 'RUST'` for RustBackendService logs
- `category: 'rpc'` for RPC-specific breadcrumbs

#### Use Riverpod DevTools
```bash
flutter run --dart-define=ENABLE_RIVERPOD_DEVTOOLS=true
```

Then use Flutter DevTools to inspect provider state.

---

## Additional Resources

### Related Documentation
- [Architecture Overview](./ARCHITECTURE.md) - Overall app architecture
- [Contributing Guide](./CONTRIBUTING.md) - Development guidelines

### External References
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Rust Bridge](https://cjycode.com/flutter_rust_bridge/)
- [Sentry Flutter SDK](https://docs.sentry.io/platforms/flutter/)

### Code Locations
- **Providers**: `lib/features/*/presentation/controllers/`, `lib/core/providers/`
- **RustBackendService**: `lib/features/node/data/repositories/rust_backend_service.dart`
- **Repositories**: `lib/features/*/data/repositories/`
- **Domain Entities**: `lib/features/*/domain/entities/`

---

**Questions or Issues?**
See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to report issues or contribute improvements.
