import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('terminal reset disposes the graph and never creates a successor',
      (tester) async {
    final ledger = _RuntimeLedger();
    final oldProbe = _RuntimeProbe('old', ledger);
    final oldContainer = _containerFor(oldProbe);

    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: oldContainer,
      child: const _RuntimeView(),
    ));
    expect(find.text('old'), findsOneWidget);
    expect(oldProbe.mounted, isTrue);

    AppResetService.instance.enterTerminalSurfaceForTesting();
    await tester.pump();
    await tester.pump();

    expect(find.text('Reset complete'), findsOneWidget);
    expect(find.text('Close and reopen Usernode to continue.'), findsOneWidget);
    expect(find.text('old'), findsNothing);
    expect(oldProbe.mounted, isFalse);
    expect(ledger.mounted, 0);
    expect(ledger.maximumMounted, 1);

    // A duplicate terminal signal is idempotent and cannot rebuild a graph.
    AppResetService.instance.enterTerminalSurfaceForTesting();
    await tester.pump();
    expect(find.text('Reset complete'), findsOneWidget);
    expect(ledger.mounted, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('terminal reset surface states the session-expired cause',
      (tester) async {
    final ledger = _RuntimeLedger();
    final probe = _RuntimeProbe('old', ledger);

    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: _containerFor(probe),
      child: const _RuntimeView(),
    ));

    AppResetService.instance.enterTerminalSurfaceForTesting('session_expired');
    await tester.pump();
    await tester.pump();

    expect(find.text('Session expired'), findsOneWidget);
    expect(
      find.text('Your session is no longer valid, so Usernode signed you out '
          'and cleared local data. Close and reopen Usernode to continue.'),
      findsOneWidget,
    );
    expect(find.text('Reset complete'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('terminal reset surface states the logout cause', (tester) async {
    final ledger = _RuntimeLedger();
    final probe = _RuntimeProbe('old', ledger);

    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: _containerFor(probe),
      child: const _RuntimeView(),
    ));

    AppResetService.instance.enterTerminalSurfaceForTesting('logout');
    await tester.pump();
    await tester.pump();

    expect(find.text('Signed out'), findsOneWidget);
    expect(
      find.text('You signed out, and your local data was cleared. '
          'Close and reopen Usernode to continue.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

ProviderContainer _containerFor(_RuntimeProbe probe) => ProviderContainer(
      overrides: [_probeProvider.overrideWithValue(probe)],
    );

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
