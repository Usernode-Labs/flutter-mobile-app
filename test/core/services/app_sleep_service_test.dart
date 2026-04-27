import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('sleeping app wakes only on wakelock reacquire', (tester) async {
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

    await service.handleLifecycleStateChanged(AppLifecycleState.resumed);
    service.recordUserInteraction(source: 'test_tap');
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(wakeReasons, isEmpty);

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
