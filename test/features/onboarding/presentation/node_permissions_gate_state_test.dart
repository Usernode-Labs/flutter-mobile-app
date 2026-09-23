import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.onhomeroom.app/alarm');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS never gates and never enters the native session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final runner = _RejectingSessionRunner();

    final state = await readNodePermissionGateState(_readySession(runner));

    expect(state.isSatisfied, isTrue);
    expect(runner.runCount, 0);
  });

  test('walletless Android sessions never enter the native session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final runner = _RejectingSessionRunner();
    final session = SessionFeatureAccess(
      identity: SessionIdentityProjection.ready(
        nativeRevision: '1',
        participantId: 1,
      ),
      operations: runner,
    );

    final state = await readNodePermissionGateState(session);

    expect(state.isSatisfied, isTrue);
    expect(runner.runCount, 0);
  });

  testWidgets('renders only producer steps, never a notifications step',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final runner = _RejectingSessionRunner();
    final session = _readySession(runner);
    final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);
    final theme = cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NodePermissionsGateScreen(
          session: session,
          initialState: const NodePermissionGateState(
            hasWallet: true,
            delegated: false,
            exactAlarmsGranted: false,
            unrestrictedBackgroundGranted: true,
          ),
          onSatisfied: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('Allow precise wake-ups'), findsOneWidget);
    expect(find.text('Enable notifications'), findsNothing);
    expect(find.text('Delegate instead'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NodePermissionsGateScreen(
          key: const ValueKey('background-step'),
          session: session,
          initialState: const NodePermissionGateState(
            hasWallet: true,
            delegated: false,
            exactAlarmsGranted: true,
            unrestrictedBackgroundGranted: false,
          ),
          onSatisfied: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow unrestricted background use'), findsOneWidget);
    expect(find.text('Delegate instead'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}

SessionFeatureAccess _readySession(SessionOperationRunner runner) {
  return SessionFeatureAccess(
    identity: SessionIdentityProjection.ready(
      nativeRevision: '1',
      participantId: 1,
      accountId: 'account',
      address: 'address',
      publicKey: 'public-key',
    ),
    operations: runner,
  );
}

final class _RejectingSessionRunner implements SessionOperationRunner {
  int runCount = 0;

  @override
  Future<T> run<T>(
    FutureOr<T> Function(SessionOperation operation) body,
  ) async {
    runCount++;
    throw const SessionAdmissionClosedException();
  }
}
