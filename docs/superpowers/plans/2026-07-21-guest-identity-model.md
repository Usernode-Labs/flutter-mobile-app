# Guest & Per-Identity Data Model — Implementation Plan

> REQUIRED SUB-SKILL: executing-plans. Steps use `- [ ]`.

**Goal:** Guest = identity-free (routes to Dapps, node non-producing); app data
isolated per on-chain identity via hashed pref buckets.

**Tech:** Riverpod, go_router, shared_preferences, `crypto` (sha256), existing
`NetworkPrefs` + `AppConfig.viewOnly`.

## Global constraints
- Bucket = first 16 hex of `sha256(address)`; `'guest'` when no active on-chain
  account **or** when `authStatus == guest`.
- No migration — buckets start fresh.
- Identity-defining keys (`accounts:index`, `accounts:activeId`) and globals
  (`network:type`, `app:theme_mode`) are NEVER bucketed.
- Each phase ends green: `flutter analyze` + `flutter test`.

---

## Phase 1 — Guest routes to Dapps  (visible, low-risk)

**Files:** `lib/core/config/app_router.dart` (redirect guard).
**Test:** extend `test/features/auth/auth_redirect_test.dart`.

- [ ] In the redirect guard, add a guest clause **before** the account/onboarding
  logic: when `authStatus == guest`, if the route isn't already under the app
  shell, redirect to `AppRoutes.dapps`; never send a guest to `/onboarding`.
- [ ] Guest still allowed on public/app-shell routes; account-gated screens keep
  their existing "sign in to view" gate.
- [ ] Test: `authStatus guest + splash → dapps`; `guest + /onboarding → dapps`.

---

## Phase 2 — Guest node is non-producing

**Files:** `lib/core/bootstrap/app_bootstrap.dart` (`blockProductionActive`),
`lib/core/providers/providers.dart` (expose a `blockProductionAllowed` gate),
possibly `slot_production_repository` / `epoch_slot_scheduler_service`.

- [ ] Add `bool guestSessionActive` signal (read the persisted guest flag /
  `authStatusProvider`) available to the bootstrap + production paths.
- [ ] Gate block production: producing is allowed only when NOT a guest session
  (and an active on-chain account exists). Node `init`/`start`/sync unchanged.
- [ ] Node view renders "observing / not producing" for guests (reuse view-only
  copy if present).
- [ ] Fail-safe default: unknown/guest → non-producing.

---

## Phase 3 — Per-identity pref bucket (foundation)

**Files:** `lib/core/utils/network_prefs.dart`.
**Test:** `test/core/utils/network_prefs_account_test.dart`.

- [ ] Add to `NetworkPrefs`:
  ```dart
  static String _activeBucket = 'guest';
  static void setActiveBucket(String? address, {required bool guest}) {
    _activeBucket = (guest || address == null || address.isEmpty)
        ? 'guest'
        : sha256.convert(utf8.encode(address)).toString().substring(0, 16);
  }
  static String get activeBucket => _activeBucket;
  static String prefixAccountKey(String key) =>
      _globalKeys.contains(key) ? key : '$currentNetwork:acct:$_activeBucket:$key';
  ```
- [ ] Tests: bucket = 16-hex of sha256(address); guest/null → `'guest'`;
  `prefixAccountKey` shape; globals pass through.

---

## Phase 4 — Wire bucket updates on identity change

**Files:** `lib/core/bootstrap/app_bootstrap.dart` (resolve active address at
start), `lib/core/providers/accounts_provider.dart` (`setActiveId` /
`importFromSecretKey`), `lib/features/auth/providers/auth_providers.dart`
(`continueAsGuest`, `completeLogin`, `logout`).

- [ ] On boot: resolve active on-chain account address; call
  `NetworkPrefs.setActiveBucket(address, guest: <guestFlag>)` BEFORE any
  account-scoped pref read.
- [ ] `AccountsRepository.setActiveId`: after setting active, resolve the new
  account's address and update the bucket (guest:false).
- [ ] `continueAsGuest()`: `setActiveBucket(null, guest: true)`.
- [ ] `completeLogin()`: recompute bucket from the active on-chain account
  (guest:false; may be `'guest'` if no on-chain account yet).
- [ ] `logout()`: recompute from active on-chain account (guest:false).

---

## Phase 5 — Reclassify account-scoped keys onto `prefixAccountKey`

Move these call sites from `prefixKey` → `prefixAccountKey` (account-scoped
state). Keep `accounts_provider` (index/activeId) on `prefixKeyWith` (network).

- [ ] `providers.dart` — `onboarding:completed`
- [ ] `leaderboard_participant_provider.dart` — `participantId`
- [ ] `leaderboard_bootstrap.dart` — season/event context
- [ ] `produced_blocks_provider.dart` — epochs/metadata/results/slot-time
- [ ] `challenge_point_tracker.dart` — `challenge_pts`
- [ ] `epoch_slot_scheduler_service.dart` — current epoch / scheduled / last-check
- [ ] `slot_production_repository.dart` — records / stats
- [ ] `slot_outcome_buffer_repository.dart` / `slot_outcome_drain_service.dart`
- [ ] `token_allocation_provider.dart` — allocation pref
- [ ] `recipient_history_provider.dart` — recipient history
- [ ] `pending_transaction_service.dart` — pending tx
- [ ] `zkpassport_repositories.dart` — pending/registration/settings/session
- [ ] Full `flutter test` + `flutter analyze` green.

Each phase committed separately.
