class Participant {
  const Participant({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.displayName,
  });

  final int id;
  final String email;
  final bool emailConfirmed;
  final String? displayName;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] as num).toInt(),
        // Username-only platform accounts legitimately have no email.
        email: json['email']?.toString() ?? '',
        emailConfirmed: json['email_confirmed'] == true,
        displayName: json['display_name'] as String?,
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
