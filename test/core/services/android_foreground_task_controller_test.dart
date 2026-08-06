import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an in-flight poll cannot borrow a successor authority', () async {
    const NodeRuntimeAuthority originalAuthority = (
      generation: 1,
      bindingFingerprint: 'binding-a',
    );
    const NodeRuntimeAuthority successorAuthority = (
      generation: 2,
      bindingFingerprint: 'binding-b',
    );
    final controller = AndroidForegroundTaskController.test(
      isAndroid: () => true,
      monitoringAuthority: successorAuthority,
    );

    final result = await controller.scheduleResumeAlarm(
      rustWakeTimeMs: 1000,
      reason: 'stale_poll',
      authority: originalAuthority,
    );

    expect(result.success, isFalse);
    expect(result.failureReason, 'runtime_authority_superseded');
  });
}
