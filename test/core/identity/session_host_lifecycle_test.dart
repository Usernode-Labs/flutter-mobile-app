import 'dart:async';

import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _probeProvider = Provider<_HostProbe>((ref) {
  throw StateError('A host probe override is required');
});

final _mountedProbeProvider = Provider<_HostProbe>((ref) {
  final probe = ref.watch(_probeProvider)..mount();
  ref.onDispose(probe.dispose);
  return probe;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A is disposed before retirement and B mounts only afterward',
      (tester) async {
    final ledger = _HostLedger();
    final oldProbe = _HostProbe('A', ledger);
    final successorProbe = _HostProbe('B', ledger);
    final retirementMayFinish = Completer<void>();
    final host = SessionHostCoordinator(
      createSuccessor: () async => _containerFor(successorProbe),
    )..mountInitial(_containerFor(oldProbe));

    await tester.pumpWidget(AppRuntimeRoot(
      sessionHost: host,
      child: const _HostView(),
    ));
    expect(find.text('A'), findsOneWidget);
    expect(oldProbe.mounted, isTrue);

    final replacement = host.replace(
      retire: () async {
        expect(oldProbe.mounted, isFalse);
        await retirementMayFinish.future;
      },
    );

    expect(oldProbe.mounted, isFalse);
    await tester.pump();
    expect(find.text('Finishing session…'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(successorProbe.mounted, isFalse);

    retirementMayFinish.complete();
    expect(await replacement, isNotNull);
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
    expect(successorProbe.mounted, isTrue);
    expect(ledger.maximumMounted, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retryable failure stays in-process and replays the same work',
      (tester) async {
    final ledger = _HostLedger();
    final oldProbe = _HostProbe('A', ledger);
    final successorProbe = _HostProbe('B', ledger);
    var attempts = 0;
    final host = SessionHostCoordinator(
      createSuccessor: () async => _containerFor(successorProbe),
    )..mountInitial(_containerFor(oldProbe));

    await tester.pumpWidget(AppRuntimeRoot(
      sessionHost: host,
      child: const _HostView(),
    ));

    final replacement = host.replace(
      retire: () async {
        attempts += 1;
        if (attempts == 1) {
          throw const SessionRetirementRetryableException(
            'injected realm cleanup failure',
          );
        }
      },
    );
    await tester.pump();

    expect(oldProbe.mounted, isFalse);
    expect(find.text('Session recovery needed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(successorProbe.mounted, isFalse);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(await replacement, isNotNull);
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('B'), findsOneWidget);
    expect(successorProbe.mounted, isTrue);
    expect(ledger.maximumMounted, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

ProviderContainer _containerFor(_HostProbe probe) => ProviderContainer(
      overrides: [_probeProvider.overrideWithValue(probe)],
    );

class _HostView extends ConsumerWidget {
  const _HostView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(home: Text(ref.watch(_mountedProbeProvider).name));
  }
}

class _HostLedger {
  int mounted = 0;
  int maximumMounted = 0;
}

class _HostProbe {
  _HostProbe(this.name, this.ledger);

  final String name;
  final _HostLedger ledger;
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
