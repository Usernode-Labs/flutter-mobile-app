# Identity Lifecycle Invariants

The v4 migration made session identity (platform login) and node identity
(on-chain account) two separate systems that must stay reconciled. This doc
enumerates the states, the invariants every change must preserve, and where
each invariant is enforced in code. When touching auth, accounts, storage
buckets, or the ZK flow, audit your change against this list before review.

Code is authoritative; this doc points at it. If they disagree, fix one.

## Architecture

All identity state is a single immutable snapshot — `Identity`
(`lib/core/identity/identity.dart`) — owned by the `SessionController`
(`lib/core/identity/session_controller.dart`, exposed as
`identityProvider`). Everything else only reads.

An `Identity` carries:

- **`phase`** — `unknown / transitioning / unauthenticated / guest /
  reconciling / ready`. `transitioning` closes every account-sensitive gate
  while credentials and the node runtime are being replaced. `reconciling`
  means "a session exists but which on-chain account it owns has not been
  confirmed"; both phases gate wallet routes, dApp signing, and node starts.
- **`epoch`** — a monotonic counter bumped on every identity-changing
  transition (login, logout, guest, 401, season rollover). It invalidates
  ephemeral authority; it is deliberately not part of durable data ownership.
- **`participantId` / `accountId` / `address` / `provisionedSeasonId`** —
  the confirmed bindings, populated as the phase settles.

Async code carries one of two explicit capabilities:

- `AuthenticatedUserScope`, `AccountStorageScope`, `WalletDataScope`, and
  `ZkIdentityScope` are stable owners. Reads and writes already addressed to
  one of these scopes may finish after logout; they must only publish if that
  scope is still the current view.
- `IdentityLease`, `AuthenticatedUserLease`, `WalletIdentityLease`,
  `WalletRuntimeLease`, and `NodeStartAuthority` are ephemeral authority. They
  are revalidated at the boundary of an authenticated transport, signature,
  node-local wallet read, wallet RPC, or native runtime transition — not after
  every harmless suspension point.

The controller serializes every transition on an internal queue, publishes
each snapshot to the ambient `IdentitySnapshots` mirror (for non-Riverpod
call sites like the node service and dApp bridge), and is the **single
writer** of both identity snapshots and `NetworkPrefs.setActiveBucket` —
enforced by the `single_identity_snapshot_writer` and
`single_identity_bucket_writer` ds_lints.

The `IdentityDriver` (`lib/features/auth/providers/post_sign_in_sync.dart`)
makes the app converge on each published snapshot: a `reconciling` identity
triggers the `NodeAccountReconciler`
(`lib/features/onboarding/data/node_account_provisioning.dart`); a
transition into `ready` retries any pending ZK completion.

## State model

| State | Storage | Lifetime |
|---|---|---|
| Identity snapshot (`Identity`) | `identityProvider` / `IdentitySnapshots` (in-memory) | Republished on every transition |
| Session token | Secure storage (`AuthTokenStore`) | Cleared on logout/401 |
| Reconcile-pending marker | Network-prefixed pref, owned by `SessionController` | Login → reconcile commit |
| Account registry (index + active id) | `AccountsRepository` (`lib/core/providers/accounts_provider.dart`), network-prefixed prefs + secure storage | **Persists across logout** |
| Active storage bucket (`guest` or `sha256(address)[..16]`) | `NetworkPrefs.activeBucket` (`lib/core/utils/network_prefs.dart`), in-memory | Recomputed on every identity transition |
| Participant id | Account-bucket-scoped pref (`lib/core/identity/participant_id_store.dart`) | Staged in guest bucket at login, installed on reconcile |
| Provisioned season id | Account-bucket-scoped pref, owned by `SessionController` | Written at reconcile commit |
| Pending ZK completion | Versioned registration-repository outbox, pinned to an explicit bucket | Hidden by an exact-version terminal outcome |
| ZK request outcome | Append-only request-version/outcome-addressed pref | Permanent terminal decision for one launch |
| Onboarding-completed flag | Account-bucket-scoped pref (`lib/core/providers/providers.dart`) | Per identity |
| Node runtime | `RustBackendService` (`lib/features/node/node_service.dart`), binds active account's key **at start time** | Until stop/restart |
| Wallet/explorer data | `WalletDataScope` (account + chain) | Stable across node downtime/restarts; published only to the same account/chain |
| Node-local wallet/mempool read | `WalletRuntimeLease` (wallet data scope + runtime generation) | Discarded when that exact runtime stops or is replaced |
| dApp receipts / recipient history / HTTP logs | Explicit account or authenticated-user scope | Never exposed through a replacement identity |

