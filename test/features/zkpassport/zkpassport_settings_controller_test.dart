import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('facematch setter returns and reloads the persisted value', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(zkPassportFlowControllerProvider);

    expect(await controller.getFacematchStrict(), isTrue);

    final saved = await controller.setFacematchStrict(false);

    expect(saved, isFalse);
    expect(await controller.getFacematchStrict(), isFalse);
    expect(
      (await container.read(zkPassportSettingsProvider.future)).facematchStrict,
      isFalse,
    );
  });
}
