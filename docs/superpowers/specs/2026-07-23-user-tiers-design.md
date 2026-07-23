# User tiers, api-version gate, More tab

Status: **needs a scope decision before implementation.** Four codex review rounds
surfaced 12 blockers. Eight of them are in one place: making the node run keyless.

## Recommendation: split this in two

**Ship now — stable across all four rounds, zero blockers after rev1:**

- api-version gate (§1)
- `app:user_type` replacing `auth:v3:guest` (§2)
- routing, including the `unknown` early return (§3)
- tabs, More tab, per-tier Challenges content (§4)
- removing the "Onboarding has evolved" dialog (§6)
- dead code (§7)

**Defer — needs a lifecycle change first:**

- keyless node for guest/member (§5)

### Why §5 should not ship with the rest

Node startup was built on one assumption — *an account exists, so start a producing
node*. Every attempt to add a second mode hit a different structural obstacle:

| round | obstacle |
|---|---|
| 1 | bootstrap starts the node before auth is known (`app_bootstrap.dart:343`) |
| 1 | lifecycle provider keys off account transitions only (`providers.dart:46`) |
| 2 | no graceful shutdown; restart can adopt the dying node (`node_service.dart:517,342`) |
| 3 | `/me` is authoritative, so local state cannot decide the mode (`me.dart:59-61`) |
| 3 | 7 independent `startNode()` callers; stopping does not stick |
| 4 | `startNode()` early-returns when already running (`node_service.dart:294`) |
| 4 | enrollment never persists the operator type before starting (`registration_flow.dart:63`) |
| 4 | a second Flutter engine caches prefs independently (`BackgroundAlarmEngine.kt:103`) |

None of these are bugs in the current app — they are all correct for a
single-mode node. They only conflict with adding a mode. The honest fix is a node
lifecycle that supports an explicit mode, set once at construction, with a real
shutdown contract — plausibly a Rust-side change in `usernode`. That is its own piece
of work, not a rider on this one.

Guests and members can ship with **no node running at all** (§5 alternative) if the
tiers are needed sooner; that needs confirming dApps and Challenges work without
local chain data.

---

Design detail follows. Revised through codex round 4.

## 1. api-version in SharedPreferences

New key `app:api_version` (int). Latest = **3**.

**The gate runs at the top of `AppBootstrap.initNonUi`**, before
`_applyBootstrapIdentity` and before `refreshActiveAccountBucket`
(`app_bootstrap.dart:122-131`). It cannot live in `AuthStatusNotifier.load()`:
bootstrap completes at `main.dart:71`, before the widget tree exists, and it already
reads the guest flag to choose the pref bucket. A gate in `load()` would run after
the bucket was picked and after the node had a chance to start.

Sequence:

1. read `app:api_version`
2. if absent or != 3 → clear session token and persisted user type
3. resolve pref bucket, continue bootstrap (now guaranteed to see cleared state)
4. router sends the user to `/auth`
5. write `3` inside `AuthStatusNotifier.completeLogin()` and `continueAsGuest()` —
   the two points where auth state actually resolves

Step 5 is deliberately **not** "when the user resolves the welcome screen". Every auth
subroute is directly reachable while unauthenticated (`app_router.dart:147` allows any
route in `_authRoutes`), so a deep link to `/auth/email` can complete a login without
the landing screen ever being shown. Tying the write to the screen would leave the
version unwritten and re-clear the token on every launch. Tying it to the two state
transitions covers every entry path.

On-chain accounts in secure storage are **not** touched. An operator who logs back in
is an operator again.

## 2. User type in SharedPreferences

New key `app:user_type`: `guest | member | operator`. **Replaces `auth:v3:guest`.**

`AuthStatus`:

| condition | AuthStatus |
|---|---|
| session token present | authenticated |
| user_type == guest | guest |
| otherwise | unauthenticated |

`UserLevel`:

| condition | UserLevel |
|---|---|
| status != authenticated | guest |
| `/me` resolved | `me.level` |
| fallback | operator if on-chain account, else member |

`app:user_type` is a **cache**, not the authority — rewritten when `UserLevel`
resolves, on login, logout and unauthorized. It exists so bootstrap and the first
frame can pick the node mode and tab set without waiting on `/me`.

## 3. Routing

