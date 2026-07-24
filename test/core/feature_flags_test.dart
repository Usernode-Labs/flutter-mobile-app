import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/feature_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset loading preserves granular flag defaults', () async {
    // loadFromAssetIfAvailable must not clobber the granular default-on
    // behavior that compile-time rollout flags rely on.
    await FeatureFlags.loadFromAssetIfAvailable();
    expect(FeatureFlags.on('some.unknown.tag'), isTrue);
  });

  test('granular tags default on unless explicitly gated', () {
    expect(FeatureFlags.on('some.unknown.tag'), isTrue);
    expect(FeatureFlags.on('some.unknown.tag', defaultOn: false), isFalse);
  });
}
