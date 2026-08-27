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

Definitive absence has a separate command. Uncertain evidence makes no Rust or
vault mutation and remains retryable. Warm wake evidence contains credential
reference, generation, commitment, and request fingerprint, never the account
scalar. A scalar is decrypted and staged only for a proven cold installation.

Rust returns one of five bounded outcomes: keep foreground, schedule exact,
cancel/retire, retry later, or request the one-time cold credential install.
Ready-derived directives retain the exact session admission until the platform
finishes applying the OS effect and completes the one-use apply claim.

## Android platform behavior

The refactor changes callback ownership, not alarm policy. The existing
platform components remain responsible for their existing jobs:

- `AlarmScheduler` uses the existing exact `AlarmManager` path and trigger
  calculations.
- `AlarmReceiver` records diagnostics, validates the opaque scheduled selector,
  and hands a valid exact callback to the native coordinator.
- `SlotMonitoringService` retains foreground-service, notification, wakelock,
  and local monitoring behavior.
- `AlarmWatchdogScheduler` and `AlarmWatchdogWorker` retain periodic and
  one-time WorkManager recovery behavior.
- boot, package replacement, and exact-alarm permission broadcasts retain their
  existing platform handling.

The coordinator compare-applies a directive against the exact Ready revision
and wake identity. Scheduling and selector persistence happen before Rust is
told the effect succeeded. If completion is rejected because logout or a
successor raced, only the newly applied effect is rolled back. Stale A cannot
cancel B's alarm or stop B's foreground service.

Headless Flutter (`BackgroundAlarmEngine`, its plugin registrant, and
`headlessMain`) is intentionally removed.

The manifest permissions, `AlarmManager` choice, wake timing, notifications,
foreground-service policy, WorkManager cadence, and local polling cadence are
otherwise unchanged. The simultaneous `USE_EXACT_ALARM` /
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

Ordinary foreground/local producer polls reuse Rust's durable E/E+1/E+2 policy
and exact local vault evidence. They do not perform an authenticated Social
GET every polling interval. Policy refresh is bounded to establishment,
delegation mutation, and relevant recovery boundaries. When a server read is
made, exact credential-invalid 401 evidence compare-retires that record;
transport failures and other uncertain responses are write-free.

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
