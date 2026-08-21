import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leaderboard provider whose fetch can be held open across an identity
/// change, the way a slow `/me/breakdown` response is.
class _SlowNotifier extends LeaderboardNotifier<String> {
  static final release = <Completer<String>>[];

  @override
  Future<String> fetch() {
    final gate = Completer<String>();
    release.add(gate);
    return gate.future;
  }

  @override
  bool watchDeps() => false;
}

final _slowProvider =
    AsyncNotifierProvider<_SlowNotifier, String?>(_SlowNotifier.new);

Identity _ready({required int participantId, required String address}) =>
    Identity(
      epoch: participantId,
      phase: IdentityPhase.ready,
      participantId: participantId,
      accountId: 'account-$participantId',
      address: address,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _SlowNotifier.release.clear();
    IdentitySnapshots.reset();
  });

  test('a response for the previous identity is never published', () async {
    IdentitySnapshots.publish(_ready(participantId: 1, address: 'ut1aaa'));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // `watchDeps` is false, so the build resolves to null without fetching.
    expect(await container.read(_slowProvider.future), isNull);

    final refresh = container.read(_slowProvider.notifier).silentRefresh();
    expect(_SlowNotifier.release, hasLength(1));

    // The user signs out (or a different user signs in) while the request is
    // still in flight. `silentRefresh` runs outside the `build` that
    // registered the identity watches, so nothing else drops this result.
    IdentitySnapshots.publish(_ready(participantId: 2, address: 'ut1bbb'));
    _SlowNotifier.release.single.complete('participant-1 points');
    await refresh;

    expect(container.read(_slowProvider).valueOrNull, isNull);
  });

  test('a response for the current identity is published as usual', () async {
    IdentitySnapshots.publish(_ready(participantId: 1, address: 'ut1aaa'));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(_slowProvider.future);

    final refresh = container.read(_slowProvider.notifier).silentRefresh();
    _SlowNotifier.release.single.complete('participant-1 points');
    await refresh;

    expect(container.read(_slowProvider).valueOrNull, 'participant-1 points');
  });
}
