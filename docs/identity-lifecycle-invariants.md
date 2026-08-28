# Identity Lifecycle Invariants

The mobile app is the private composition boundary between Social, the native
Usernode runtime, and Android/iOS. Login and logout are hard identity
boundaries: work admitted for session A finishes before A is retired, and
session B is not published until its native authority is ready.

Code is authoritative. This document names the small set of boundaries that
must remain true when session, bridge, vault, or background code changes.

## One owner, one public shape

The mounted, library-private `_NativeSessionCompositionRoot` in
`lib/src/session_lifecycle/native_session_transport.dart` is the sole Flutter
lifecycle owner. It is created only by the private bootstrap in `lib/main.dart`.
No provider, service locator, public bootstrap function, or product-feature
argument contains its root or native session clients.

Features receive only `SessionFeatureAccessView` from
`lib/core/session/session_operation_runner.dart`. Its current value contains:

- an immutable `SessionIdentityProjection` (`signedOut` or `ready`); and
- a `SessionOperationRunner` that admits work for exactly that publication.

Signed-out runners reject permanently. A ready runner cannot publish, replace,
or close a session. Generated FRB clients and the process-root proof never
cross the private composition root. The sole glue exception is the trusted
Flutter-to-Social adapter: private widget fields receive the attenuated
`NativeSessionBridgeIngress` by explicit constructor injection from private
route-builder closures. It is not stored in Riverpod or exposed as a public
field, and every call still requires the exact realm marker and realm-session
claim.

## Boundary ordering

`lib/src/session_lifecycle/session_operation_kernel.dart` enforces the temporal
contract:

1. A top-level operation is counted before feature code runs.
2. An admitted operation may add counted child work and exact effects until its
   callback settles.
3. Logout closes new top-level admission synchronously.
4. Logout waits without a timeout for every admitted operation, child, and
   effect to finish.
5. Only then may native logout and exact platform-vault retirement commit.
6. Only after that commit does Flutter publish signed-out or a successor.

Establishment is serialized with logout. If a same-realm terminal intent
arrives while establishment is committing, the new Ready remains private and
is retired with its exact native revision; it is never briefly published.
Once Rust returns a committed Ready receipt, Flutter retains its private
session/revision authority until terminal cleanup even if wake or UI
publication fails.

The composition-root resume barrier gates the same runner used by every
feature. On foreground resume, native credential evidence is resolved before
ZK recovery, Social push replay, WebView dispatch, node status, or any other
session operation can enter. UI input is also blocked while this validation is
pending.

Focused deterministic checks live in
`test/core/session/session_operation_kernel_test.dart` and
`test/features/dapps/bridge_admission_coordinator_test.dart`.

## Native authority and credential custody

Android implements the private platform boundary under
`android/app/src/main/kotlin/com/usernode_labs/usernode/session/`; iOS mirrors
it in `ios/Runner/NativeSessionPlatform.swift`,
`ios/Runner/NativeSessionProtocol.swift`, and
`ios/Runner/NativeSessionVault.swift`.

The following rules are structural, not conventions:

- The random platform process-transport claim is bound to the exact current
  Flutter engine lease. It remains valid for that lease; installing a successor
  invalidates its predecessor.
- Rust root/install/wake/apply claims are separately one-use. Root proofs,
  native session clients, account scalar, and mobile bearer are never returned
  to Dart features or JavaScript.
- The account scalar may cross platform-to-Rust once when a proven credential
  is installed. Warm producer wakes carry only bounded vault evidence.
- Native vault reads distinguish definitive absence from uncertainty. A
  Keychain/Keystore error or network/server failure is uncertain and makes no
  destructive write.
- An authenticated, exact-credential 401 is definitive only for the credential
  reference and generation that made that request. Retirement is a
  compare-delete of that exact vault record.
- The trusted mobile API base is fixed at bootstrap to a validated HTTPS
  `/api/v4/mobile` origin selected by the build. There is no generic native
  HTTP or bearer API.

Delegation policy and push registration are private platform-vault HTTP calls.
Flutter can request only their closed, purpose-specific operations. Delegation
identity is credential-derived by Social; Flutter cannot submit an account.
Policy writes retain Social's server-generated E+2 effective epoch and
same-epoch serialization contract.

