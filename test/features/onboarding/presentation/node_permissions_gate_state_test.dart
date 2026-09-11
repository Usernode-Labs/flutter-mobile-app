import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.usernode.app/alarm');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'missing notifications gate before native session admission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'hasPostNotificationsPermission' ? false : null,
      );
      final alarms = PlatformAlarmService.test(
        observability: ObservabilityReportingService.instance,
      );
      final runner = _RejectingSessionRunner();
      final session = SessionFeatureAccess(
        identity: SessionIdentityProjection.ready(
          nativeRevision: '1',
          participantId: 1,
          accountId: 'account',
          address: 'address',
          publicKey: 'public-key',
        ),
        operations: runner,
      );

      final state = await readNodePermissionGateState(
        session,
        alarmService: alarms,
      );

      expect(state.nextStep, NodePermissionGateStep.notifications);
      expect(state.notificationsGranted, isFalse);
      expect(runner.runCount, 0);
    },
  );

  testWidgets('renders notifications as the mandatory first step',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'hasPostNotificationsPermission' ? false : null,
    );
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
            notificationsGranted: false,
            hasWallet: true,
            delegated: false,
            exactAlarmsGranted: true,
            unrestrictedBackgroundGranted: true,
          ),
          onSatisfied: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('Enable notifications'), findsOneWidget);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('Delegate instead'), findsNothing);
    expect(runner.runCount, 0);

    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'hasPostNotificationsPermission' ? true : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NodePermissionsGateScreen(
          key: const ValueKey('background-step'),
          session: session,
          initialState: const NodePermissionGateState(
            notificationsGranted: true,
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