- unknown → explicit early return (see Risks; fixed in this change)
- unauthenticated → `/auth`
- guest → may reach auth routes (#500)
- authenticated → unchanged

## 4. Tabs

Bottom nav becomes **Challenges · dApps · Wallet · More**, Wallet conditional.

| type | tabs | default |
|---|---|---|
| guest | Challenges, dApps, More | dApps |
| member | Challenges, dApps, More | dApps |
| operator | Challenges, dApps, Wallet, More | Challenges |

**More** is a new page listing Settings / Profile / Node Status.

Challenges content: guest → "sign in to unlock" + link to `/auth`; member →
waiting-list message; operator → the real screen.

The positional coupling is **centralised**, not spread out: `_homePages`,
`_bottomNavTabs` and the `IndexedStack` index (`home_screen.dart:93,279,289`). The
five other files use symbolic `HomeTab` values and are fine. The failure mode if
Wallet is dropped from `_homePages` is that every later page shifts up by one and
selections render the wrong screen. Fix: make `HomeTab` an enum, key the
`IndexedStack` off a per-type visible list, and stop `_homePages` from being a const
list whose order is load-bearing.

## 5. Node startup

Verified against usernode `b53c60d5`: the node has **no** keypair requirement.
`block_producer` is `Option`, default `None` (`builder.rs:46,306`); the p2p identity
auto-generates via `unwrap_or_else(P2pSecretKey::rand)` (`:828-831`).

### The decision must live inside `startNode()`

There are **seven** independent `startNode()` callers, not one entry point:

| caller | trigger |
|---|---|
| `app_bootstrap.dart:345` | launch |
| `providers.dart:57` | account created/imported |
| `block_production_alarm_audit_service.dart:905` | watchdog recovery (**enabled by default**, `:221`) |
| `app_sleep_service.dart:378` | wake from sleep |
| `android_foreground_task_controller.dart:229` | alarm monitoring |
| `zkpassport_flow_provider.dart:1175` | zk passport flow |
| `registration_flow.dart:63` | operator enrollment |

Gating each one is unworkable and would rot — a background watchdog would happily
start a keyed producing node for a member. **`startNode()` itself resolves the mode.**
Callers stay as they are; there is one decision point.

Additionally, producer-recovery machinery (watchdog, alarm audit) is disabled
outright when the user is not an operator, so nothing tries to resurrect block
production.

### Mode selection

Keyed **iff** all three hold: session token present, on-chain account exists, and
cached `app:user_type == operator`.

### Status after implementation

Delivered and safe:

- **Cold start** picks keyed/keyless exactly. Guests and members run a syncing,
  non-producing node; operators run the keyed path. This is the core requirement.
- **Single-isolate session changes** are handled: `startNode` re-resolves the
  mode as its final `await` and configures the producer + builds synchronously,
  so a mid-start logout is caught; `backendLifecycle` stops a producing node on
  logout/demotion, and any restart returns keyless.

Addressed in `usernode` (branch `feat/awaitable-shutdown`):

- **Awaitable shutdown.** `NodeControl.shutdown_and_wait` signals shutdown and
  awaits the run loop actually exiting. `stopNode` now awaits it, so on logout
  block production has provably ceased before the stop returns — the timing hole
  is closed for the single-engine case.
- **One node per process (best-effort).** `new_inner` signals the previous
  global node to shut down when a new one replaces it, so a second engine
  building a node does not leave the first one's producer running.

Still open — needs a bigger `usernode` change:

- **Cross-engine race.** The Android alarm engine can still build a keyed node
  in the sub-second window around a UI-engine logout. The above narrows it a lot
  but does not fully close it: a constructor cannot await the previous node's
  shutdown.
- **Within-session promotion** (member → operator) still needs an app restart.

Both remaining items need a *live production gate* — the ability to toggle or
refuse block production on a running node without rebuilding — which reaches into
the VRF/consensus state machine. Recommended as dedicated follow-up work; the
tier feature does not depend on it.

- guest, member → keyless start: skip account/secret lookup,
  skip `blockProducerSecretKey`, skip `_configureWalletSigner`, skip mempool
  autoinsert and observability intake
- operator → today's keyed path

The third condition is the important one. `/me` is **authoritative** over local
account presence — `resolveUserLevel` returns `me.level` whenever `/me` resolved, and
only falls back to `hasOnchainAccount` when it did not (`me.dart:59-61`). So a backend
`member` holding a stale local account must **not** produce blocks, and local state
alone cannot decide that.

`app:user_type` is what bridges the two: it caches the last backend-confirmed level,
so bootstrap gets backend authority without needing `/me` to be reachable. Offline
launches use the cache. A fresh login defaults to `member` until `/me` says otherwise
— conservative, never over-privileging.

**The mode is decided once, before the first start, and never upgraded by restart.**
The one case where a user becomes an operator mid-session is enrollment, and that
path already starts the node itself after importing the key
(`registration_flow.dart:63`), so no restart is needed there either.

Restart-to-upgrade would not be safe anyway. `stopNode()` does not await
shutdown — its own comment says the FRB API "does not expose a graceful shutdown"
(`node_service.dart:517-523`) — and `restartNode()` calls `startNode()` immediately
(`:590`). `startNode()` then reuses `Node.getGlobal()` if one exists (`:342`), so a
restart can adopt the still-dying keyless node, which can never become keyed because
block-producer configuration only happens while building a fresh `NodeBuilder`
(`:365`). Deciding up front avoids the race entirely.

If `/me` later contradicts the cache (says member while we started keyed), the cache
is corrected and producer recovery is disabled, but **the running node is left
alone until the next launch**. "Just stop it" does not work: `stopNode()` does not
await shutdown (`node_service.dart:517-523`), and five of the seven callers above —
watchdog, wake, alarm monitoring — would simply start it again. Correcting the cache
and killing the recovery paths is what actually sticks.

The `and a token` half matters too. Today an operator with a leftover on-chain
account but no session still starts a **block-producing** node
(`app_bootstrap.dart:343` → `node_service.dart:374`), so the welcome screen would not
actually stop them operating.

This replaces the `viewOnly`-via-guest-flag approach from `c48e506`, which still
loaded a real secret.

## 6. Remove: "Onboarding has evolved"

Delete the participant-recovery dialog:

- `lib/features/onboarding/widgets/participant_recovery_dialog.dart`
- `main.dart`: `_participantRecoveryOpen`, `_checkParticipantRecovery()`, both call
  sites (initState, didChangeAppLifecycleState)
- l10n keys `participantRecovery{Title,Body,Restore,Later,Success}`, all locales

Keep `registration_flow.dart` / `registerAndApply` — `import_api_account_screen`
needs it for operator enrollment.

**Consequence, needs a decision.** This dialog is the only automated repair for a
missing `participant_id`. Without it, an affected user is stuck: freshness stays
`unknown` (`leaderboard_bootstrap.dart:271`), so the stale-registration redirect
never fires (`app_router.dart:671`), and ranking stays disabled
(`ranking_provider.dart:10-13`).

Proposed replacement: a "Restore registration" entry in **More**. It cannot simply
reuse the existing route — `/onboarding/import-api` is bounced to `/home` for anyone
with an account and completed onboarding (`app_router.dart:683`), and on success the
screen hard-navigates into the permission flow
(`import_api_account_screen.dart:105`). So it needs:

- a new route outside `/onboarding/*`, e.g. `/more/restore-registration`
- `ImportApiAccountScreen` given a completion destination instead of a hardcoded
  `context.go(onboardingWelcomeSetup)` — restore mode returns to More

Same repair, user initiated, no nagging dialog.

## 7. Dead code to remove

- `AuthGuestFlag` (superseded by `app:user_type`)
- guest coupling to `AppConfig.viewOnly` in `node_service.dart`
- `HomeTab` int constants and `_visibleBottomNavIndexForTab`
- l10n orphaned by the above

## Risks

- **`unknown` falls through to authenticated-only logic**
  (`app_router.dart:594-606`). The api-version gate makes launch routing more
  sensitive to it. Fixed here with an explicit early return.
- Clearing the token on version mismatch logs out every existing user once. That is
  the intent of "treat as new install", but it is one-way on real devices.
- Node mode now depends on auth state, which resolves asynchronously. Bootstrap must
  not start a keyed node before the type is known — start keyless and upgrade, or
  wait. **Start keyless, then restart keyed on operator confirmation** is the
  proposal; it never over-privileges.

## Testing

- `AuthStatus` table: token × user_type
- api-version: absent → clear + welcome; 3 → untouched; gate ordering vs bootstrap
- operator with account but no token → keyless, non-producing
- tab visibility and default tab per type
- keyless vs keyed start across all three gate sites
