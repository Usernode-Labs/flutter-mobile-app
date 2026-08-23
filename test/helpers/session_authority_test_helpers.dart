import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';

export 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart'
    show AuthCredentialLease;

AuthCredentialLease testCredentialLease({
  required int epoch,
  required String token,
  String? sessionId,
  String? credentialRef,
  int? credentialGeneration,
  IdentityPhase phase = IdentityPhase.ready,
}) =>
    SessionAuthorityGateway.captureCredential(
      identity: Identity(
        epoch: epoch,
        phase: phase,
        sessionId: sessionId ?? 'test-session-$epoch',
        credentialRef: credentialRef ?? 'test-credential-$epoch',
        credentialGeneration: credentialGeneration ?? 1,
      ),
      token: token,
    );