## Cold recovery

Rust's durable state is canonical. A cold snapshot may be logged out,
recoverable Ready, or require an in-progress/terminal recovery decision.

- A LoggedOut snapshot, including recovery that commits LoggedOut, invokes one
  process-root-only platform cleanup before Flutter publishes signed-out. It
  removes any credential or producer selector orphaned between Rust commit and
  platform retirement.
- Definitive credential absence resolves cold state to signed-out.
- Uncertain evidence stays write-free and retryable; it never publishes Ready.
- Present evidence adopts the exact durable identity. A ColdReady install uses
  one bounded, one-use credential claim; warm wakes cannot restage the scalar.
- Cold adoption retains the private root/session authority even if the first
  post-adoption wake cannot complete, so later exact retirement is possible.

A rare Android overlap between an already-starting background runtime and cold
interactive bootstrap remains deliberately fail-closed and may require a
natural relaunch. It is documented at the `transitionInProgress` mapping; no
second recovery coordinator is introduced for this extreme case.

## Producer wake and OS ownership

`NativeProducerWakeCoordinator.kt` owns Android's native-to-Rust background
callback. A Present wake is two-step: the platform stages a fixed bounded
request and receives an opaque one-use claim; only consumption of that claim
can run the mutation. Definitive absence uses its separate closed command.
Uncertainty stays platform-local and retryable.

Every Ready-derived Rust directive retains A's operation permit until the
platform reports exact apply success or failure. Platform code validates the
revision/wake identity, compare-applies the existing OS effect, then completes
the one-use apply claim. A failed completion rolls back only the newly applied
effect and cannot stop or clear a newer session. Rust releases A only after
completion.

Android alarm permissions, `AlarmManager` choice, trigger calculations,
notifications, foreground-service policy, watchdog/WorkManager behavior, and
the existing local polling cadence are unchanged. Headless Flutter is removed;
existing receivers and workers now enter the private native coordinator.
There is no Rust alarm journal or lifecycle reconciler.

iOS uses the same credential/root/session and staged-wake authority, but makes
no exact wake-timing claim. Existing callbacks are best-effort. Unsupported
schedule/retry effects are reported truthfully as failures while an already
running foreground Ready session remains usable. A warm definitive absence
closes Rust A, clears the exact vault revision, closes Flutter admission, and
latches an inert signed-out publication until natural relaunch; the app does
not call `exit` or `fatalError`.

## Feature effects

Session-bound work must be expressed as a purpose-specific method on
`SessionOperation`; a raw native client, bearer, native HTTP request, or global
node owner is never an acceptable shortcut. Current closed effects cover:

- node/status and wallet reads, signing, and transaction submission;
- delegation reads and E+2 mutations;
- device benchmark start/cancel/status/result;
- the retained ZK proof verification/wrapping/completion mechanics;
- push status/register/unregister using the exact native credential;
- one exact session-scoped sleep command; and
- session observability records.

The clock-drift warning polls the closed node-status snapshot through the
published runner. Sentry, metrics, observability, push binding, and ZK recovery
bind to immutable session publications and clear or reject on sign-out.

Challenges, Explorer, and Leaderboard integration are intentionally absent
from Flutter; Social owns those product surfaces. The deferred legacy ZK
mechanics remain, but their native and completion calls are admitted through
the exact session runner.

## Drift alarms

Lints and surface scans are drift alarms, not lifecycle enforcement. The API
shape provides the enforcement. Before review, verify that production code has
no `SessionController`, `identityProvider`, token store, `RustBackendService`,
raw node/RPC generated module, public lifecycle bootstrap, or headless Flutter
owner. Regenerate FRB only from the curated `crate::mobile_api` input and delete
stale generated leaves that codegen no longer owns.

Keep tests compact: deterministic admission/drain ordering, focused bridge and
platform framing/apply checks, and the first real Social-to-Rust-to-Flutter
vertical slice. Do not recreate the retired architecture as per-feature
logout guards, mocks of database/runtime behavior, or reconciliation patches.
