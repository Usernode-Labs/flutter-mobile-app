# Background Block Production

Background production is owned by the native Usernode runtime and each mobile
OS. Flutter is interactive glue; it does not start a headless engine, own a
second node, or reconstruct session authority for an alarm.

See `docs/identity-lifecycle-invariants.md` for the hard login/logout boundary.

## Authority boundary

The native vault retains the exact installed credential and durable Ready
revision. A background callback may present only bounded evidence for that
record. It cannot obtain the bearer, account scalar, Flutter process root, or a
generic Rust client.

On Android, all callback sources enter
`NativeProducerWakeCoordinator.kt` on one serialized worker. A Present request
uses two closed JNI calls:

1. stage the exact `UNPW` request and receive an opaque one-use claim; then
2. consume that claim to run the wake and receive a closed `UNPR` directive.

`UNPR` response version 2 keeps the directive closed while carrying display
metadata for awake states: a production/evaluation target has its global slot
and platform-adjusted wall-clock time, the successor barrier has only the
locally produced height, and the mempool guard has its applicable transaction
count. No best-tip, credential, key, or generic status payload is exposed.

Definitive absence has a separate command. Uncertain evidence makes no Rust or
vault mutation and remains retryable. Warm wake evidence contains credential
reference, generation, commitment, and request fingerprint, never the account
scalar. A scalar is decrypted and staged only for a proven cold installation.

Rust returns one of five bounded outcomes: keep foreground, schedule exact,
cancel/retire, retry later, or request the one-time cold credential install.
Ready-derived directives retain the exact session admission until the platform
finishes applying the OS effect and completes the one-use apply claim.

## Android platform behavior

The existing platform components remain responsible for their existing jobs:

- `AlarmScheduler` uses the existing exact `AlarmManager` path and trigger
  calculations.
- `AlarmReceiver` records diagnostics, validates the opaque scheduled selector,
  and hands a valid exact callback to the native coordinator.
- `SlotMonitoringService` retains foreground-service, notification, wakelock,
  and local monitoring behavior.
- `AlarmWatchdogScheduler` and `AlarmWatchdogWorker` retain periodic
  WorkManager recovery and one-time recovery when there is no simultaneous
  direct native callback.
- boot and package replacement start the foreground service and submit one
  direct native callback; they do not also enqueue a duplicate immediate
  WorkManager callback. Exact-alarm permission broadcasts retain their
  one-time WorkManager recovery.

The coordinator compare-applies a directive against the exact Ready revision
and wake identity. Scheduling and selector persistence happen before Rust is
told the effect succeeded. If completion is rejected because logout or a
successor raced, only the newly applied effect is rolled back. Stale A cannot
cancel B's alarm or stop B's foreground service.

Sleepy mode now supplies the scheduling decision. A Flutter policy write calls
Rust first and then asks this coordinator to reconcile Android ownership. Rust
returns `KeepForeground` for every awake guard and `ScheduleExact` only for the
exact Redux `Eligible` plan. The alarm is scheduled at the local-wall-clock
equivalent of `wake_at_ms`, five minutes before the target slot.

While the runtime is awake, notification `1001` is the ongoing foreground
service notification and is derived from the exact Rust reason: evaluating
slots, production scheduled soon (with slot and target time), producing,
waiting for a successor block (with produced height), processing applicable
transactions, or an explicit retry/disabled state. Android no longer invents
"slot 0" for this path. When an exact sleep commits, notification `1001` and
the partial wakelock are removed together. Notification `1002` remains as an
ongoing informational "block production wake scheduled" notification showing
the target slot and wake date/time; it is removed when that alarm is delivered,
cancelled, replaced without another tracked alarm, or the session is retired.
For `ProductionSoon`, the service also arms a bounded Rust state poll at the
Rust-provided target timestamp so a short production interval is not lost
between 30-second policy polls. It shows `Producing a block` only after Rust
reports `production_in_progress`; clock time alone never fabricates that state.
The node driver publishes that live phase after each bounded Redux pass, so the
target poll can read it without waiting behind the complete production action
tree. While that phase is live, Rust requests a one-second follow-up instead
of the normal 30-second poll so the notification settles promptly afterward.

