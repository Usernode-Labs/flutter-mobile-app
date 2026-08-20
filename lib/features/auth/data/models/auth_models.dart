import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';

class Participant {
  const Participant({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.displayName,
    this.identityHash,
  });

  final int id;
  final String email;
  final bool emailConfirmed;
  final String? displayName;

  /// The server-issued namespace this user's local storage is prefixed with
  /// (`sha256(id + email)`, 16 hex characters). Stable for the life of the
  /// account, so two users sharing a device never read each other's local
  /// accounts. Null against a server that predates the field — the app then
  /// keeps using the unnamespaced legacy keys.
  final String? identityHash;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] as num).toInt(),
        // Username-only platform accounts legitimately have no email.
        email: json['email']?.toString() ?? '',
        emailConfirmed: json['email_confirmed'] == true,
        displayName: json['display_name'] as String?,
        identityHash: normalizeIdentityHash(json['identity_hash']),
      );
}

class AuthSession {
  const AuthSession({required this.token, required this.participant});

  final String token;
  final Participant participant;

  // v4 returns `{token, user}` — the SPEC §4.8 rename of the source's
  // participant vocabulary. The inner object's fields are unchanged. The
  // v3 `participant` key is not accepted: v3 backends are unsupported
  // (fresh onboarding requires the v4-only /wallet/provision endpoint).
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        participant: Participant.fromJson(
          json['user'] as Map<String, dynamic>,
        ),
      );
}