## Invariants

**I1 — Ownership.** A local account is only treated as the session user's
after the backend has confirmed it: every reconciling identity resolves
through `POST /wallet/provision`, activating/importing the returned
address. The presence of *some* local account (`hasAny()`) is never an
ownership signal — the registry persists across logout.
*Enforced by:* `NodeAccountReconciler`, invoked by the `IdentityDriver`
whenever the identity is `reconciling`, and by `WelcomeSetupScreen`.

**I2 — Node identity follows explicit start and runtime authority.** Every
start path funnels through `RustBackendService.startNode`. Normal callers must
capture a settled `NodeStartAuthority`; the reconciler constructs a distinct
authority naming the exact network, account, and address it has just confirmed.
There is no boolean gate bypass. Equivalent concurrent starts coalesce;
different authorities wait, then revalidate independently.

A locally tracked runtime is reusable only when its native `NodeHandle` is
active and its `NodeRuntimeAuthority` matches the requested account/keyless
mode and runtime generation. An ambient process-wide handle has no proven Dart
identity and is never adopted: it is only the compare-and-swap target for a
fresh configured runtime. Guest/view-only builders contain neither producer
key nor wallet signer. Producer starts bind both the build-time producer key
and wallet signer; signer failure makes the start fail.

`stopNode` waits for any in-flight start, targets only this engine's exact
handle, and awaits `MobileNode.shutdown`, which completes after the driver
thread exits. A stop barrier revokes older queued starts; starts requested
after the barrier wait for it, so shutdown cannot miss a successor. Pause is a
desired lifecycle state applied before an in-flight start publishes its
facade. A stale handle is detached without falling back to stopping the new
process-wide current handle. A handle monitor clears local authority only for
the same generation on unexpected exit. Starts revalidate their lease at the
native transition and signer effects; if it changed, that exact newly returned
handle is shut down. The reconciler must not commit `ready` unless this process
succeeds.

*Enforced by:* `NodeStartAuthority` / `NodeRuntimeAuthority`, the start,
replace, monitor, and exact-shutdown state machine in
`lib/features/node/node_service.dart`; publish-before-await suspension in
`SessionController.completeLogin` / `beginSeasonRollover`; and
`NodeAccountReconciler._defaultEnsureNodeIdentity` before the
`reconcileSucceeded` commit. The remaining empty-slot cross-engine ambiguity
is documented below.

**I3 — Secrets never reach logs or log exports.** Key material and
credentials (`secret_key`, `token`, `password` and its aliases, `otp`, …)
are redacted from captured HTTP bodies before truncation and again at the
`HttpLogEntry` constructor chokepoint; headers were already redacted.
Never log a secret value; log lengths or addresses.
*Enforced by:* `redactSensitiveBodyFields`
(`lib/core/services/http_debug_log_store.dart`); consumed by
`LoggingHttpClient`. New sensitive field names must be added to
`_sensitiveBodyFields`.

**I4 — The guest bucket holds no other user's data in settled states.**
The participant id is *staged* there between login and reconcile only.
`installParticipantIdInBucket` deletes the staged source after the
destination write — and only when the staged value still matches the id
being installed (a mid-reconcile login stages the NEW user's id, which
must survive for their own reconcile). Logout and continue-as-guest clear
any leftover staged id.
*Enforced by:* `stageParticipantIdInGuestBucket` /
`installParticipantIdInBucket` / `clearGuestParticipantId`
(`lib/core/identity/participant_id_store.dart`);
`SessionController.completeLogin` / `logout` / `continueAsGuest`.

