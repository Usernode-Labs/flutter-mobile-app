import 'package:crypto_mobile_app/features/onboarding/presentation/node_permissions_gate_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NodePermissionGateState state({
    bool hasWallet = true,
    bool delegated = false,
    bool exactAlarms = true,
    bool unrestrictedBackground = true,
  }) {
    return NodePermissionGateState(
      hasWallet: hasWallet,
      delegated: delegated,
      exactAlarmsGranted: exactAlarms,
      unrestrictedBackgroundGranted: unrestrictedBackground,
    );
  }

  test('delegation removes exact-alarm and background requirements', () {
    final value = state(
      delegated: true,
      exactAlarms: false,
      unrestrictedBackground: false,
    );

    expect(value.nextStep, isNull);
    expect(value.isSatisfied, isTrue);
  });

  test('walletless sessions do not require producer settings', () {
    final value = state(
      hasWallet: false,
      exactAlarms: false,
      unrestrictedBackground: false,
    );

    expect(value.isSatisfied, isTrue);
  });

  test('self-producing wallets require exact alarms before background access',
      () {
    final missingBoth = state(
      exactAlarms: false,
      unrestrictedBackground: false,
    );
    final missingBackground = state(
      unrestrictedBackground: false,
    );

    expect(missingBoth.nextStep, NodePermissionGateStep.exactAlarms);
    expect(
      missingBackground.nextStep,
      NodePermissionGateStep.unrestrictedBackground,
    );
  });

  test('self-producing wallet passes only when every setting is enabled', () {
    final value = state();

    expect(value.isSatisfied, isTrue);
  });
}
