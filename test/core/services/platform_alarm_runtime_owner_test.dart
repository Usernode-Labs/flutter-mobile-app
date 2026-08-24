import 'package:crypto_mobile_app/core/identity/runtime_owner.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.usernode.app/alarm');
  const ownerA = RuntimeOwner(
    sessionId: 'session-a',
    runtimeGeneration: 7,
    accountId: 'account-a',
    address: 'address-a',
  );
  const ownerB = RuntimeOwner(
    sessionId: 'session-b',
    runtimeGeneration: 1,
    accountId: 'account-b',
    address: 'address-b',
  );

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('privileged native events require the current complete runtime owner',
      () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    final service = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
      platform: TargetPlatform.android,
    )..configureRuntimeOwnerResolver(() => ownerA);

    expect(await service.initialize(), isTrue);
    var calls = 0;
    service.setNativeEventCallback((_, __) async {
      calls += 1;
      return true;
    });

    expect(
      await service.dispatchNativeEventForTesting(
        'android_alarm_fired',
        ownerB.toMap(),
      ),
      isFalse,
    );
    expect(
      await service.dispatchNativeEventForTesting(
        'android_alarm_fired',
        ownerA.toMap(),
      ),
      isTrue,
    );
    expect(
      await service.dispatchNativeEventForTesting(
        'android_exact_alarm_permission_granted',
        const {},
      ),
      isTrue,
    );
    expect(calls, 2);
  });

  test('Android alarm creation carries one complete owner at every handoff',
      () async {
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'hasPostNotificationsPermission' => true,
          'hasExactAlarmPermission' => true,
          'isBatteryOptimizationDisabled' => true,
          'scheduleExactAlarm' => true,
          _ => null,
        };
      },
    );
    final service = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
      platform: TargetPlatform.android,
    )..configureRuntimeOwnerResolver(() => ownerA);

    expect(await service.initialize(), isTrue);
    expect(await service.requestPermissions(), isTrue);
    expect(
      await service.scheduleAlarm(
        alarmId: 'slot-a',
        globalSlot: 9,
        delayMs: 1,
      ),
      isTrue,
    );

    final schedule = calls.singleWhere(
      (call) => call.method == 'scheduleExactAlarm',
    );
    final arguments = Map<String, dynamic>.from(schedule.arguments as Map);
    expect(arguments, containsPair('session_id', 'session-a'));
    expect(arguments, containsPair('runtime_generation', 7));
    expect(arguments, containsPair('account_id', 'account-a'));
    expect(arguments, containsPair('address', 'address-a'));
    final data = Map<String, dynamic>.from(arguments['data'] as Map);
    for (final entry in ownerA.toMap().entries) {
      expect(data, containsPair(entry.key, entry.value));
    }
  });
}
