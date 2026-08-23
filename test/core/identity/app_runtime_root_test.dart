import 'package:crypto_mobile_app/core/identity/session_host.dart';
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
      sessionHost: _hostFor(oldContainer),
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
}

SessionHostCoordinator _hostFor(ProviderContainer container) {
  final host = SessionHostCoordinator(
    createSuccessor: () async =>
        throw StateError('Terminal reset must not create a successor'),
  );
  host.mountInitial(container);
  return host;
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
