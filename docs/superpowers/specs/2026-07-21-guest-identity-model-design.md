# Guest & Per-Identity Data Model — Design

**Date:** 2026-07-21
**Status:** Proposed (pending review)

## Goal

Make "Continue as guest" a genuinely identity-free mode, and isolate app data
per on-chain identity so switching accounts (or entering guest) never mixes
data.

Three parts:
1. **Per-identity SharedPreferences isolation** — account-scoped keys are
   bucketed by a hash of the on-chain address; **guest** gets a reserved bucket.
2. **Guests route to the Dapps tab** (never into node onboarding).
3. **A guest's node runs & syncs but does not produce blocks.**

Decisions (confirmed): bucket = `hash(address)`; non-producing = node runs +
syncs with production disabled; **no migration** — buckets start fresh.

## Part 1 — Per-identity pref isolation

Today `NetworkPrefs.prefixKey(k)` → `"<network>:<k>"` for full network
isolation, with a small `_globalKeys` allowlist left unprefixed.

Add an **account dimension** for account-scoped keys:

```
account-scoped key  →  "<network>:acct:<bucket>:<k>"
bucket              =  first 16 hex of sha256(address)   // active on-chain account
                    =  "guest"                            // no active on-chain account
```

- New API: `NetworkPrefs.prefixAccountKey(k)` (or an `IdentityPrefs` wrapper).
  `prefixKey` stays for network-scoped/global keys.
- **Three key classes:**
  - *Global* (unchanged): `network:type`, `app:theme_mode`.
  - *Network-scoped, identity-defining* (unchanged, must resolve the bucket
    without knowing it): the account registry — active account id, account
    index/list in `AccountsRepository`.
  - *Account-scoped* (newly bucketed): the identity's state — onboarding-complete
    flag, season/event context, participant id, challenge/point caches, produced
    blocks, profile & token-allocation prefs, recipient history, terms cache.
    (The exact inventory is the ~10 `NetworkPrefs.prefixKey` call sites; the plan
    enumerates each as network- vs account-scoped.)
- **Bucket resolution:** the active bucket is derived from the active on-chain
  account's address (or `guest`). It changes on login / register / logout /
  continue-as-guest; providers that read account-scoped prefs re-read on change.
- **No migration:** existing `"<network>:<k>"` data is not read under the new
  scheme. On upgrade, account-scoped local state (onboarding flag, caches) starts
  empty — a one-time reset, accepted.

## Part 2 — Guest routes to Dapps

In the router redirect guard, when `authStatus == guest`:
- route to `AppRoutes.dapps` instead of onboarding/home;
- never send a guest into node onboarding.

Account-gated tabs (profile / rewards / challenges) keep the existing
"sign in to view" gate for guests.

## Part 3 — Guest node is non-producing

- The node still `init`s, starts, and syncs in guest mode (unchanged bootstrap
  path).
- **Block production is gated OFF for guests** at the existing
  `blockProductionActive` decision (`app_bootstrap.dart`) and the slot-production
  path (`slot_production_repository`, `epoch_slot_scheduler_service`), reusing/
  extending the `AppConfig.viewOnly` mechanism so a guest is effectively
  view-only for on-chain writes.
- Rationale: a returning operator who logs out and continues as guest still has
  keys on device; production must not run under a guest session.
- Node view renders as observing / non-producing.

## Risks

- **Blast radius:** every account-scoped pref call site must be reclassified;
  miscategorizing an identity-defining key (e.g. the active-account pointer)
  would break account resolution. The plan classifies each explicitly.
- **Fresh-start reset:** existing users lose local account-scoped state
  (onboarding flag, caches) once on upgrade. Server-held data (rewards, terms
  consent) is unaffected.
- **Production gating must be fail-safe:** default to non-producing unless the
  session is clearly a non-guest with an active on-chain account.

## Out of scope

- Multi-account switching UI.
- Migrating existing local data into buckets (explicitly deferred).
- Changing the on-chain account/key storage itself (keys stay in secure storage
  as today; only prefs get bucketed).

## Delivery

Phased, each independently green:
1. `prefixAccountKey` + bucket resolution (+ tests), no call sites moved yet.
2. Reclassify account-scoped pref call sites onto the bucketed API.
3. Guest → Dapps routing.
4. Guest node non-producing (production gating).
