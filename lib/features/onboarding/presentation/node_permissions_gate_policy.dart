import 'package:flutter/foundation.dart';

enum NodePermissionGateStep {
  notifications,
  exactAlarms,
  unrestrictedBackground,
}

@immutable
final class NodePermissionGateState {
  const NodePermissionGateState({
    required this.notificationsGranted,
    required this.hasWallet,
    required this.delegated,
    required this.exactAlarmsGranted,
    required this.unrestrictedBackgroundGranted,
  });

  factory NodePermissionGateState.conservative({required bool hasWallet}) {
    return NodePermissionGateState(
      notificationsGranted: false,
      hasWallet: hasWallet,
      delegated: false,
      exactAlarmsGranted: false,
      unrestrictedBackgroundGranted: false,
    );
  }

  final bool notificationsGranted;
  final bool hasWallet;
  final bool delegated;
  final bool exactAlarmsGranted;
  final bool unrestrictedBackgroundGranted;

  bool get requiresProducerPermissions => hasWallet && !delegated;

  NodePermissionGateStep? get nextStep {
    if (!notificationsGranted) {
      return NodePermissionGateStep.notifications;
    }
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
        other.notificationsGranted == notificationsGranted &&
        other.hasWallet == hasWallet &&
        other.delegated == delegated &&
        other.exactAlarmsGranted == exactAlarmsGranted &&
        other.unrestrictedBackgroundGranted == unrestrictedBackgroundGranted;
  }

  @override
  int get hashCode => Object.hash(
        notificationsGranted,
        hasWallet,
        delegated,
        exactAlarmsGranted,
        unrestrictedBackgroundGranted,
      );
}
