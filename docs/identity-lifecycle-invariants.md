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

- **`phase`** — `unknown / unauthenticated / guest / reconciling / ready`.
  `reconciling` means "a session exists but which on-chain account it owns
  has not been confirmed"; it gates wallet routes, dApp signing, and node
  starts.
- **`epoch`** — a monotonic counter bumped on every transition (login,
  logout, guest, 401, season rollover). Async work captures the epoch it
  started under and its results are discarded if the epoch moved on.
- **`participantId` / `accountId` / `address` / `provisionedSeasonId`** —
  the confirmed bindings, populated as the phase settles.

The controller serializes every transition on an internal queue, publishes
each snapshot to the ambient `IdentitySnapshots` mirror (for non-Riverpod
call sites like the node service and dApp bridge), and is the **single
writer** of `NetworkPrefs.setActiveBucket` — enforced by the
`single_identity_bucket_writer` ds_lint.

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
| Pending ZK completion | Registration repository, pinned to an explicit bucket | Until submitted, terminally rejected, or rolled back |
| Onboarding-completed flag | Account-bucket-scoped pref (`lib/core/providers/providers.dart`) | Per identity |
| Node runtime | `RustBackendService` (`lib/features/node/node_service.dart`), binds active account's key **at start time** | Until stop/restart |

## Invariants

**I1 — Ownership.** A local account is only treated as the session user's
after the backend has confirmed it: every reconciling identity resolves
through `POST /wallet/provision`, activating/importing the returned
address. The presence of *some* local account (`hasAny()`) is never an
ownership signal — the registry persists across logout.
*Enforced by:* `NodeAccountReconciler`, invoked by the `IdentityDriver`
whenever the identity is `reconciling`, and by `WelcomeSetupScreen`.

