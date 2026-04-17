import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults automatic app sleep to enabled with no stored preference',
      () async {
    SharedPreferences.setMockInitialValues({});

    await AppSleepStateStore.load();

    expect(AppSleepStateStore.isEnabled, isTrue);
    expect(AppSleepStateStore.isSleeping, isFalse);
  });

  test('respects stored automatic app sleep preference', () async {
    SharedPreferences.setMockInitialValues({
      'app_sleep:is_enabled': false,
      'app_sleep:is_sleeping': true,
    });

    await AppSleepStateStore.load();

    expect(AppSleepStateStore.isEnabled, isFalse);
    expect(AppSleepStateStore.isSleeping, isFalse);
  });
}
