import 'package:flutter/foundation.dart';

/// Android block-production requirements only. Notification permission is
/// requested by the SV shell's own onboarding sheet, not by this gate.
enum NodePermissionGateStep {
  exactAlarms,
  unrestrictedBackground,
}

@immutable
final class NodePermissionGateState {
  const NodePermissionGateState({
    required this.hasWallet,
    required this.delegated,
    required this.exactAlarmsGranted,
    required this.unrestrictedBackgroundGranted,
  });

  factory NodePermissionGateState.conservative({required bool hasWallet}) {
    return NodePermissionGateState(
      hasWallet: hasWallet,
      delegated: false,
      exactAlarmsGranted: false,
      unrestrictedBackgroundGranted: false,
    );
  }

  final bool hasWallet;
  final bool delegated;
  final bool exactAlarmsGranted;
  final bool unrestrictedBackgroundGranted;

  bool get requiresProducerPermissions => hasWallet && !delegated;

  NodePermissionGateStep? get nextStep {
    if (!requiresProducerPermissions) return null;
    if (!exactAlarmsGranted) return NodePermissionGateStep.exactAlarms;
    if (!unrestrictedBackgroundGranted) {
      return NodePermissionGateStep.unrestrictedBackground;
    }
    return null;
  }

  bool get isSatisfied => nextStep == null;

  @override
  bool operator ==(Object other) {
    return other is NodePermissionGateState &&
        other.hasWallet == hasWallet &&
        other.delegated == delegated &&
        other.exactAlarmsGranted == exactAlarmsGranted &&
        other.unrestrictedBackgroundGranted == unrestrictedBackgroundGranted;
  }

  @override
  int get hashCode => Object.hash(
        hasWallet,
        delegated,
        exactAlarmsGranted,
        unrestrictedBackgroundGranted,
      );
}