**I2 — Node identity follows the settled identity.** The node binds the
active account's secret key at start. `RustBackendService.startNode` — the
chokepoint every start path funnels through (bootstrap, wake, foreground
task, alarms) — refuses to start while the identity is `reconciling`
(`Identity.allowsNodeStart`), and `resumeNode` applies the same gate; only
the reconciler passes `identityOverride: true`, and only for the account
it just confirmed. The gate is airtight against races on both sides:
`completeLogin` / `beginSeasonRollover` publish the `reconciling` snapshot
*before their first `await`*, so a start racing the transition already
sees the closed gate; `startNode` re-checks the gate after the runtime
comes up and tears it down if the identity became unsettled mid-start; and
`stopNode` waits out any in-flight start before stopping, so a suspend can
never interleave with a start and lose. Entering `reconciling` stops a
running node; the reconciler then requests `freshRuntime: true`, which
shuts down and rebuilds any existing global node — the block producer key
is captured at build time and cannot be swapped on a live runtime — and a
wallet-signer bind failure fails the start and tears the runtime down
rather than leaving a half-bound node running. The reconciler treats
`startNode() == false` as failure — the identity must not become `ready`
with an unconfirmed runtime.
*Enforced by:* the gates in `startNode` / `resumeNode`, the post-start
re-check and `_teardownRuntimeAfterFailedBind` in
`RustBackendService._startNodeInternal`, the publish-before-await order
and `_suspendNode` in `SessionController.completeLogin` /
`beginSeasonRollover` (gate-ordering test in
`test/features/auth/providers/auth_status_test.dart`), and
`NodeAccountReconciler._defaultEnsureNodeIdentity` (runs before the
`reconcileSucceeded` commit).

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
rolled back, under the identity that owns it.** A ZK run is *bound to its
launch identity*: `markLaunchStarted` persists the launching epoch,
bucket, and participant id in the runtime session, and every later stage
— foreground recovery, server polling, the proof pipeline — re-validates
the current identity against that launch identity
(`_checkLaunchIdentity`): a different user's session is discarded, an
unsettled identity defers rather than proceeding. The pending completion
record is an identity-keyed outbox row: persisted (pinned to the owning
identity's bucket) BEFORE the first delivery attempt, so killing the app
mid-send never loses the retry. Every completion POST re-checks the epoch
immediately before the request fires — not just at the retry's entry —
because retry backoff delays are suspension points a login can pass
through. Terminal 4xx (except 401/408/429) clears the record AND rolls
back the optimistic local registration — but only when the identity that
answered is still the identity that submitted (the rollback itself
re-validates the epoch it was told to target). 401 preserves the proof;
the retry fires when the identity settles to `ready` — not only on cold
start. The retry never runs under an unsettled identity
(`Identity.isSettled`), pins reads and clears to the bucket captured at
start, and epoch-scopes its coalescing so a newer identity's caller never
joins a stale run.
*Enforced by:* `markLaunchStarted` / `_checkLaunchIdentity` /
`isTerminalZkCompletionRejection`, `retryPendingCompletion` /
`_attemptBackendCompletion` / `_handleTerminalCompletionRejection`
(`lib/features/zkpassport/providers/zkpassport_flow_provider.dart`),
the launch-identity fields on `ZkPassportRuntimeSession`
(`lib/features/zkpassport/data/models/zkpassport_models.dart`, round-trip
tests in
`test/features/zkpassport/data/models/zkpassport_state_models_test.dart`),
`storePendingCompletion(bucket:)`
(`lib/features/zkpassport/data/repositories/zkpassport_repositories.dart`),
and the ready-transition trigger in the `IdentityDriver`.

**I8 — Identity transitions recompute identity-derived state.** Every
transition publishes a new `Identity` snapshot; providers holding
identity-derived or bucket-scoped data watch `identityProvider` (e.g.
`participantIdProvider`, `walletProvider`, `recipientHistoryProvider`) or
are invalidated by the reconciler (`hasAnyAccountProvider`,
`activeAccountProvider`, `accountsProvider`,
`hasCompletedOnboardingProvider`). An auth-status watch alone cannot see a
mid-session bucket switch — watch the snapshot.
*Enforced by:* `SessionController._publish` + `ref.watch(identityProvider)`
in account-scoped providers + `NodeAccountReconciler` invalidations.

**I9 — All identity storage is network-prefixed.** Testnet/internal/custom
data never mix. Account-scoped keys are additionally bucket-prefixed.
*Enforced by:* `NetworkPrefs.prefixKey*` — never build storage keys by
hand.

**I10 — Async identity work is epoch-scoped.** Every transition bumps
`Identity.epoch`, and transitions themselves are serialized on the
controller's queue so their persistence writes never interleave. In-flight
async work started under an older epoch must not: join a newer caller's
coalescing slot (the newer caller waits it out and runs fresh), mutate
identity state with its now-stale response, clear recovery markers, or
clear a session token on a late 401. Commits (`reconcileSucceeded`,
`onUnauthorized`) re-validate the epoch inside the serialized queue. This
is what stops "B's slow provision response activates B's wallet inside C's
session".
*Enforced by:* the epoch guards in `NodeAccountReconciler.reconcile` /
`_reconcile` (re-checked before every mutation, each `await` being a
suspension point), `_retryPendingCompletionGuarded`, the epoch-carrying
401 callbacks in `LeaderboardApiService._parseEnvelope` and
`AccountApiService.getMe`, and the epoch checks inside
`SessionController.reconcileSucceeded` / `onUnauthorized`; regression
tests in `test/features/onboarding/node_account_reconciler_test.dart` and
`test/features/auth/providers/auth_status_test.dart`.

**I11 — The login recovery payload is crash-atomic.** The reconcile-pending
marker and the staged participant id are persisted BEFORE the session
token; a crash at any point either leaves the device signed out (token
missing — clean retry) or signed in with the full recovery payload present
for the boot reconcile. When the payload is nevertheless missing (legacy
state), the reconciler recovers the participant id from the authenticated
`/me` endpoint rather than committing without it. The marker is only
cleared by a commit that confirmed both the account AND the node runtime
identity, in the same epoch that started it.
*Enforced by:* the write order in `SessionController.completeLogin` (order
probe test in `test/features/auth/providers/auth_status_test.dart`),
`NodeAccountReconciler._resolveParticipantId`, and the commit gating in
`reconcileSucceeded`.

**I12 — Identity is gated until reconciled, and signing authority is
re-proven at the effect point.** While the identity is `reconciling`, an
authenticated session must not sign or spend with the active local
account — it may still belong to a previous user; guest sessions never
sign at all (`Identity.allowsSigning` refuses `guest` outright). Three
independent gates enforce this: the router bounces wallet routes
(`identityGateRedirect`), the dApp bridge refuses `sendTransaction` /
`signMessage`, and the node-start chokepoint refuses to start (I2). Entry
gates alone are not enough: the dApp handlers capture the signing
identity when the request arrives and re-validate its epoch *after* the
user confirmation dialog, immediately before loading the secret key or
issuing the RPC — a login/logout while the dialog is up must not let the
old confirmation sign under the new identity. All wallet reads exposed to
dApps (`getNodeAddress`, `getWalletState`, balance/transaction fetches)
derive their address from the same identity snapshot, never from the
account registry directly. The router re-evaluates on every published
snapshot.
*Enforced by:* `identityGateRedirect` (`lib/core/config/app_router.dart`),
`Identity.allowsSigning` (guest-refusal test in
`test/features/auth/providers/auth_status_test.dart`),
`_bridgeWalletIdentity` and the post-confirmation epoch re-checks in
`DappWebViewScreen._handleSendTransaction` / `_handleSignMessage`
(`lib/features/dapps/dapp_webview_screen.dart`), the identity-derived
address in `walletProvider` (`lib/core/providers/wallet_provider.dart`),
and the `startNode` gate.

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
