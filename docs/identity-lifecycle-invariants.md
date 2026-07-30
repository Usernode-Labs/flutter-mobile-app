# Identity Lifecycle Invariants

The v4 migration made session identity (platform login) and node identity
(on-chain account) two separate systems that must stay reconciled. This doc
enumerates the states, the invariants every change must preserve, and where
each invariant is enforced in code. When touching auth, accounts, storage
buckets, or the ZK flow, audit your change against this list before review.

Code is authoritative; this doc points at it. If they disagree, fix one.

## State model

| State | Storage | Lifetime |
|---|---|---|
| Session status (`unknown / unauthenticated / guest / authenticated`) | `authStatusProvider` (`lib/features/auth/providers/auth_providers.dart`), token in secure storage | Cleared on logout/401 |
| Account registry (index + active id) | `AccountsRepository` (`lib/core/providers/accounts_provider.dart`), network-prefixed prefs + secure storage | **Persists across logout** |
| Active storage bucket (`guest` or `sha256(address)[..16]`) | `NetworkPrefs.activeBucket` (`lib/core/utils/network_prefs.dart`), in-memory | Recomputed on every identity transition |
| Participant id | Account-bucket-scoped pref (`lib/core/providers/leaderboard_participant_provider.dart`) | Staged in guest bucket at login, moved on reconcile |
| Pending ZK completion | Registration repository, account-bucket-scoped | Until submitted, terminally rejected, or rolled back |
| Onboarding-completed flag | Account-bucket-scoped pref (`lib/core/providers/providers.dart`) | Per identity |
| Node runtime | `RustBackendService` (`lib/features/node/node_service.dart`), binds active account's key **at start time** | Until stop/restart |

## Invariants

**I1 — Ownership.** A local account is only treated as the session user's
after the backend has confirmed it: every sign-in and every onboarding
attempt calls `POST /wallet/provision` and activates/imports the returned
address. The presence of *some* local account (`hasAny()`) is never an
ownership signal — the registry persists across logout.
*Enforced by:* `NodeAccountReconciler`
(`lib/features/onboarding/data/node_account_provisioning.dart`), invoked
from `postSignInSyncProvider` and `WelcomeSetupScreen`.

**I2 — Node identity follows the active account.** The node binds the
active account's secret key at start. Any flow that changes the active
account while a node may be running must restart it; the lifecycle
provider only reacts to has-any-account flips, not switches.
*Enforced by:* the restart hook in `NodeAccountReconciler._reconcile`
(triggered when a previously active account is switched away from).

**I3 — Secrets never reach logs or log exports.** Key material and
credentials (`secret_key`, `token`, `password`, `otp`, …) are redacted
from captured HTTP bodies before truncation and again at the
`HttpLogEntry` constructor chokepoint; headers were already redacted.
Never log a secret value; log lengths or addresses.
*Enforced by:* `redactSensitiveBodyFields`
(`lib/core/services/http_debug_log_store.dart`); consumed by
`LoggingHttpClient`. New sensitive field names must be added to
`_sensitiveBodyFields`.

**I4 — The guest bucket holds no other user's data in settled states.**
The participant id is *staged* there between login and reconcile only.
The reconcile move deletes the source after the destination write;
logout and continue-as-guest clear any leftover staged id.
*Enforced by:* `stageParticipantIdInGuestBucket` /
`migrateGuestParticipantId` / `clearGuestParticipantId`
(`lib/core/providers/leaderboard_participant_provider.dart`);
`completeLogin` / `logout` / `continueAsGuest`.

**I5 — Never read or write identity-scoped data through another user's
bucket.** Between login and reconcile, the registry's active account may
still belong to a *previous* user. Login therefore only activates the
account bucket when it provably belongs to the session (its stored
participant id matches); otherwise the guest bucket stays active until
the reconcile confirms ownership. Anything persisted in that window must
address its bucket explicitly (`NetworkPrefs.prefixAccountKeyFor`), not
implicitly (`prefixAccountKey`).
*Enforced by:* `activateBucketForSession`
(`lib/core/providers/leaderboard_participant_provider.dart`) called from
`completeLogin`, plus login staging (I4).

**I6 — Multi-step transitions are resumable.** Provision → import/activate
→ bucket switch → id move can be interrupted at any point; because
reconciliation re-runs on every sign-in and onboarding attempt (I1) and
each step is idempotent, partial state self-heals. A login persists a
reconcile-pending marker (`markAccountReconcilePending`, cleared on
reconcile success) so that a boot restore — which never produces a
sign-in transition — re-runs the reconcile when a previous one was
interrupted. No step may assume a previous run completed.
*Enforced by:* reconcile-always semantics + idempotent move (I4) +
pending marker (`lib/core/providers/accounts_provider.dart`, consumed by
`postSignInSyncProvider`); regression tests in
`test/features/onboarding/node_account_reconciler_test.dart` and
`test/core/providers/participant_id_migration_test.dart`.

**I7 — A pending ZK completion is eventually submitted or explicitly
rolled back.** Terminal 4xx (except 401/408/429) clears the pending
record AND rolls back the optimistic local registration. 401 preserves
the proof and a guarded retry fires when auth transitions back to
authenticated — not only on cold start. Retryable errors keep the record.
*Enforced by:* `isTerminalZkCompletionRejection`,
`retryPendingCompletion` (`lib/features/zkpassport/providers/zkpassport_flow_provider.dart`),
`postSignInSyncProvider` (`lib/features/auth/providers/post_sign_in_sync.dart`).

**I8 — Auth transitions recompute identity-derived state.** Every
transition recomputes the active bucket; sign-in additionally triggers
reconcile + ZK retry; providers holding identity-derived data either
watch `authStatusProvider` or are invalidated by the reconciler
(`participantIdProvider`, `hasAnyAccountProvider`, `activeAccountProvider`,
`accountsProvider`, `hasCompletedOnboardingProvider`).
*Enforced by:* `AuthStatusNotifier` methods + `NodeAccountReconciler`
invalidations.

**I9 — All identity storage is network-prefixed.** Testnet/internal/custom
data never mix. Account-scoped keys are additionally bucket-prefixed.
*Enforced by:* `NetworkPrefs.prefixKey*` — never build storage keys by
hand.

## Known residual risks (accepted for now)

- **In-memory session state is not reset on user switch.** e.g.
  `seasonEventContextProvider` keeps the previous user's season/event
  selection until the auth-gated bootstrap rewrites it. Cosmetic: all
  data fetches use the new session's token.
- **Sign-in reconcile costs one `/wallet/provision` round-trip per
  login** (deliberate: it is the ownership check). Boot restore stays
  network-free unless the reconcile-pending marker is set (I6).
- **Reconcile failure on a switched device** (offline sign-in by user B
  on user A's device) leaves A's account in the registry and a running
  node under A's identity until a reconcile succeeds (retried on next
  boot via the pending marker). B's session stays on the guest bucket
  in the meantime (I5), so no cross-identity reads or writes occur.