Android mobile nodes require the alarm transaction to commit before automatic
pause. The completion JNI call revalidates the same plan and settled node
ingress; Rust rejects a raced disable, transaction, manual command, or target
change. Android then rolls back only the attempted alarm and retains foreground
retry ownership. After success it stops `SlotMonitoringService` and releases
the native partial wakelock. It does not kill the application process, so the
Rust timer remains a second wake path while the process survives.

At delivery, the receiver validates the durable selector before the coordinator
acquires a partial wakelock and starts `SlotMonitoringService`. The coordinator
then enters Rust directly over JNI, clears the matching automatic pause without
disabling sleepy mode, and recomputes policy. No Flutter engine is needed.

Headless Flutter (`BackgroundAlarmEngine`, its plugin registrant, and
`headlessMain`) is intentionally removed.

The manifest permissions, `AlarmManager` choice, notifications,
foreground-service policy, WorkManager cadence, and 30-second foreground poll
cadence are otherwise unchanged. The simultaneous `USE_EXACT_ALARM` /
`SCHEDULE_EXACT_ALARM` policy question remains a separate TODO; it is not part
of the lifecycle refactor.

## iOS platform behavior

iOS mirrors the credential/root/session and staged-wake authority in
`NativeSessionPlatform.swift`, `NativeSessionProtocol.swift`, and
`NativeSessionVault.swift`. Existing background callbacks are best-effort;
there is no Android-style exact scheduler, alarm journal, or claimed exact wake
time.

Keeping an already-active foreground runtime is a real applied effect.
Unsupported schedule/retry effects are reported to Rust as failures. They do
not make a valid foreground login fail, and they do not pretend that iOS
scheduled work it did not schedule.

If a warm callback proves the exact credential definitively absent, Rust closes
the session and iOS clears the compare-matching vault revision. Flutter then
closes its matching runner and publishes a permanently rejecting signed-out
surface until natural relaunch. The app does not exit or crash.

## Policy refresh and network use

When a normal E/E+1/E+2 snapshot is available, ordinary foreground/local
producer polls reuse Rust's durable policy and exact local vault evidence. They
do not perform an authenticated Social GET every polling interval. Policy
refresh is otherwise bounded to establishment, delegation mutation, and
relevant recovery boundaries. When a server read is made, exact
credential-invalid 401 evidence compare-retires that record; transport failures
and other uncertain responses are write-free.

An authenticated `503 node_epoch_unavailable` response is handled explicitly:
the platform sends Rust a closed `UNEA` marker alongside the matching vault
evidence. Rust uses its own current clock epoch and assigns the local managed
producer for that epoch only. Android/iOS never choose an epoch, and no other
HTTP failure enables production. Once VRF preparation freezes that assignment,
it remains authoritative through the end of that epoch; later server policy
can govern subsequent epochs but cannot revoke the frozen fallback mid-epoch.
The exact Ready session remembers the allowed epoch in memory so its 30-second
local polls do not repeat the same server request. That marker is epoch-exact
and is discarded on a cold process. The fallback is not persisted as a
fabricated E/E+1/E+2 server snapshot. A real server assignment for the same
epoch takes precedence over the in-memory fallback; a cold process or a later
epoch performs another authenticated refresh.

Cold Flutter startup reconstructs the local process root and exact Ready
session before building the trusted UI. Producer wake, policy refresh, and
sleepy reconciliation start after the first Flutter frame. Session operations
remain admission-gated during that reconciliation, but the WebView and app
navigation are not covered by a process-wide input barrier.

## Diagnostics and verification

Android continues to record scheduled, receiver, foreground-service, and
delivery timestamps through `AlarmStateStore`. The Flutter diagnostics UI may
read platform state, but it is not a lifecycle or scheduling owner.

Verification should stay focused on:

- exact frame/selector decoding;
- stale callback rejection;
- compare-apply and completion ordering;
- rollback of only a newly created OS effect; and
- cold/present/absent/uncertain evidence classification.

Do not build a second lifecycle coordinator, alarm journal, or per-feature
logout guard to test background production.
