/// The user's access level, resolved by the backend (`/me` → `level`) with a
/// local fallback. Guest → Member → Operator, highest privilege wins.
enum UserLevel { guest, member, operator }

UserLevel userLevelFromString(String? value) {
  switch (value) {
    case 'operator':
      return UserLevel.operator;
    case 'member':
      return UserLevel.member;
    default:
      return UserLevel.guest;
  }
}

/// The authenticated participant profile returned by `GET /api/v3/mobile/me`.
class Me {
  const Me({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    required this.level,
    this.displayName,
    this.isInWaitlist = false,
    this.github,
    this.x,
  });

  final int id;
  final String email;
  final bool emailConfirmed;
  final UserLevel level;
  final String? displayName;
  final bool isInWaitlist;
  final String? github;
  final String? x;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        emailConfirmed: json['email_confirmed'] == true,
        level: userLevelFromString(json['level'] as String?),
        displayName: json['display_name'] as String?,
        isInWaitlist: json['is_in_waitlist'] == true,
        github: json['github'] as String?,
        x: json['x'] as String?,
      );
}

/// Resolves the user's level. Not authenticated → guest. Authenticated → the
/// backend `level` from [me] when available, otherwise a local derivation
/// (operator when an on-chain account exists, else member) used until `/me`
/// resolves or while offline.
UserLevel resolveUserLevel({
  required bool authenticated,
  required Me? me,
  required bool hasOnchainAccount,
}) {
  if (!authenticated) return UserLevel.guest;
  if (me != null) return me.level;
  return hasOnchainAccount ? UserLevel.operator : UserLevel.member;
}
