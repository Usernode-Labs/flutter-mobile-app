import 'package:crypto_mobile_app/core/identity/identity.dart';

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
