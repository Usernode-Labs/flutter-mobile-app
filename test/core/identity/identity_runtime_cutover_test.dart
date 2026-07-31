import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/identity_runtime_restart_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

AuthSession _session(String token) => AuthSession(
      token: token,
      participant: const Participant(
        id: 1,
        email: 'a@b.com',
        emailConfirmed: true,
      ),
    );

Future<Identity> _settle(ProviderContainer container) async {
  await container.read(identityProvider.notifier).restore();
  return container.read(identityProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final restartService = IdentityRuntimeRestartService.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
    restartService.resetForTesting();
  });

  tearDown(() {
    restartService.resetForTesting();
    IdentitySnapshots.reset();
  });

  test('replacement containers preserve a monotonic identity epoch', () async {
    final first = ProviderContainer();
    final firstIdentity = await _settle(first);
    first.dispose();

    final replacement = ProviderContainer();
    addTearDown(replacement.dispose);
    final replacementIdentity = await _settle(replacement);

    expect(replacementIdentity.epoch, greaterThan(firstIdentity.epoch));
  });

  test(
      'an accepted login cutover leaves the old runtime closed and the '
      'replacement restores its durable target', () async {
    final restartRequested = Completer<void>();
    restartService.registerHandler((reason) async {
      restartRequested.complete();
    });

    final oldRuntime = ProviderContainer();
    await _settle(oldRuntime);
    await oldRuntime
        .read(identityProvider.notifier)
        .completeLogin(_session('sess-replacement'));

    final closedIdentity = oldRuntime.read(identityProvider);
    expect(closedIdentity.phase, IdentityPhase.transitioning);
    expect(closedIdentity.isAuthenticated, isFalse);
    expect(closedIdentity.allowsSigning, isFalse);
    expect(closedIdentity.allowsNodeStart, isFalse);
    await restartRequested.future;

    oldRuntime.dispose();
    restartService.unregisterHandler();

    final replacement = ProviderContainer();
    addTearDown(replacement.dispose);
    final restored = await _settle(replacement);

    expect(restored.phase, IdentityPhase.reconciling);
    expect(restored.participantId, 1);
    expect(restored.epoch, greaterThan(closedIdentity.epoch));
  });
}
