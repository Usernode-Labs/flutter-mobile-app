import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/session_runtime_boundary.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _probeProvider = Provider<_RuntimeProbe>((ref) {
  throw StateError('A runtime probe override is required');
});

final _graphProvider = Provider<_RuntimeProbe>((ref) {
  final probe = ref.watch(_probeProvider)..mount();
  ref.onDispose(probe.dispose);
  return probe;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    SessionRuntimeBoundary.instance.resetForTesting();
  });

  tearDown(SessionRuntimeBoundary.instance.resetForTesting);

  testWidgets(
      'hard transition removes the old graph and blocks replacement on drain',
      (tester) async {
    final ledger = _RuntimeLedger();
    final oldProbe = _RuntimeProbe('old', ledger);
    final freshProbe = _RuntimeProbe('fresh', ledger);
    final backendBootstrap = Completer<void>();
    final reconcileDrainStarted = Completer<void>();
    final allowReconcileDrain = Completer<void>();
    final shutdownStarted = Completer<void>();
    final allowShutdown = Completer<void>();
    var replacementCalls = 0;
    var oldRuntimeDisposedBeforeReplacement = false;

    final oldContainer = ProviderContainer(overrides: [
      _probeProvider.overrideWithValue(oldProbe),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => _BlockingNodeAccountReconciler(
          ref,
          reconcileDrainStarted,
          allowReconcileDrain.future,
        ),
      ),
    ]);

    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: oldContainer,
      initialBackendBootstrap: backendBootstrap.future,
      shutdownRuntime: () async {
        shutdownStarted.complete();
        await allowShutdown.future;
      },
      replacementFactory: () async {
        replacementCalls += 1;
        oldRuntimeDisposedBeforeReplacement = !oldProbe.mounted;
        return _containerFor(freshProbe);
      },
      child: const _RuntimeView(),
    ));
    expect(find.text('old'), findsOneWidget);

    final persistenceStarted = Completer<void>();
    final restart = SessionRuntimeBoundary.instance.replace<void>(
      change: SessionRuntimeChange.logout,
      transition: (_) async => persistenceStarted.complete(),
    );

    await _pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
    );
    expect(oldProbe.mounted, isTrue);
    expect(reconcileDrainStarted.isCompleted, isFalse);
    expect(shutdownStarted.isCompleted, isFalse);
    expect(persistenceStarted.isCompleted, isFalse);
    expect(replacementCalls, 0);

    backendBootstrap.complete();
    await _pumpUntil(tester, () => reconcileDrainStarted.isCompleted);
    expect(shutdownStarted.isCompleted, isFalse);
    expect(persistenceStarted.isCompleted, isFalse);
    expect(replacementCalls, 0);

    allowReconcileDrain.complete();
    await _pumpUntil(tester, () => shutdownStarted.isCompleted);
    expect(persistenceStarted.isCompleted, isFalse);
    expect(replacementCalls, 0);

    allowShutdown.complete();
    await _pumpUntil(tester, () => persistenceStarted.isCompleted);
    await _pumpUntil(tester, () => find.text('fresh').evaluate().isNotEmpty);
    await restart;

    expect(oldRuntimeDisposedBeforeReplacement, isTrue);
    expect(ledger.maximumMounted, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(ledger.mounted, 0);
  });

  testWidgets('persistence failure drains and leaves the app fail-closed',
      (tester) async {
    final ledger = _RuntimeLedger();
    final oldProbe = _RuntimeProbe('old', ledger);
    var replacementCalls = 0;
    var shutdownCalls = 0;

    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: _containerFor(oldProbe),
      shutdownRuntime: () async => shutdownCalls += 1,
      replacementFactory: () async {
        replacementCalls += 1;
        return _containerFor(_RuntimeProbe('unexpected', ledger));
      },
      child: const _RuntimeView(),
    ));

    final restart = SessionRuntimeBoundary.instance.replace<void>(
      change: SessionRuntimeChange.logout,
      transition: (_) async => throw StateError('persistence failed'),
    );
    final failure = expectLater(restart, throwsStateError);
    await _pumpUntil(
      tester,
      () =>
          find.textContaining('Please close and reopen').evaluate().isNotEmpty,
    );
    await failure;

    expect(oldProbe.mounted, isFalse);
    expect(shutdownCalls, 1);
    expect(replacementCalls, 0);
    expect(ledger.mounted, 0);
  });
}

ProviderContainer _containerFor(_RuntimeProbe probe) => ProviderContainer(
      overrides: [_probeProvider.overrideWithValue(probe)],
    );

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

class _RuntimeView extends ConsumerWidget {
  const _RuntimeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(home: Text(ref.watch(_graphProvider).name));
  }
}

class _RuntimeLedger {
  int mounted = 0;
  int maximumMounted = 0;
}

class _BlockingNodeAccountReconciler extends NodeAccountReconciler {
  _BlockingNodeAccountReconciler(
    super.ref,
    this._drainStarted,
    this._allowDrain,
  );

  final Completer<void> _drainStarted;
  final Future<void> _allowDrain;

  @override
  Future<void> drain() async {
    _drainStarted.complete();
    await _allowDrain;
  }
}

class _RuntimeProbe {
  _RuntimeProbe(this.name, this.ledger);

  final String name;
  final _RuntimeLedger ledger;
  bool mounted = false;

  void mount() {
    if (mounted) return;
    mounted = true;
    ledger.mounted += 1;
    if (ledger.mounted > ledger.maximumMounted) {
      ledger.maximumMounted = ledger.mounted;
    }
  }

  void dispose() {
    if (!mounted) return;
    mounted = false;
    ledger.mounted -= 1;
  }
}