**I5 — Never read or write identity-scoped data through another user's
bucket.** Between login and reconcile, the registry's active account may
still belong to a *previous* user, so the guest bucket stays active until
the reconcile confirms ownership: boot restore only activates an account
bucket when its stored participant id proves the last reconcile completed
under this token's user. Anything persisted in that window must address
its bucket explicitly (`NetworkPrefs.prefixAccountKeyFor`), not implicitly
(`prefixAccountKey`). The bucket has exactly one writer.
*Enforced by:* `SessionController._restoreAuthenticated` / `_publish`, the
`single_identity_bucket_writer` ds_lint
(`packages/ds_lints/lib/src/lint_visitor.dart`), plus login staging (I4).

**I6 — Multi-step transitions are resumable.** Provision → import/activate
→ id install → node bind → commit can be interrupted at any point; because
the reconcile re-runs whenever a `reconciling` identity is published and
each step is idempotent, partial state self-heals. Login persists a
reconcile-pending marker (cleared only by the `reconcileSucceeded` commit)
so a boot restore routes an interrupted login back into `reconciling`. No
step may assume a previous run completed.
*Enforced by:* the marker lifecycle inside `SessionController` (`restore`
/ `completeLogin` / `reconcileSucceeded`); regression tests in
`test/features/onboarding/node_account_reconciler_test.dart` and
`test/core/providers/participant_id_migration_test.dart`.

**I7 — A pending ZK completion is eventually submitted or explicitly
rolled back, under the identity and request version that own it.** Every
launch is reserved in the controller before the first server call, so rapid
duplicate triggers share one session. The persisted exact version (`request
id`, wall-clock creation time, and random 128-bit nonce) is copied unchanged
into the runtime, outbox, optimistic registration, and terminal outcome; an
outcome for one version cannot hide another.

The runtime persists a complete stable launch scope (network, bucket,
participant, account, address, challenge). Foreground and cold-start recovery
resume polling automatically only when that scope matches; an unsettled
identity defers, and a different settled owner detaches without acting as that
owner. Poll and finalizer work is keyed by the exact request generation, and
compare-and-clear refuses to erase a replacement generation. Launch waits for
cold restoration before inspecting `idle`, so it cannot overwrite an unseen
request. The session server's consumptive result is persisted into that exact
runtime row before any post-response identity check; recovery replays it
without calling `/result` again.

The pending completion is written before both optimistic registration and the
first delivery attempt. An unresolved account outbox blocks a new launch
instead of being overwritten. Exact authority is checked immediately before
every authenticated completion POST. Once that transport starts, its success
or terminal rejection is a fact about the original stable request scope and
is recorded there—even ahead of best-effort telemetry—if the UI identity
changes while the response is in flight. Append-only outcomes are the
crash-consistency boundary: `delivered` hides the outbox while preserving
registration; `rejected` or `discarded` hides both. A 401 or retryable
transport failure preserves the row for the next ready identity opportunity.

*Enforced by:* the launch single-flight, `markLaunchStarted`,
`_checkLaunchIdentity`, request-keyed polling/finalization,
`isTerminalZkCompletionRejection`, `retryPendingCompletion` /
`_prepareBackendCompletion` / `_deliverBackendCompletion` /
`_handleTerminalCompletionRejection`
(`lib/features/zkpassport/providers/zkpassport_flow_provider.dart`),
the launch scope and request version on `ZkPassportRuntimeSession`
(`lib/features/zkpassport/data/models/zkpassport_models.dart`, round-trip
tests in
`test/features/zkpassport/data/models/zkpassport_state_models_test.dart`),
`storePendingCompletion` / `recordRequestOutcome` / runtime compare-and-clear
(`lib/features/zkpassport/data/repositories/zkpassport_repositories.dart`),
and the ready-transition trigger in the `IdentityDriver`.

**I8 — Identity transitions recompute identity-derived state.** Every
transition publishes a new `Identity` snapshot; providers holding
identity-derived or bucket-scoped data watch `identityProvider` (e.g.
`participantIdProvider`, `walletProvider`) or are keyed by a scope selected
from that snapshot (e.g. `recipientHistoryProvider`). Other providers are
invalidated by the reconciler (`hasAnyAccountProvider`,
`activeAccountProvider`, `accountsProvider`,
`hasCompletedOnboardingProvider`). An auth-status watch alone cannot see a
mid-session bucket switch — watch the snapshot.
*Enforced by:* `SessionController._publish` + `ref.watch(identityProvider)`
in account-scoped providers + `NodeAccountReconciler` invalidations.

