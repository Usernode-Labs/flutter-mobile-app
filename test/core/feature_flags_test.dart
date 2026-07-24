import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/feature_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabledFeatures =
      String.fromEnvironment('ENABLED_FEATURES', defaultValue: '');
  final shellEnabledFromEnv = enabledFeatures
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .contains('shell.sv');

  test('SV shell mode follows its opt-in compile-time flag', () {
    // The full-screen SV shell (app-as-SV-chrome migration) must stay
    // opt-in: it replaces the native tab shell on /home, so an accidental
    // default-on would ship the migration to everyone. Enable explicitly
    // via ENABLED_FEATURES=shell.sv or assets/feature_flags.json.
    expect(FeatureFlags.svShellEnabled, shellEnabledFromEnv);
  });

  test('asset loading preserves compile-time granular rollout flags', () async {
    await FeatureFlags.loadFromAssetIfAvailable();
    expect(FeatureFlags.svShellEnabled, shellEnabledFromEnv);
  });

  test('granular tags default on unless explicitly gated', () {
    // Documents the asymmetry svShellEnabled relies on: unknown tags are
    // default-on, so the shell flag must always pass defaultOn: false.
    expect(FeatureFlags.on('some.unknown.tag'), isTrue);
    expect(FeatureFlags.on('some.unknown.tag', defaultOn: false), isFalse);
  });
}
