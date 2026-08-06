import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/src/rust/observability.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.usernode.app/alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('lease reads cannot transfer scheduling authority', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getNodeRecoveryLease' => <String, Object?>{
            'enabled': true,
            'generation': 2,
            'bindingFingerprint': 'binding-b',
          },
        'scheduleExactAlarm' => true,
        _ => null,
      };
    });

    final service = PlatformAlarmService.test(
      observability: _observability(),
      isAndroid: () => true,
      initialized: true,
      permissionsGranted: true,
    );
    const NodeRuntimeAuthority originalAuthority = (
      generation: 1,
      bindingFingerprint: 'binding-a',
    );

    final observed = await service.getNodeRecoveryLease();
    expect(observed.generation, 2);

    expect(
      await service.scheduleAlarm(
        alarmId: 'fg_resume',
        globalSlot: 42,
        delayMs: 1000,
        authority: originalAuthority,
      ),
      isTrue,
    );

    final schedule = calls.singleWhere(
      (call) => call.method == 'scheduleExactAlarm',
    );
    final arguments = (schedule.arguments as Map).cast<Object?, Object?>();
    final data = (arguments['data'] as Map).cast<Object?, Object?>();
    expect(data['recoveryGeneration'], 1);
    expect(data['bindingFingerprint'], 'binding-a');
  });
}

ObservabilityReportingService _observability() =>
    ObservabilityReportingService.test(
      collector: _NoopMobileContextCollector(),
      canRecord: () => true,
      record: ({
        required FlutterObservabilityKind kind,
        required String event,
        String? payloadJson,
      }) =>
          const FlutterObservabilityRecordResult(
        queued: true,
        discarded: false,
      ),
    );

class _NoopMobileContextCollector implements MobileContextSnapshotCollector {
  @override
  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};
}