**I9 — All identity storage is network-prefixed.** Testnet/internal/custom
data never mix. Account-scoped keys are additionally bucket-prefixed.
*Enforced by:* `NetworkPrefs.prefixKey*` — never build storage keys by
hand.

**I10 — Async work separates stable ownership from live authority.** Every
identity-changing transition bumps `Identity.epoch`, and identity transitions
themselves are serialized on the controller queue. Work that can cause an
external effect (authenticated transport, key access, signature, wallet send,
node start) captures a lease and revalidates it immediately before that
effect. Work that already has an explicit stable owner may finish reading or
persisting into that old scope; only publication into the current UI is
conditional on the scope still matching. This avoids both cross-user effects
and the opposite bug where a valid response for A is lost merely because the
user moved to B while it was in flight.

Coalescing is lease-aware: a newer caller does not join a stale identity's
run. Commits (`reconcileSucceeded`, `onUnauthorized`) validate the exact
epoch inside the serialized queue. Authenticated requests retain the exact
credential they carried and may invalidate only that credential.

*Enforced by:* the lease/scope types in
`lib/core/identity/identity_scope.dart`, effect gates in
`LeaderboardApiService`, `RustBackendService`, wallet and dApp send/sign
paths, publication gates in scoped providers, and epoch checks inside
`SessionController.reconcileSucceeded` / `onUnauthorized`; regression tests
in `test/core/identity/identity_scope_test.dart`,
`test/features/onboarding/node_account_reconciler_test.dart`, and
`test/features/auth/providers/auth_status_test.dart`.

**I11 — Credential replacement has a crash-atomic recovery payload.** Login
first publishes `transitioning`, then clears the previous credential and
persists the reconcile-pending marker and staged participant id BEFORE the
replacement session token. Node shutdown is allowed to fail independently:
the controller publishes `reconciling` only after both the token is durable
and the previous runtime is confirmed down, otherwise it stays fail-closed in
`transitioning`. A crash in this replacement sequence either leaves the device
signed out (token missing — clean retry) or signed in with the full recovery
payload present for the boot reconcile. When the payload is nevertheless
missing (legacy state), the reconciler recovers the participant id from the
authenticated `/me` endpoint rather than committing without it. The marker is
only cleared by a commit that confirmed both the account AND the node runtime
identity, in the same epoch that started it.
*Enforced by:* the write order in `SessionController.completeLogin` (order
probe test in `test/features/auth/providers/auth_status_test.dart`),
`NodeAccountReconciler._resolveParticipantId`, and the commit gating in
`reconcileSucceeded`.

**I12 — Identity is gated until reconciled, and signing authority is
re-proven at the effect point.** While the identity is `transitioning` or
`reconciling`, an authenticated session must not sign or spend with the active
local account — it may still belong to a previous user; guest sessions never
sign at all (`Identity.allowsSigning` refuses `guest` outright). Three
independent gates enforce this: the router bounces wallet routes
(`identityGateRedirect`), the dApp bridge refuses `sendTransaction` /
`signMessage`, and the node-start chokepoint refuses to start (I2). Entry
gates alone are not enough: the dApp handlers capture a wallet lease when
the request arrives and re-validate its exact snapshot *after* the user
confirmation dialog, immediately before loading the secret key or
issuing the RPC — a login/logout while the dialog is up must not let the
old confirmation sign under the new identity. The sender is derived by the
final node-service gateway from that lease, not accepted from the caller.
Explorer reads and caches carry stable account + chain ownership and remain
available while the node is offline. Only node-local balance/mempool reads
carry a runtime generation, and their result is discarded when that lease is
replaced. dApp receipts are account-scoped and are blanked when their lease is
revoked. No wallet path resolves an ambient active account after suspending.
The router re-evaluates on every published snapshot.
*Enforced by:* `identityGateRedirect` (`lib/core/config/app_router.dart`),
`Identity.allowsSigning` (guest-refusal test in
`test/features/auth/providers/auth_status_test.dart`),
`_bridgeWalletIdentity` and the post-confirmation lease checks in
`DappWebViewScreen._handleSendTransaction` / `_handleSignMessage`
(`lib/features/dapps/dapp_webview_screen.dart`), the identity-derived
scope in `walletProvider` (`lib/core/providers/wallet_provider.dart`), the
wallet-effect gateway in `RustBackendService`, and the `startNode` gate. The
`no_ambient_wallet_account` and `wallet_effect_gateway_only` ds_lints keep new
call sites on these boundaries.

