# Navigation & State Management Documentation

> Comprehensive guide to the app's navigation flow, routing architecture, and state management using GoRouter and Riverpod.

---

## Table of Contents

- [Overview](#overview)
- [Navigation Flow](#navigation-flow)
  - [ASCII Diagram](#ascii-diagram)
  - [Mermaid Diagram](#mermaid-diagram)
- [State Management Architecture](#state-management-architecture)
- [Route Protection](#route-protection)
- [Quick Reference](#quick-reference)

---

## Overview

This Flutter application uses:
- **GoRouter** for declarative routing with deep linking support
- **Riverpod** for reactive state management
- **ShellRoute** for persistent bottom navigation
- **Automatic route protection** based on account existence

The navigation is driven by the `hasAnyAccountProvider` which determines whether users see onboarding or the main app.

---

## Navigation Flow

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          APP NAVIGATION FLOW                         │
└─────────────────────────────────────────────────────────────────────┘

                              ┌──────────┐
                              │  SPLASH  │
                              │ /splash  │
                              └────┬─────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
            No Account                      Has Account
                    │                             │
                    ▼                             ▼
          ┌────────────────┐           ┌────────────────┐
          │  ONBOARDING    │           │   MAIN APP     │
          │  /onboarding   │           │   /main/home   │
          └───┬────────────┘           └───┬────────────┘
              │                            │
      ┌───────┴───────┐                    │
      │               │                    │
      ▼               ▼                    │
┌──────────┐  ┌──────────────┐           │
│ CREATE   │  │   IMPORT     │           │
│ ACCOUNT  │  │ SEED PHRASE  │           │
│ /create- │  │ /import-     │           │
│ new-     │  │ seed-phrase  │           │
│ account  │  └──────┬───────┘           │
└────┬─────┘         │                    │
     │               │                    │
     └───────┬───────┘                    │
             │                            │
             ▼                            │
    ┌─────────────────┐                  │
    │   IDENTITY      │◄─────────────────┘
    │  VERIFICATION   │  (Optional - can access
    │  /identity-     │   from home screen)
    │  verification   │
    └─────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                   MAIN APP STRUCTURE (Shell Route)                   │
└─────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │    MAIN SHELL    │
                        │  Bottom Nav Bar  │
                        └────────┬─────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │            │           │           │            │
        ▼            ▼           ▼           ▼            ▼
    ┌──────┐   ┌────────┐  ┌────────┐  ┌────────┐  ┌─────────┐
    │ HOME │   │  NODE  │  │ DAPPS  │  │ WALLET │  │ PROFILE │
    │/main/│   │ /main/ │  │ /main/ │  │ /main/ │  │ /main/  │
    │ home │   │  node  │  │ dapps  │  │ wallet │  │ profile │
    └──┬───┘   └───┬────┘  └────────┘  └────────┘  └─────────┘
       │           │                      (optional)  (optional)
       │           │
       │           └──────┬─────────────────┬──────────────┐
       │                  │                 │              │
       │                  ▼                 ▼              ▼
       │          ┌────────────┐   ┌──────────────┐  ┌──────────┐
       │          │ WON SLOTS  │   │   PRODUCED   │  │ MEMPOOL  │
       │          │   /main/   │   │    BLOCKS    │  │  /main/  │
       │          │   node/    │   │    /main/    │  │  node/   │
       │          │ won-slots  │   │    node/     │  │ mempool  │
       │          └────────────┘   │  produced-   │  └──────────┘
       │                           │   blocks     │
       │                           └──────────────┘
       │
       └──────────┐
                  │ (Quick Actions)
          ┌───────┴────────┬──────────┬──────────┐
          ▼                ▼          ▼          ▼
     ┌────────┐      ┌─────────┐ ┌────────┐ ┌─────────┐
     │  SEND  │      │ RECEIVE │ │ REWARDS│ │ SETTINGS│
     │ /send  │      │/receive │ │/rewards│ │/settings│
     └────────┘      └─────────┘ └────────┘ └────┬────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │NOTIFICATIONS │
                                          │/notifications│
                                          └──────────────┘
```

### Mermaid Diagram

```mermaid
graph TD
    Start([App Start]) --> Splash[Splash Screen<br/>/splash]

    Splash -->|No Account| Onboarding[Onboarding<br/>/onboarding]
    Splash -->|Has Account| Home[Home Screen<br/>/main/home]

    Onboarding --> CreateAccount[Create New Account<br/>/create-new-account]
    Onboarding --> ImportSeed[Import Seed Phrase<br/>/import-seed-phrase]

    CreateAccount --> Identity[Identity Verification<br/>/identity-verification]
    ImportSeed --> Identity

    Identity -->|Complete| Home

    Home -->|From Drawer/Actions| Identity

    subgraph MainApp["Main App (Shell Route with Bottom Navigation)"]
        Home
        Node[Node Status<br/>/main/node]
        DApps[DApps<br/>/main/dapps]
        Wallet[Wallet<br/>/main/wallet<br/>(optional)]
        Profile[Profile<br/>/main/profile<br/>(optional)]
    end

    Node --> WonSlots[Won Slots<br/>/main/node/won-slots]
    Node --> ProducedBlocks[Produced Blocks<br/>/main/node/produced-blocks]
    Node --> Mempool[Mempool Details<br/>/main/node/mempool]

    Home --> Send[Send<br/>/send]
    Home --> Receive[Receive<br/>/receive]
    Home --> Rewards[Rewards Breakdown<br/>/rewards]

    Home --> Settings[Settings<br/>/settings]
    Settings --> Notifications[Notifications<br/>/notifications]

    style Start fill:#e1f5ff
    style Splash fill:#fff3cd
    style Onboarding fill:#f8d7da
    style Home fill:#d4edda
    style MainApp fill:#d1ecf1
    style Identity fill:#e2e3e5
```

---

## Navigation Flow with State Management

### ASCII Diagram with States

```
╔══════════════════════════════════════════════════════════════════════╗
║                  APP NAVIGATION FLOW WITH STATES                      ║
╚══════════════════════════════════════════════════════════════════════╝

                           ┌──────────────┐
                           │   APP START  │
                           │              │
                           │ Global State:│
                           │ - ThemeMode  │
                           └──────┬───────┘
                                  │
                           ┌──────▼───────┐
                           │ SPLASH       │
                           │ /splash      │
                           │              │
                           │ State:       │
                           │ - Animation  │
                           │ - Loading    │
                           └──────┬───────┘
                                  │
                    Check: hasAnyAccountProvider
                           (FutureProvider<bool>)
                                  │
              ┌───────────────────┴────────────────────┐
              │                                        │
     hasAny = false                             hasAny = true
              │                                        │
              ▼                                        ▼
    ┌─────────────────┐                    ┌──────────────────┐
    │  ONBOARDING     │                    │   MAIN APP       │
    │  /onboarding    │                    │   /main/home     │
    │                 │                    │                  │
    │  State:         │                    │  State:          │
    │  - UI Selection │                    │  - AsyncValue    │
    └────┬────────────┘                    │  - Assets[]      │
         │                                 │  - EpochRewards  │
         │ User Choice                     │  - NodeStatus    │
    ┌────┴────┐                           └────────┬─────────┘
    │         │                                     │
    ▼         ▼                            (Continues Below)
┌────────┐  ┌──────────────┐
│CREATE  │  │   IMPORT     │
│ACCOUNT │  │ SEED PHRASE  │
│/create-│  │ /import-seed-│
│new-    │  │ phrase       │
│account │  │              │
│        │  │ State:       │
│State:  │  │ - Input Text │
│- Mnemo │  │ - Validation │
│  nic   │  │ - Processing │
│- Ack   │  └──────┬───────┘
│  Saved │         │
│- Proce │         │
│  ssing │         │
└────┬───┘         │
     │             │
     └──────┬──────┘
            │
    AccountsRepository
    .importFromMnemonic()
            │
            │ Success → Account Created
            │
            ▼
   ┌────────────────────┐
   │ IDENTITY           │
   │ VERIFICATION       │
   │ /identity-         │
   │ verification       │
   │                    │
   │ State:             │
   │ - VerificationData │
   │ - Processing       │
   │ - accountId        │
   └─────────┬──────────┘
             │
   ┌─────────┴─────────┐
   │                   │
   Skip            Complete
   │                   │
   └────────┬──────────┘
            │
   Invalidate hasAnyAccountProvider
   Backend Lifecycle: Start Backend
            │
            ▼
   ┌────────────────┐
   │  MAIN APP      │
   │  /main/home    │
   └────────────────┘


╔══════════════════════════════════════════════════════════════════════╗
║                   MAIN APP STATE STRUCTURE                            ║
╚══════════════════════════════════════════════════════════════════════╝

┌────────────────────────────────────────────────────────────────────┐
│                      GLOBAL STATE LAYER                             │
├────────────────────────────────────────────────────────────────────┤
│ • hasAnyAccountProvider: AsyncValue<bool>                          │
│ • themeModeProvider: StateNotifier<ThemeMode>                      │
│ • backendLifecycleProvider: void (side effects only)               │
│ • notificationsProvider: StateNotifier<List<AppNotification>>     │
└────────────────────────────────────────────────────────────────────┘

                                  │
                    ┌─────────────┴─────────────┐
                    │     SHELL ROUTE           │
                    │   (Bottom Navigation)     │
                    └─────────────┬─────────────┘
                                  │
        ┌─────────────────────────┼──────────────────────────┐
        │             │            │            │             │
        ▼             ▼            ▼            ▼             ▼

┌──────────────┐ ┌──────────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│   HOME       │ │   NODE       │ │  DAPPS   │ │  WALLET  │ │ PROFILE  │
│  /main/home  │ │  /main/node  │ │ /main/   │ │ /main/   │ │ /main/   │
│              │ │              │ │  dapps   │ │  wallet  │ │  profile │
│ States:      │ │ States:      │ │          │ │          │ │          │
│ ┌──────────┐ │ │ ┌──────────┐ │ │ States:  │ │ States:  │ │ States:  │
│ │EpochRewar││ │ │NodeStatus│ │ │ - DApps  │ │ - Assets │ │ - Account│
│ │  dsUi    ││ │ │ (Async)  │ │ │   List   │ │   (Async)│ │   Info   │
│ │ • snapshot││ │ │ • local  │ │ │          │ │ - UTXOs  │ │ - Balan  │
│ │ • isCached││ │ │   Height │ │ │          │ │   (Async)│ │   ces    │
│ │ • isStale ││ │ │ • network│ │ │          │ │ - Txns   │ │          │
│ └──────────┘ │ │ │   Height │ │ │          │ │   (Async)│ │          │
│              │ │ │ • sync%  │ │ │          │ └──────────┘ │          │
│ ┌──────────┐ │ │ │ • peers  │ │ │          │              │          │
│ │Activity  │ │ │ └──────────┘ │ │          │              │          │
│ │  Items   │ │ │              │ │          │              │          │
│ └──────────┘ │ │ ┌──────────┐ │ │          │              │          │
│              │ │ │SyncStatus│ │ │          │              │          │
│ ┌──────────┐ │ │ │ (Async)  │ │ │          │              │          │
│ │Won Slots │ │ │ │ • isSyncd││ │          │              │          │
│ │ (Async)  │ │ │ │ • progress│ │          │              │          │
│ └──────────┘ │ │ └──────────┘ │ │          │              │          │
└──────────────┘ │              │ │          │              │          │
                 │ ┌──────────┐ │ │          │              │          │
                 │ │Mempool   │ │ │          │              │          │
                 │ │  (Async) │ │ │          │              │          │
                 │ │ • count  │ │ │          │              │          │
                 │ │ • orphans│ │ │          │              │          │
                 │ │ • size   │ │ │          │              │          │
                 │ └──────────┘ │ │          │              │          │
                 │              │ │          │              │          │
                 │ ┌──────────┐ │ │          │              │          │
                 │ │Blockchain│ │ │          │              │          │
                 │ │  (Async) │ │ │          │              │          │
                 │ │ • blocks │ │ │          │              │          │
                 │ └──────────┘ │ │          │              │          │
                 └──────┬───────┘ └──────────┘              └──────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
 ┌────────────┐ ┌─────────────┐ ┌────────────┐
 │ WON SLOTS  │ │  PRODUCED   │ │  MEMPOOL   │
 │  /main/    │ │   BLOCKS    │ │  /main/    │
 │  node/     │ │   /main/    │ │  node/     │
 │  won-slots │ │   node/     │ │  mempool   │
 │            │ │   produced- │ │            │
 │ States:    │ │   blocks    │ │ States:    │
 │ - Filter   │ │             │ │ - Txns[]   │
 │ - Slots[]  │ │ States:     │ │ - Filter   │
 │   (Async)  │ │ - Blocks[]  │ │ - Detail   │
 └────────────┘ │   (Async)   │ └────────────┘
                └─────────────┘


╔══════════════════════════════════════════════════════════════════════╗
║                    OVERLAY ROUTES WITH STATES                         ║
╚══════════════════════════════════════════════════════════════════════╝

From Home (Quick Actions):

    ┌────────────┐      ┌───────────┐      ┌────────────┐
    │   SEND     │      │  RECEIVE  │      │  REWARDS   │
    │   /send    │      │ /receive  │      │  /rewards  │
    │            │      │           │      │            │
    │ States:    │      │ States:   │      │ States:    │
    │ - Amount   │      │ - Address │      │ - Epoch    │
    │ - Address  │      │ - QR Code │      │ - Earned   │
    │ - Validatn │      │ - Display │      │ - Expected │
    │ - Procesng │      │           │      │ - Produced │
    └────────────┘      └───────────┘      │ - Wins     │
                                           │ - WonSlots │
                                           └────────────┘

From Drawer/Settings:

    ┌─────────────┐      ┌──────────────┐
    │  SETTINGS   │      │NOTIFICATIONS │
    │  /settings  │      │/notifications│
    │             │      │              │
    │ States:     │      │ States:      │
    │ - ThemeMode │      │ - Notifs[]   │
    │ - Prefs     │      │ - Unread     │
    └─────────────┘      │   Count      │
                         └──────────────┘


╔══════════════════════════════════════════════════════════════════════╗
║                    STATE LIFECYCLE & ASYNC FLOW                       ║
╚══════════════════════════════════════════════════════════════════════╝

All AsyncNotifier/FutureProvider states follow this pattern:

    ┌─────────────────────────────────────────────────────┐
    │         AsyncValue<T> State Machine                 │
    ├─────────────────────────────────────────────────────┤
    │                                                     │
    │  Initial → AsyncLoading → AsyncData<T>             │
    │                ↓              ↓                     │
    │                └──→ AsyncError                     │
    │                        ↓                            │
    │                   (retry/refresh)                   │
    │                        ↓                            │
    │                  AsyncLoading → AsyncData/Error    │
    │                                                     │
    └─────────────────────────────────────────────────────┘

Example State Transitions:

1. WALLET ASSETS:
   Initial → Loading → Data([AssetSummary])

   AssetSummary:
   - tokenId: String
   - tokenName: String
   - tokenSymbol: String
   - totalBalance: BigInt
   - usdValue: double
   - change24h: double

2. NODE STATUS:
   Initial → Loading → Data(NodeStatus)

   NodeStatus:
   - localBestHeight: int
   - networkBestHeight: int
   - connectedPeers: int
   - totalPeers: int
   Auto-refreshes every 2 minutes

3. EPOCH REWARDS:
   Initial → Loading → Data(EpochRewardsUiState)

   EpochRewardsUiState:
   - snapshot: EpochRewardsSnapshot?
     - epoch: int
     - earnedSoFar: String
     - expectedTotal: String
     - producedInEpoch: int
     - winsInEpoch: int
     - rewardPerBlock: String
     - wonSlots: List
   - isCached: bool
   - isStale: bool

   Side Effect: Triggers notification when rewards increase
```

### Mermaid State Diagram

```mermaid
stateDiagram-v2
    [*] --> AppStart

    state AppStart {
        [*] --> InitGlobalState
        InitGlobalState --> ThemeMode
        InitGlobalState --> BackendService
    }

    AppStart --> Splash

    state Splash {
        [*] --> AnimationState
        AnimationState --> CheckingAccount
    }

    state "hasAnyAccountProvider" as CheckAccount
    Splash --> CheckAccount

    CheckAccount --> Onboarding: hasAny = false
    CheckAccount --> MainApp: hasAny = true

    state Onboarding {
        [*] --> SelectionUI
        SelectionUI --> CreateAccount: User selects "Create"
        SelectionUI --> ImportSeed: User selects "Import"

        state CreateAccount {
            [*] --> GenerateMnemonic
            GenerateMnemonic --> DisplayMnemonic
            DisplayMnemonic --> AcknowledgeSaved
            AcknowledgeSaved --> Processing: User confirms
        }

        state ImportSeed {
            [*] --> InputText
            InputText --> Validation
            Validation --> Processing: Valid
            Validation --> InputText: Invalid
        }

        CreateAccount --> AccountCreated
        ImportSeed --> AccountCreated

        state AccountCreated {
            [*] --> ImportToRepo
            ImportToRepo --> StartBackend
            StartBackend --> InvalidateProvider
        }
    }

    Onboarding --> IdentityVerification

    state IdentityVerification {
        [*] --> InputData
        InputData --> ProcessingVerification
        ProcessingVerification --> Complete
        InputData --> Skip
    }

    IdentityVerification --> MainApp: Skip or Complete

    state MainApp {
        [*] --> ShellRoute

        state ShellRoute {
            [*] --> Home

            state Home {
                [*] --> LoadStates
                LoadStates --> EpochRewardsState
                LoadStates --> ActivityState
                LoadStates --> WonSlotsState

                state EpochRewardsState {
                    [*] --> AsyncLoading
                    AsyncLoading --> AsyncData
                    AsyncLoading --> AsyncError
                    AsyncData --> CheckRewardIncrease
                    CheckRewardIncrease --> TriggerNotification: Increased
                    AsyncError --> AsyncLoading: Refresh
                }
            }

            state Node {
                [*] --> LoadNodeData
                LoadNodeData --> NodeStatusState
                LoadNodeData --> SyncStatusState
                LoadNodeData --> MempoolState
                LoadNodeData --> BlockchainState

                state NodeStatusState {
                    [*] --> AsyncLoading
                    AsyncLoading --> AsyncData
                    AsyncData --> AutoRefresh: Every 2 min
                    AutoRefresh --> AsyncLoading
                }

                Node --> WonSlots
                Node --> ProducedBlocks
                Node --> MempoolDetails
            }

            state Wallet {
                [*] --> LoadWalletData
                LoadWalletData --> AssetsState
                LoadWalletData --> UTXOsState
                LoadWalletData --> TransactionsState

                state AssetsState {
                    [*] --> AsyncLoading
                    AsyncLoading --> AggregateByToken
                    AggregateByToken --> AsyncData
                }
            }

            state DApps {
                [*] --> DAppsList
            }

            state Profile {
                [*] --> AccountInfo
                AccountInfo --> Balances
            }
        }
    }

    Home --> Send: Quick Action
    Home --> Receive: Quick Action
    Home --> Rewards: Quick Action
    Home --> Settings: Drawer

    state Send {
        [*] --> AmountInput
        AmountInput --> AddressInput
        AddressInput --> Validation
        Validation --> Processing
        Processing --> Success
        Processing --> Error
    }

    state Receive {
        [*] --> GenerateAddress
        GenerateAddress --> DisplayQR
    }

    state Rewards {
        [*] --> LoadRewardsData
        LoadRewardsData --> DisplayBreakdown
        DisplayBreakdown --> ShowWonSlots
    }

    Settings --> Notifications

    state "Global State Layer" as GlobalState {
        hasAnyAccount: AsyncValue_bool
        themeMode: StateNotifier_ThemeMode
        backendLifecycle: SideEffects
        notifications: StateNotifier_List
    }

    note right of GlobalState
        All providers use Riverpod
        AsyncValue states: Loading | Data | Error
        Auto-refresh on dependency changes
    end note

    note right of MainApp
        Shell Route maintains persistent
        bottom navigation state across tabs
    end note
```

---

## State Management Architecture

### Key State Providers

#### 1. Global State

**Location:** `lib/core/di/providers.dart`

| Provider | Type | Purpose |
|----------|------|---------|
| `hasAnyAccountProvider` | `FutureProvider<bool>` | Drives routing logic - determines if user sees onboarding or main app |
| `themeModeProvider` | `StateNotifierProvider<ThemeMode>` | Theme persistence with light/dark/system modes |
| `backendLifecycleProvider` | `Provider<void>` | Manages Rust backend start/stop based on account state changes |
| `notificationsProvider` | `StateNotifier<List<AppNotification>>` | Manages in-app notifications |

#### 2. Wallet State

**Location:** `lib/features/wallet/presentation/controllers/`

| Provider | Type | Purpose |
|----------|------|---------|
| `walletAssetsProvider` | `AsyncNotifier<List<AssetSummary>>` | Aggregated token balances by token_id |
| `walletUtxosProvider` | `AsyncNotifier<List<OwnedUtxo>>` | UTXO management |
| `transactionActivityProvider` | `AsyncNotifier<List<Transaction>>` | Recent transaction history |

**AssetSummary Model:**
```dart
class AssetSummary {
  final String tokenId;
  final String tokenName;
  final String tokenSymbol;
  final BigInt totalBalance;
  final double usdValue;
  final double change24h;
}
```

#### 3. Node State

**Location:** `lib/features/node/presentation/controllers/`

| Provider | Type | Purpose | Auto-Refresh |
|----------|------|---------|--------------|
| `nodeStatusProvider` | `AsyncNotifier<NodeStatus?>` | Node sync status, peer info | Every 2 min |
| `syncStatusProvider` | `Provider<SyncStatus>` | Blockchain sync progress | On dependency |
| `mempoolProvider` | `AsyncNotifier<Mempool>` | Mempool transaction data | Manual |
| `blockchainProvider` | `AsyncNotifier<Blockchain>` | Recent blocks | Manual |

**NodeStatus Model:**
```dart
class NodeStatus {
  final int localBestHeight;
  final int networkBestHeight;
  final int connectedPeers;
  final int totalPeers;
}
```

#### 4. Rewards State

**Location:** `lib/features/rewards/presentation/controllers/epoch_rewards_provider.dart`

| Provider | Type | Purpose |
|----------|------|---------|
| `epochRewardsUiProvider` | `AsyncNotifier<EpochRewardsUiState?>` | Epoch rewards tracking with notifications |

**EpochRewardsUiState Model:**
```dart
class EpochRewardsUiState {
  final EpochRewardsSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
}

class EpochRewardsSnapshot {
  final int epoch;
  final String earnedSoFar;
  final String expectedTotal;
  final int producedInEpoch;
  final int winsInEpoch;
  final String rewardPerBlock;
  final List wonSlots;
}
```

**Side Effects:**
- Monitors `earnedSoFar` changes
- Triggers in-app notification when rewards increase
- Calculates reward differential

### State Flow Characteristics

#### AsyncValue State Machine

All async states follow this pattern:

```
Initial → AsyncLoading → AsyncData<T> | AsyncError
                ↓              ↓
                └──→ AsyncError
                        ↓
                   (retry/refresh)
                        ↓
                  AsyncLoading → AsyncData<T> | AsyncError
```

#### Provider Reactivity

- **State invalidation** triggers re-navigation via `GoRouterRefreshStream`
- **Backend lifecycle** automatically managed by account state changes
- **Providers watch dependencies** and auto-refresh on changes
- **Cache management** with staleness detection for offline support

#### Lifecycle Hooks

```dart
// Example from NodeStatusController
@override
Future<NodeStatus?> build() async {
  // Initial fetch
  final status = await repo.getStatus();

  // Auto-refresh setup
  _timer = Timer.periodic(const Duration(minutes: 2), (_) async {
    final newStatus = await repo.getStatus();
    state = AsyncData(newStatus);
  });

  // Cleanup
  ref.onDispose(() => _timer?.cancel());

  return status;
}
```

---

## Route Protection

### Authentication Guard

**Location:** `lib/core/routing/app_router.dart` (lines 159-225)

The router uses a `redirect` guard that checks `hasAnyAccountProvider`:

```dart
redirect: (context, state) {
  final hasAny = ref.read(hasAnyAccountProvider)
    .maybeWhen(data: (v) => v, orElse: () => null);

  final currentLocation = state.matchedLocation;

  // Still loading - allow navigation
  if (hasAny == null) return null;

  // No account exists
  if (!hasAny) {
    if (currentLocation == '/splash') return '/onboarding';
    if (isOnboardingRoute) return null;
    return '/onboarding'; // Redirect to onboarding
  }

  // Account exists
  if (currentLocation == '/splash' || currentLocation == '/onboarding') {
    return '/main/home'; // Redirect to main app
  }

  return null; // Allow navigation
}
```

### Route Classifications

#### Public Routes (No Account Required)
- `/splash` - Splash screen
- `/onboarding` - Account mode selection
- `/create-new-account` - Account creation flow
- `/import-seed-phrase` - Import existing account
- `/identity-verification` - Identity verification (accessible during onboarding)

#### Protected Routes (Account Required)
- All `/main/*` routes require an account
- Automatically redirected to `/onboarding` if no account exists

#### Overlay Routes (Account Required)
- `/send` - Send tokens
- `/receive` - Receive tokens
- `/rewards` - Rewards breakdown
- `/settings` - App settings
- `/notifications` - Notifications center

---

## Quick Reference

### All Routes

| Route | Path | Protected | Notes |
|-------|------|-----------|-------|
| **Authentication** | | | |
| Splash | `/splash` | No | Transient - redirects based on account state |
| Onboarding | `/onboarding` | No | Account mode selection |
| Create Account | `/create-new-account?mnemonic=` | No | Displays mnemonic, creates account |
| Import Seed | `/import-seed-phrase` | No | Import existing account |
| Identity Verification | `/identity-verification?accountId=` | No | Can be accessed post-account for updates |
| **Main App (Shell Route)** | | | |
| Home | `/main/home` | Yes | Default landing page |
| Node Status | `/main/node` | Yes | Node sync and blockchain info |
| DApps | `/main/dapps` | Yes | Decentralized applications |
| Wallet | `/main/wallet` | Yes | Optional - controlled by feature flags |
| Profile | `/main/profile` | Yes | Optional - controlled by feature flags |
| **Node Sub-Routes** | | | |
| Won Slots | `/main/node/won-slots` | Yes | View won slot details |
| Produced Blocks | `/main/node/produced-blocks` | Yes | View produced blocks |
| Mempool Details | `/main/node/mempool` | Yes | View mempool transactions |
| **Overlay Routes** | | | |
| Send | `/send` | Yes | Send tokens |
| Receive | `/receive` | Yes | Receive tokens (address + QR) |
| Rewards | `/rewards` | Yes | Rewards breakdown |
| Settings | `/settings` | Yes | App settings |
| Notifications | `/notifications` | Yes | Notifications center |

### Bottom Navigation Tabs

1. **Home** - `/main/home` - Dashboard with epoch rewards, activity, quick actions
2. **Node** - `/main/node` - Node status, sync progress, blockchain data
3. **DApps** - `/main/dapps` - Decentralized applications
4. **Wallet** - `/main/wallet` - (Optional) Asset management
5. **Profile** - `/main/profile` - (Optional) Account info

### State Provider Locations

| Feature | Provider Location |
|---------|-------------------|
| Global State | `lib/core/di/providers.dart` |
| Wallet State | `lib/features/wallet/presentation/controllers/` |
| Node State | `lib/features/node/presentation/controllers/` |
| Rewards State | `lib/features/rewards/presentation/controllers/` |
| Notifications | `lib/core/providers/notifications_provider.dart` |

### Key Navigation Patterns

#### 1. Account Creation Flow
```
Onboarding → Create/Import → Identity Verification → Home
```

#### 2. Quick Actions from Home
```
Home → Send/Receive/Rewards (overlay routes)
```

#### 3. Node Exploration
```
Node → Won Slots/Produced Blocks/Mempool (sub-routes)
```

#### 4. Settings & Notifications
```
Any Screen (via drawer) → Settings → Notifications
```

---

## Implementation Details

### Router Configuration

**File:** `lib/core/routing/app_router.dart`

- **Router Type:** GoRouter with ShellRoute
- **State Bridge:** `GoRouterRefreshStream` connects Riverpod to GoRouter
- **Initial Location:** `/splash`
- **Refresh Strategy:** Reactive to `hasAnyAccountProvider` changes

### Shell Route Architecture

The main app uses a `ShellRoute` to maintain persistent bottom navigation state:

```dart
ShellRoute(
  builder: (context, state, child) =>
    MainApp(currentLocation: state.matchedLocation, child: child),
  routes: [
    GoRoute(path: '/main/home', ...),
    GoRoute(path: '/main/node', ...),
    GoRoute(path: '/main/dapps', ...),
    // ...
  ],
)
```

Benefits:
- Bottom navigation persists across tab changes
- Efficient state preservation
- Smooth tab transitions

### Backend Lifecycle Integration

The `backendLifecycleProvider` listens to account state changes:

```dart
ref.listen<AsyncValue<bool>>(
  hasAnyAccountProvider,
  (previous, next) async {
    final prevHasAccount = previous?.value ?? false;
    final nextHasAccount = next.value ?? false;

    // Account created: false → true
    if (!prevHasAccount && nextHasAccount) {
      await RustBackendService.instance.startForActiveAccount();
    }

    // Account deleted: true → false
    if (prevHasAccount && !nextHasAccount) {
      await RustBackendService.instance.stopNode();
    }
  },
);
```

This ensures the Rust backend starts/stops automatically based on account existence.

---

## Best Practices

### 1. Navigation
- Use `context.go()` for navigation within the app
- Use `context.push()` for overlay screens that should allow back navigation
- Always use named routes from the router configuration

### 2. State Management
- Use `ref.watch()` in build methods for reactive updates
- Use `ref.read()` in event handlers
- Call `.refresh()` on providers to manually trigger updates
- Handle all `AsyncValue` states (loading, data, error)

### 3. Route Protection
- Don't manually check auth state - let the router guard handle it
- Use query parameters for passing IDs: `?accountId=123`
- Clean up timers and listeners in provider `onDispose`

### 4. Performance
- Use `const` constructors where possible
- Leverage provider auto-dispose for inactive screens
- Implement pagination for large lists
- Cache data with staleness detection for offline support

---

## Troubleshooting

### Common Issues

**Issue:** Navigation not updating after account creation
- **Cause:** Provider not invalidated
- **Solution:** Ensure `ref.invalidate(hasAnyAccountProvider)` is called after account operations

**Issue:** State not updating in UI
- **Cause:** Using `ref.read()` instead of `ref.watch()`
- **Solution:** Use `ref.watch()` in build methods for reactive updates

**Issue:** Back button behavior inconsistent
- **Cause:** Mixing `context.go()` and `context.push()`
- **Solution:** Use `context.go()` for tab navigation, `context.push()` for overlays

**Issue:** Multiple refreshes on screen load
- **Cause:** Multiple providers watching same dependency
- **Solution:** Debounce refresh calls or consolidate provider dependencies

---

## Version History

- **v1.0** - Initial documentation with complete navigation flow and state management architecture
- Generated: 2025-10-16

---

## Related Files

- Router: `lib/core/routing/app_router.dart`
- Global Providers: `lib/core/di/providers.dart`
- Main App Shell: `lib/app/main_app.dart`
- Theme Configuration: `lib/core/theme/theme.dart`
