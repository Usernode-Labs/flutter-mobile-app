import 'dart:async';

import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a scoped sign-out waits for every already accepted transition',
      () async {
    final ran = <String>[];
    final sleepEntered = Completer<void>();
    final releaseSleep = Completer<void>();
    final service = AppSleepService.forTest(
      idleTimeout: const Duration(minutes: 5),
      onSleep: (reason) async {
        ran.add('sleep:${reason.name}');
        if (!sleepEntered.isCompleted) sleepEntered.complete();
        await releaseSleep.future;
      },
      onWake: (reason) async => ran.add('wake:$reason'),
      persistSleepState: (_) async {},
      isWakelockHeld: () async => false,
      useWakelockTransitionFlow: false,
    );
    addTearDown(service.dispose);

    // One transition is running and one is already accepted behind it.
    final running = service.sleep(reason: AppSleepReason.idleTimeout);
    await sleepEntered.future;
    final queued = service.wake(reason: 'queued');

    var closed = false;
    final close = service.closeForSignOut().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse,
        reason: 'the boundary must not report done mid-transition');

    releaseSleep.complete();
    await running;
    await queued;
    await close;

    expect(closed, isTrue);
    expect(ran, ['sleep:idleTimeout', 'wake:queued']);
  });

  testWidgets('a scoped sign-out cancels timers but keeps the user preference',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => false,
      useWakelockTransitionFlow: false,
    );
    addTearDown(service.dispose);

    await service.initializeForInteractiveApp();

    // The sleep service sits outside the node coordinator by design, so the
    // sign-out teardown has to stand it down explicitly: its timers and resume
    // flags were armed while the signed-out user's node was running.
    await tester.runAsync(service.closeForSignOut);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(sleepReasons, isEmpty, reason: 'the idle timer was cancelled');
    // Reversible, unlike closeForTerminalReset: the user's automatic-sleep
    // preference belongs to the device, and the next session re-arms.
    expect(service.isEnabled, isTrue);
  });

  testWidgets('does not sleep before wakelock release transition',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final persistedValues = <bool>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (value) async => persistedValues.add(value),
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();
    expect(service.isSleeping, isFalse);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.idleTimeout]);
    expect(persistedValues, [false, true]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('released wakelock sleeps once inactivity is confirmed',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
      initialLifecycleState: AppLifecycleState.resumed,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.lifecycleInactive]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('sleeping app wakes on user interaction once resumed',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final wakeReasons = <String>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (reason) async => wakeReasons.add(reason),
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();
    wakelockHeld = false;
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.lifecycleInactive]);

    // Interaction while backgrounded (not resumed) must not wake the node.
    service.recordUserInteraction(source: 'test_tap');
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(wakeReasons, isEmpty);

    // Sleep no longer covers the UI, so once the app is foregrounded any
    // interaction is the wake gesture.
    await service.handleLifecycleStateChanged(AppLifecycleState.resumed);
    service.recordUserInteraction(source: 'test_tap');
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(wakeReasons, [AppSleepService.manualUiWakeReason]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('sleeping app wakes on wakelock reacquire', (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final wakeReasons = <String>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (reason) async => wakeReasons.add(reason),
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();
    wakelockHeld = false;
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.lifecycleInactive]);

    wakelockHeld = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(wakeReasons, ['wakelock_acquired:poll']);

    service.dispose();
    await tester.pump();
  });

  testWidgets('wakelock reacquire clears pending sleep before inactivity',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 2),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();
    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    wakelockHeld = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    service.dispose();
    await tester.pump();
  });

  testWidgets('automatic sleep stays off until it is enabled', (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final persistedEnabledValues = <bool>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      persistSleepEnabled: (value) async => persistedEnabledValues.add(value),
      isWakelockHeld: () async => wakelockHeld,
      initiallyEnabled: false,
    );

    await service.initializeForInteractiveApp();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    await service.setEnabled(true);
    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.idleTimeout]);
    expect(persistedEnabledValues, [true]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('automatic sleep disabled ignores lifecycle sleep triggers',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
      initiallyEnabled: false,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);
    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    service.dispose();
    await tester.pump();
  });

  testWidgets('disabling automatic sleep wakes a sleeping app', (tester) async {
    final wakeReasons = <String>[];
    final persistedEnabledValues = <bool>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      wakelockMonitorInterval: const Duration(seconds: 1),
      onSleep: (_) async {},
      onWake: (reason) async => wakeReasons.add(reason),
      persistSleepState: (_) async {},
      persistSleepEnabled: (value) async => persistedEnabledValues.add(value),
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();
    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isTrue);

    await service.setEnabled(false);
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(wakeReasons, ['automatic_sleep_disabled']);
    expect(persistedEnabledValues, [false]);

    service.dispose();
    await tester.pump();
  });
}
