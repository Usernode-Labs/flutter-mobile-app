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
        email: json['email'] as String,
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

class CheckEmailResult {
  const CheckEmailResult({required this.exists, required this.passwordSet});

  final bool exists;
  final bool passwordSet;

  factory CheckEmailResult.fromJson(Map<String, dynamic> json) =>
      CheckEmailResult(
        exists: json['exists'] == true,
        passwordSet: json['password_set'] == true,
      );
}

class OtpTicket {
  const OtpTicket({required this.setPasswordToken});

  final String setPasswordToken;

  factory OtpTicket.fromJson(Map<String, dynamic> json) =>
      OtpTicket(setPasswordToken: json['set_password_token'] as String);
}
