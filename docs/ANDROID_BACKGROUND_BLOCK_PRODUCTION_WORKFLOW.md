# Android Background Block Production Workflow

This is the Android-specific execution map. The policy and security invariants
are documented in `BACKGROUND_PRODUCTION.md` and
`identity-lifecycle-invariants.md`.

## Exact alarm callback

1. `AlarmReceiver` records the existing delivery diagnostics.
2. It rejects a missing, malformed, stale-incarnation, or stale opaque wake
   selector before acquiring runtime ownership.
3. Under `NativeProducerWakeCoordinator` serialization, the exact selector is
   revalidated, then the existing wakelock and foreground service are acquired.
4. The native vault supplies Present, definitive-absent, or Uncertain evidence.
5. Present evidence is staged into Rust and consumed through a one-use wake
   claim. Absence uses the separate terminal command. Uncertainty returns a
   retry without shared mutation.
6. The coordinator compare-applies the closed Rust directive.
7. For a Ready-derived directive it reports apply success/failure exactly once,
   releasing the retained Rust admission only after the platform transaction.

No Flutter engine is started in this flow.

## Schedule transaction

For `ScheduleExact`, the coordinator:

1. validates the Ready revision and prior selector;
2. schedules the replacement with the existing `AlarmScheduler` policy;
3. persists the replacement selector;
4. performs exact prior-alarm/foreground cleanup with compare guards;
5. completes the Rust apply claim; and
6. stops monitoring/releases the wakelock only when the just-applied selector
   still belongs to the same revision.

If scheduling fails, Rust is not told success and the foreground runtime stays
active. If completion is rejected, the replacement is compare-rolled back and
a concurrently published successor is untouched.

## Other callback sources

- `AlarmWatchdogWorker` invokes the same coordinator from its existing
  WorkManager worker.
- `SlotMonitoringService` uses the same closed callback for its existing local
  monitoring cadence.
- boot and package replacement retain the existing one-time WorkManager,
  foreground-service, and direct native callback paths.
- interactive foreground resume is submitted only by the private Dart
  composition root after cold recovery/adoption. `MainActivity.onResume` does
  not submit a competing wake.

## Logout

Flutter first closes admission and drains session A. Native logout then commits
the boundary, and platform retirement compare-clears A's selector, alarm,
watchdog, service, wakelock, and application incarnation. A reply-loss retry is
idempotent. A non-null mismatched Ready revision is rejected; it is never
treated as already cleared.

## Deliberately unchanged policy

This refactor does not change exact-alarm permissions, manifest declarations,
`AlarmManager` APIs, trigger timing, notifications, foreground-service policy,
WorkManager behavior, or monitoring cadence. Broader alarm cleanup and the
`USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` choice remain separate work.
