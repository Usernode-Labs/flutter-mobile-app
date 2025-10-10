import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_core/build.dart';

void main() {
  testWidgets('SettingsScreen toggles theme mode and persists', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // Provide a fake BuildEnv to avoid touching flutter_rust_bridge in tests
    final fakeEnv = BuildEnv(
      time: 'now',
      version: '0.0.0-test',
      git: const GitBuildEnv(
        commitTime: 'now',
        commitHash: 'deadbeef',
        branch: 'test',
      ),
      cargo: const CargoBuildEnv(
        features: 'none',
        optLevel: 0,
        target: 'test',
        isDebug: true,
      ),
      rustc: const RustCBuildEnv(
        channel: 'stable',
        commitDate: 'now',
        commitHash: 'deadbeef',
        host: 'x86_64-apple-darwin',
        version: '1.0.0',
        llvmVersion: '0',
      ),
    );

    final container = ProviderContainer(overrides: [
      buildEnvProvider.overrideWithValue(fakeEnv),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));

    await tester.pumpAndSettle();

    // Tap Dark
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Tap Light
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