**I13 — Reconciliation follows the active season.** `/wallet/provision`
allocates per season. A session that lives across a season rollover must
re-reconcile — no sign-in transition ever fires for it. The authoritative
signal is the backend's `is_active` season from `/seasons`
(`activeSeasonIdOf`), never the user-selected reporting season the season
picker mutates. The controller compares it against the identity's
persisted `provisionedSeasonId` and re-enters `reconciling` (new epoch)
only on a genuine mismatch, so the listener can fire on every refresh. A
rollover also suspends a running node (I2) — it was producing under the
previous season's binding. Installs upgraded from before season tracking
have a `ready` identity with *no* baseline: the first authoritative season
report triggers a one-time migration reconcile (guarded by a persisted
per-account flag so a backend that still reports no season id cannot loop
it).
*Enforced by:* `seasonRolloverSyncProvider` / `activeSeasonIdOf`
(`lib/features/auth/providers/post_sign_in_sync.dart`) and
`SessionController.beginSeasonRollover` (rollover-suspend and
baseline-migration tests in
`test/features/auth/providers/auth_status_test.dart`).

**I14 — Long-lived callbacks retain exact identity authority.** A log-sharing
session captures one identity and credential, validates both before every
send/retry, and never advances its owner-specific cursor with another user's
row. Authenticated HTTP debug entries are tagged with the stable owner captured
before transport; anonymous entries remain ownerless. The viewer and
copy/export paths filter to the current owner. dApp profile/logout callbacks
capture identity before origin validation and re-check it at their effect
boundary; a stale callback cannot log out its successor.
*Enforced by:* `LoggingHttpClient`, `HttpDebugLogStore`,
`LogShareController` / `LogShareService`, and
`DappWebViewScreen._handleGetProfileInfo` / `_handleLogout`.

## Known residual risks (accepted for now)

- **In-memory session state is not reset on user switch.** e.g.
  `seasonEventContextProvider` keeps the previous user's season/event
  selection until the auth-gated bootstrap rewrites it. Cosmetic: all
  data fetches use the new session's token.
- **Sign-in reconcile costs one `/wallet/provision` round-trip per
  login** (deliberate: it is the ownership check). Boot restore stays
  network-free unless the previous session never settled (I6).
- **Reconcile failure on a switched device** (offline sign-in by user B
  on user A's device) leaves A's account in the registry until a
  reconcile succeeds (the persisted `reconciling` phase re-runs on next
  boot). The node stays down and signing stays refused in the meantime
  (I2/I12), and B's session stays on the guest bucket (I5), so no
  cross-identity reads, writes, signatures, or block production occur.
- **The native mobile-node slot has no identity authority metadata or vacant
  compare-and-swap result.** Exact handles make shutdown and replacement
  generation-safe, but `getOrStart` cannot distinguish “started from the
  observed empty slot” from “reused a runtime another engine installed in that
  race.” A native account/network authority tag or start-if-still-empty CAS is
  required before simultaneous Flutter engines can prove producer ownership.
- **ZK runtime and outbox source rows remain one mutable preference per
  account.** Exact request outcomes are append-only, local updates use
  compare-and-clear, and an unresolved outbox prevents a second local flow
  from overwriting it. SharedPreferences still cannot make that guard or CAS
  transactional across Flutter engines. Concurrent-engine support requires
  request-keyed rows in a native transactional store.
- **Event-points pagination has no backend snapshot token or cursor.** The
  client validates page metadata and participant uniqueness, then retries one
  whole read when it detects drift. That bounds common corruption modes but
  cannot prove a consistent multi-page snapshot while ranks are changing; a
  backend as-of token or keyset cursor is the durable fix.
- **The pre-baseline season migration reads its persisted one-time flag before
  publishing the rollover gate.** A start can race that lookup on upgraded
  installs whose identity has no provisioned-season baseline. Moving the
  baseline attempt into the identity transaction remains separate lifecycle
  work.
