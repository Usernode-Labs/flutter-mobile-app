import 'package:crypto_mobile_app/core/identity/identity.dart';

/// Closes admission to bridge methods that expose or mutate session-owned
/// wallet state while the web session is handed off to native.
///
/// This is intentionally only an admission gate. Calls already admitted are
/// not cancelled or generation-fenced; that more complex edge case is tracked
/// separately.
class SessionHandoffGate {
  SessionHandoffGate({bool initiallyBlocked = false})
      : _blocked = initiallyBlocked;

  static const sessionScopedMethods = <String>{
    'getNodeAddress',
    'sendTransaction',
    'signMessage',
    'txObserved',
    'getWalletState',
    'getTransactionRecords',
  };

  bool _blocked;

  bool get isBlocked => _blocked;

  void begin() => _blocked = true;

  void admit() => _blocked = false;

  bool blocks(String method) =>
      _blocked && sessionScopedMethods.contains(method);
}

Map<String, dynamic> sessionBoundAuthStatus(
  Identity identity, {
  required String reconciliationStatus,
}) =>
    {
      'phase': identity.phase.name,
      'address':
          identity.phase == IdentityPhase.ready ? identity.address : null,
      'participantId': identity.participantId,
      'epoch': identity.epoch,
      'reconciliationStatus': reconciliationStatus,
    };

bool sessionScopeMatchesReadyIdentity(
  Identity identity, {
  required int participantId,
  required int epoch,
  required String address,
}) =>
    identity.phase == IdentityPhase.ready &&
    identity.participantId == participantId &&
    identity.epoch == epoch &&
    identity.address == address;
