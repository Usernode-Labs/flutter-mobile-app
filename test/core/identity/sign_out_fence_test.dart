import 'dart:io';

import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    NetworkPrefs.setActiveBucket(null, guest: true);
    root = await Directory.systemTemp.createTemp('usernode-fence-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  DurableSignOutFence fence({Directory? directory}) =>
      DurableSignOutFence(directory: () async => directory ?? root);

  test('a raised fence is on disk and survives a fresh process', () async {
    expect(await fence().isRaised(), isFalse);

    expect(await fence().raise(), isTrue);

    // A different instance is what the next boot sees. The point of the file
    // (rather than a preference, whose own docs decline to guarantee that a
    // completed write reached disk) is exactly this.
    expect(await fence().isRaised(), isTrue);
    expect(root.listSync(), isNotEmpty);
  });

  test('lowering removes it', () async {
    await fence().raise();
    expect(await fence().lower(), isTrue);
    expect(await fence().isRaised(), isFalse);
  });

  test('raising is idempotent', () async {
    expect(await fence().raise(), isTrue);
    expect(await fence().raise(), isTrue);
    expect(await fence().isRaised(), isTrue);
    await fence().lower();
    expect(await fence().isRaised(), isFalse);
  });

  test('an unwritable location reports failure rather than a phantom fence',
      () async {
    // A fence the sign-out cannot make durable must be reported as such: the
    // caller then refuses to clear the bearer and escalates, instead of
    // proceeding on a pair that is no longer crash-atomic.
    final missing = DurableSignOutFence(
      directory: () async => throw const FileSystemException('no app dir'),
    );

    expect(await missing.raise(), isFalse);
    // And because raising can never succeed there, a boot must not read the
    // failure as "a sign-out was interrupted" — that would sign the user out
    // on every single launch.
    expect(await missing.isRaised(), isFalse);
  });

  test('the fence is scoped to its network', () async {
    await fence().raise();
    expect(await fence().isRaised(), isTrue);

    final other = Directory('${root.path}/other')..createSync();
    expect(await fence(directory: other).isRaised(), isFalse);
  });
}
