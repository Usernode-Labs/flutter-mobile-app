import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sleeps after idle timeout and wakes on user interaction',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final wakeReasons = <String>[];
    final persistedValues = <bool>[];

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (reason) async => wakeReasons.add(reason),
      persistSleepState: (value) async => persistedValues.add(value),
    );

    await service.initializeForInteractiveApp();
    expect(service.isSleeping, isFalse);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.idleTimeout]);

    service.recordUserInteraction(source: 'test_tap');
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(wakeReasons, ['user_interaction:test_tap']);
    expect(persistedValues, [false, true, false]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('lifecycle inactive sleeps immediately and resumed wakes',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    final wakeReasons = <String>[];

    final service = AppSleepService.forTest(
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (reason) async => wakeReasons.add(reason),
      persistSleepState: (_) async {},
      initialLifecycleState: AppLifecycleState.resumed,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.lifecycleInactive]);

    await service.handleLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(wakeReasons, ['lifecycle_resumed']);

    service.dispose();
    await tester.pump();
  });

  testWidgets('idle timeout does not sleep while wakelock is held',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      idleTimeout: const Duration(seconds: 1),
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
    );

    await service.initializeForInteractiveApp();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.isSleeping, isTrue);
    expect(sleepReasons, [AppSleepReason.idleTimeout]);

    service.dispose();
    await tester.pump();
  });

  testWidgets('lifecycle inactive does not sleep while wakelock is held',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];

    final service = AppSleepService.forTest(
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => true,
      initialLifecycleState: AppLifecycleState.resumed,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    service.dispose();
    await tester.pump();
  });

  testWidgets('inactive sleep retries until wakelock is released',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
      inactiveWakelockRetryInterval: const Duration(seconds: 1),
      initialLifecycleState: AppLifecycleState.resumed,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

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

  testWidgets('inactive sleep retry stops once app is no longer inactive',
      (tester) async {
    final sleepReasons = <AppSleepReason>[];
    var wakelockHeld = true;

    final service = AppSleepService.forTest(
      onSleep: (reason) async => sleepReasons.add(reason),
      onWake: (_) async {},
      persistSleepState: (_) async {},
      isWakelockHeld: () async => wakelockHeld,
      inactiveWakelockRetryInterval: const Duration(seconds: 1),
      initialLifecycleState: AppLifecycleState.resumed,
    );

    await service.initializeForInteractiveApp();
    await service.handleLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    await service.handleLifecycleStateChanged(AppLifecycleState.resumed);
    wakelockHeld = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(service.isSleeping, isFalse);
    expect(sleepReasons, isEmpty);

    service.dispose();
    await tester.pump();
  });
}
