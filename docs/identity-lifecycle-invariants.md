# Identity and session lifecycle invariants

This document describes the architecture enforced by the current
implementation. The Rust journal is the source of session and network
authority. Flutter exposes that authority through one disposable session host;
it does not maintain a second lifecycle state machine.

The implementation is intentionally mechanism-based. Session replacement,
immutable capabilities, exact-owner storage and the native runtime supervisor
cover late asynchronous work globally. Adding a logout-specific gate or a
service-by-service cleanup list is a design change, not a routine fix.

## Owners

There are three lifecycle owners:

1. The Rust session-authority journal owns the durable state and transition
   sequence. Its states are `LoggedOut`, `Activating`, `Ready`, `Retiring` and
   `Closed`.
2. The Flutter application root owns exactly one independent
   `ProviderContainer` for the current session host. It disposes the complete
   container before publishing a successor.
3. The Rust runtime supervisor owns the one node runtime and its scheduling
   resources. Runtime commands carry the exact journal-issued owner.

`SessionController` serializes UI transition requests and mirrors the journal
record into `Identity`. It is the only writer of `IdentitySnapshots` and the
active account bucket. Those mirrors route UI work; they do not grant durable
authority by themselves.

Process-lifetime services may be injected into a session container only as
explicit adapters. They cannot retain a session provider or manufacture a
session owner.

## Session transitions

Every session ID and transition ID is globally unique and never reused.
Commands compare the complete expected journal revision before advancing it.
A stale command can neither complete a newer transition nor erase its result.

Activation reserves its rollback record before external work. It installs the
credential and reconciles the exact backend-provisioned account before the
journal becomes `Ready`. A crash resumes the recorded phase.

Retirement uses one replayable command:

1. detach and dispose the current Flutter session host;
2. CAS the exact `Ready(A)` record to `Retiring(A)` with its reserved logged-out
   successor;
3. revoke A's runtime, scheduling and credential authority;
4. clear A's WebView session data and posted notifications;
5. CAS to the reserved `LoggedOut(B)` record;
6. construct and publish the fresh logged-out host.

Logout, credential rejection, missing credentials, guest choice and user
replacement all use this path. The process remains reusable, so a user can log
in again without restarting the application.

If a replayable transition step fails, the application stays on one in-process
recovery surface and retries that same journal phase. It never admits a
partially retired or partially activated session.

## Authority at effect boundaries

Durable and privileged work captures one complete immutable owner before its
first suspension point.

Authenticated HTTP requests carry an `AuthCredentialLease` containing the
session ID, credential reference and credential revision. A workflow request
also supplies its owning application session; the request is sent only when
the two match.

Account access requires an `AccountCapability` with a private constructor. It
pins:

```text
(session_id, user_namespace, network, account_id, address, bucket, key_ref)
```

Registry enumeration, active-account resolution, key lookup and signing all
require that capability. Account activation uses a separate reconciliation
lease because no Ready account capability exists yet.

Pending workflow rows are addressed by:

```text
(network, account_bucket, app_session_id, operation_id)
```

Recovery scans only the current exact `Ready` session prefix and selects the
newest owned operation deterministically. A late A save, outcome or exact
delete remains under A's key and cannot affect B, including a same-user login
that uses the same account bucket. Retired rows are inert; physical cleanup is
only reclamation.

The WebView document and privileged callbacks are owned by `(session_id,
realm_id)`. Detaching the old host quarantines the complete realm. Shared
browser storage is cleared before a successor realm is mounted.

An operation accepted by A may finish after A retires. Its immutable owner may
still address A's data, but the disposed container cannot publish into B. New
work enters only through B's fresh host and capabilities. Logout does not wait
for ordinary network, proof or UI continuations.

## Runtime and scheduling

Every native/runtime command carries the exact `RuntimeOwner` from the Ready
journal record. The supervisor serializes validation, node state and scheduling
effects under one command owner. Retirement of A runs through that same owner,
so work already admitted for A completes before revocation while queued stale
commands fail validation.

Cold Android recovery reads the journal directly and starts only an enabled,
exact `Ready` owner. Logged-out, retiring, disabled, malformed and stale owners
remain inert. Headless recovery uses explicit journal network and namespace
values; it does not construct a UI provider container or consult ambient
preferences.

## Migration and retained data

Journal absence is the sole one-time migration marker. Bootstrap keeps session
and native authority closed, clears obsolete authority artifacts, and creates a
fresh `LoggedOut` journal record atomically. A crash safely repeats that work.

Migration never deletes wallet keys, account metadata, account history,
workflow rows or audit history. Legacy workflow rows without a trustworthy
application-session owner remain stored but cannot resume. After login,
ordinary reconciliation may associate one retained account only when both the
retained key and backend-provisioned key prove the same network/address
binding; it does not move or delete the legacy registry.

## Network and season changes

The journal owns the network. A logged-out network change records a fresh
logged-out owner. An authenticated change retires the session first and adopts
the new network only in the final logged-out record. An operational restart may
then rebuild process-wide network services, but restart is not a session-safety
mechanism.

A season rollover with the same exact account binding updates the season
baseline and keeps the current session/runtime lease. A different binding
performs no local account mutation, retires normally and requires fresh login
and activation.

## Enforcement

The following are correctness boundaries:

- Rust journal CAS and crash-recovery tests;
- deterministic scheduler tests with delays at every authority and supervisor
  boundary;
- loom exploration of runtime owner, journal and sink ordering;
- disposable-host and WebView realm tests;
- credential, account capability and exact workflow-owner tests;
- static lints that keep identity and bucket publication single-writer.

Tests are derived from these public invariants before implementation. A change
that reorders runtime retirement, widens capability construction, reintroduces
ambient durable routing or adds case-specific session cleanup must amend the
design and its Tier-1 packet first.
