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
6. Rust clears only the matching automatic pause, preserving sleepy policy, and
   recomputes the full Redux sleepy decision.
7. The coordinator compare-applies the closed Rust directive.
8. For a Ready-derived directive it reports apply success/failure exactly once,
   releasing the retained Rust admission only after the platform transaction.

No Flutter engine is started in this flow.

## Schedule transaction

For `ScheduleExact`, the coordinator:

1. receives the exact Redux `SleepyPlan` translated to local wall-clock time;
2. validates the Ready revision and prior selector;
3. schedules the replacement with the existing `AlarmScheduler` policy;
4. persists the replacement selector;
5. performs exact prior-alarm cleanup with compare guards;
6. completes the Rust apply claim, which revalidates the same plan and settled
   event/RPC ingress before applying `NodeControlAction::Pause`; and
7. stops monitoring/releases the wakelock only when the just-applied selector
   still belongs to the same revision.

The successful schedule publishes one persistent informational notification
with the target global slot and the exact local wake date/time. Delivery and
cancel paths remove the corresponding tracked alarm and clear that notification
once no scheduled alarm remains. A replacement is installed before its prior
alarm is cancelled, so cancelling the prior selector cannot erase the new
schedule's notification.

If scheduling fails, Rust is not told success and the foreground runtime stays
active. If completion is rejected by a raced sleepy disable, manual command,
transaction/RPC ingress, target change, logout, or successor, the replacement
is compare-rolled back and a concurrently published successor is untouched.

## Other callback sources

- `AlarmWatchdogWorker` invokes the same coordinator from its existing
  WorkManager worker.
- `SlotMonitoringService` uses the same closed callback for its existing local
  monitoring cadence. Its ongoing foreground notification uses the closed Rust
  reason and details instead of a synthetic slot zero: evaluating slots,
  production scheduled soon, producing, waiting for a successor, pending
  applicable transactions, or retry/disabled state.
- boot and package replacement retain the foreground-service and direct native
  callback paths without enqueueing a duplicate immediate WorkManager run;
  the periodic watchdog remains armed.
- Every Android sleepy enable/disable write is followed by a coordinator pass.
- interactive foreground resume is submitted only by the private Dart
  composition root after cold recovery/adoption. Initial reconciliation starts
  after the first Flutter frame, and `MainActivity.onResume` does not submit a
  competing wake.

## Logout

Flutter first closes admission and drains session A. Native logout then commits
the boundary, and platform retirement compare-clears A's selector, alarm,
watchdog, service, wakelock, and application incarnation. A reply-loss retry is
idempotent. A non-null mismatched Ready revision is rejected; it is never
treated as already cleared.

## Platform policy

Android uses the Rust sleepy target and the existing exact-alarm permission,
`AlarmManager.RTC_WAKEUP` / `setExactAndAllowWhileIdle`, notification,
foreground-service, and watchdog/WorkManager machinery. The foreground poll
cadence remains 30 seconds. Broader alarm cleanup and the simultaneous
`USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` choice remain separate work.

The ownership invariant is: an awake native runtime has both the foreground
service and partial wakelock; a committed automatic sleep has neither. The
separate scheduled-wake notification is informational and owns no process or
wakelock.
