import 'dart:async';

import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/services/identity_runtime_restart_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _runtimeProbeProvider = Provider<_RuntimeProbe>((ref) {
  throw StateError('A runtime probe override is required');
});

final _runtimeGraphProvider = Provider<_RuntimeProbe>((ref) {
  final probe = ref.watch(_runtimeProbeProvider);
  probe.mountProviderGraph();
  ref.onDispose(probe.disposeProviderGraph);
  return probe;
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final restartService = IdentityRuntimeRestartService.instance;

  setUp(restartService.resetForTesting);

  tearDown(restartService.resetForTesting);

  testWidgets(
    'hard cutover unmounts and disposes the old runtime before creating the replacement',
    (tester) async {
      final ledger = _RuntimeLedger();
      final oldProbe = _RuntimeProbe('old', ledger);
      final newProbe = _RuntimeProbe('new', ledger);
      final oldContainer = _containerFor(oldProbe);
      final allowRetiringBootstrap = Completer<void>();
      final replacementFactoryCalled = Completer<void>();
      final allowReplacementCreation = Completer<void>();

      await tester.pumpWidget(
        AppRuntimeRoot(
          initialContainer: oldContainer,
          initialBackendBootstrap: allowRetiringBootstrap.future,
          replacementContainerFactory: () async {
            ledger.events.add('replacement-factory-called');
            expectSync(oldProbe.consumerMounted, isFalse);
            expectSync(oldProbe.providerGraphMounted, isFalse);
            expectSync(ledger.activeConsumers, 0);
            expectSync(ledger.activeProviderGraphs, 0);
            expectSync(
              () => oldContainer.read(_runtimeProbeProvider),
              throwsStateError,
            );
            replacementFactoryCalled.complete();

            await allowReplacementCreation.future;
            return _containerFor(newProbe);
          },
          child: const _RuntimeConsumer(),
        ),
      );

      expect(find.text('old'), findsOneWidget);
      expect(
        ledger.events,
        ['old-provider-mounted', 'old-consumer-mounted'],
      );

      expect(restartService.request(reason: 'test-cutover'), isTrue);
      await _pumpUntil(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
      );
      expect(replacementFactoryCalled.isCompleted, isFalse);
      expect(oldProbe.consumerMounted, isFalse);
      expect(oldProbe.providerGraphMounted, isTrue);

      // A provider-free blocker is visible while already-started singleton
      // work drains. Only then may the old container be disposed.
      allowRetiringBootstrap.complete();
      await _pumpUntil(tester, () => replacementFactoryCalled.isCompleted);

      expect(find.byType(_RuntimeConsumer), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        ledger.events,
        [
          'old-provider-mounted',
          'old-consumer-mounted',
          'old-consumer-unmounted',
          'old-provider-disposed',
          'replacement-factory-called',
        ],
      );
      expect(ledger.activeConsumers, 0);
      expect(ledger.activeProviderGraphs, 0);

      allowReplacementCreation.complete();
      await _pumpUntil(tester, () => find.text('new').evaluate().isNotEmpty);

      expect(find.text('new'), findsOneWidget);
      expect(oldProbe.consumerMounted, isFalse);
      expect(oldProbe.providerGraphMounted, isFalse);
      expect(newProbe.consumerMounted, isTrue);
      expect(newProbe.providerGraphMounted, isTrue);
      expect(ledger.maximumActiveConsumers, 1);
      expect(ledger.maximumActiveProviderGraphs, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(ledger.activeConsumers, 0);
      expect(ledger.activeProviderGraphs, 0);
    },
  );
}

ProviderContainer _containerFor(_RuntimeProbe probe) => ProviderContainer(
      overrides: [
        _runtimeProbeProvider.overrideWithValue(probe),
        identityProvider.overrideWith(
          (ref) => SessionController(
            tokenStore: AuthTokenStore(),
            guestFlag: AuthGuestFlag(),
            repository: AuthRepository(),
            suspendNode: () async {},
          ),
        ),
      ],
    );

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

class _RuntimeConsumer extends ConsumerStatefulWidget {
  const _RuntimeConsumer();

  @override
  ConsumerState<_RuntimeConsumer> createState() => _RuntimeConsumerState();
}

class _RuntimeConsumerState extends ConsumerState<_RuntimeConsumer> {
  _RuntimeProbe? _probe;

  @override
  Widget build(BuildContext context) {
    final probe = ref.watch(_runtimeGraphProvider);
    if (!identical(_probe, probe)) {
      _probe?.unmountConsumer();
      _probe = probe..mountConsumer();
    }
    return MaterialApp(home: Text(probe.name));
  }

  @override
  void dispose() {
    _probe?.unmountConsumer();
    super.dispose();
  }
}

class _RuntimeLedger {
  final events = <String>[];
  int activeConsumers = 0;
  int activeProviderGraphs = 0;
  int maximumActiveConsumers = 0;
  int maximumActiveProviderGraphs = 0;
}

class _RuntimeProbe {
  _RuntimeProbe(this.name, this.ledger);

  final String name;
  final _RuntimeLedger ledger;
  bool consumerMounted = false;
  bool providerGraphMounted = false;

  void mountConsumer() {
    consumerMounted = true;
    ledger.activeConsumers += 1;
    ledger.maximumActiveConsumers =
        ledger.activeConsumers > ledger.maximumActiveConsumers
            ? ledger.activeConsumers
            : ledger.maximumActiveConsumers;
    ledger.events.add('$name-consumer-mounted');
  }

  void unmountConsumer() {
    if (!consumerMounted) return;
    consumerMounted = false;
    ledger.activeConsumers -= 1;
    ledger.events.add('$name-consumer-unmounted');
  }

  void mountProviderGraph() {
    providerGraphMounted = true;
    ledger.activeProviderGraphs += 1;
    ledger.maximumActiveProviderGraphs =
        ledger.activeProviderGraphs > ledger.maximumActiveProviderGraphs
            ? ledger.activeProviderGraphs
            : ledger.maximumActiveProviderGraphs;
    ledger.events.add('$name-provider-mounted');
  }

  void disposeProviderGraph() {
    if (!providerGraphMounted) return;
    providerGraphMounted = false;
    ledger.activeProviderGraphs -= 1;
    ledger.events.add('$name-provider-disposed');
  }
}
