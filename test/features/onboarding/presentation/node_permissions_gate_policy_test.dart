import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NodePermissionGateState state({
    required bool notifications,
    bool hasWallet = true,
    bool delegated = false,
    bool exactAlarms = true,
    bool unrestrictedBackground = true,
  }) {
    return NodePermissionGateState(
      notificationsGranted: notifications,
      hasWallet: hasWallet,
      delegated: delegated,
      exactAlarmsGranted: exactAlarms,
      unrestrictedBackgroundGranted: unrestrictedBackground,
    );
  }

  test('notifications are mandatory even when the wallet is delegated', () {
    final value = state(
      notifications: false,
      delegated: true,
      exactAlarms: false,
      unrestrictedBackground: false,
    );

    expect(value.nextStep, NodePermissionGateStep.notifications);
    expect(value.isSatisfied, isFalse);
  });

  test('delegation removes exact-alarm and background requirements', () {
    final value = state(
      notifications: true,
      delegated: true,
      exactAlarms: false,
      unrestrictedBackground: false,
    );

    expect(value.nextStep, isNull);
    expect(value.isSatisfied, isTrue);
  });

  test('walletless sessions require notifications but not producer settings',
      () {
    final missingNotifications = state(
      notifications: false,
      hasWallet: false,
      exactAlarms: false,
      unrestrictedBackground: false,
    );
    final notificationsGranted = state(
      notifications: true,
      hasWallet: false,
      exactAlarms: false,
      unrestrictedBackground: false,
    );

    expect(
      missingNotifications.nextStep,
      NodePermissionGateStep.notifications,
    );
    expect(notificationsGranted.isSatisfied, isTrue);
  });

  test('self-producing wallets require exact alarms before background access',
      () {
    final missingBoth = state(
      notifications: true,
      exactAlarms: false,
      unrestrictedBackground: false,
    );
    final missingBackground = state(
      notifications: true,
      unrestrictedBackground: false,
    );

    expect(missingBoth.nextStep, NodePermissionGateStep.exactAlarms);
    expect(
      missingBackground.nextStep,
      NodePermissionGateStep.unrestrictedBackground,
    );
  });

  test('self-producing wallet passes only when every setting is enabled', () {
    final value = state(notifications: true);

    expect(value.isSatisfied, isTrue);
  });
}
