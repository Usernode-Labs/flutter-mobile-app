import 'package:crypto_mobile_app/core/identity/identity.dart';

/// Separates authenticated services from wallet-owned services while the web
/// session is handed off to native.
///
/// A validated bearer is enough for Social push, but wallet reads, signing and
/// node control stay closed until account reconciliation confirms the wallet
/// belongs to the same participant and identity epoch.
class SessionHandoffGate {
  SessionHandoffGate({bool initiallyBlocked = false})
      : _authenticatedBlocked = initiallyBlocked,
        _walletBlocked = initiallyBlocked;

  static const walletScopedMethods = <String>{
    'getNodeAddress',
    'sendTransaction',
    'signMessage',
    'txObserved',
    'getWalletState',
    'manageStaking',
    'getTransactionRecords',
  };

  static const authenticatedScopedMethods = <String>{
    'getSocialPushState',
    'setSocialPushEnabled',
    'claimPendingSocialNotification',
    'ackPendingSocialNotification',
  };

  bool _authenticatedBlocked;
  bool _walletBlocked;
  int? _participantId;
  int? _epoch;

  bool get isAuthenticatedBlocked => _authenticatedBlocked;
  bool get isWalletBlocked => _walletBlocked;

  void begin() {
    _authenticatedBlocked = true;
    _walletBlocked = true;
    _participantId = null;
    _epoch = null;
  }

  bool admitAuthenticated(Identity identity) {
    final participantId = identity.participantId;
    if (!identity.isAuthenticated || participantId == null) return false;
    _authenticatedBlocked = false;
    _walletBlocked = true;
    _participantId = participantId;
    _epoch = identity.epoch;
    return true;
  }

  bool admitWallet(Identity identity) {
    if (!authenticates(identity) || identity.phase != IdentityPhase.ready) {
      return false;
    }
    _walletBlocked = false;
    return true;
  }

  void restrictWallet(Identity identity) {
    if (authenticates(identity)) _walletBlocked = true;
  }

  bool admitAnonymous() {
    _authenticatedBlocked = false;
    _walletBlocked = false;
    _participantId = null;
    _epoch = null;
    return true;
  }

  bool authenticates(Identity identity) =>
      !_authenticatedBlocked &&
      identity.isAuthenticated &&
      identity.participantId == _participantId &&
      identity.epoch == _epoch;

  bool blocks(String method) =>
      (_authenticatedBlocked && authenticatedScopedMethods.contains(method)) ||
      (_walletBlocked && walletScopedMethods.contains(method));
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
