/// The authenticated participant profile returned by `GET /api/v3/mobile/me`.
class Me {
  const Me({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.displayName,
    this.isInWaitlist = false,
    this.hasPlatformAccess = false,
    this.bpRequested = false,
    this.bpReleased = false,
    this.github,
    this.x,
  });

  final int id;
  final String email;
  final bool emailConfirmed;
  final String? displayName;
  final bool isInWaitlist;

  /// Onboarding flow alignment: whether the account has been released onto
  /// the platform (SV home/social/build surfaces). Apps and the wallet work
  /// regardless.
  final bool hasPlatformAccess;

  /// The user asked to participate in block production.
  final bool bpRequested;

  /// An admin released this user's block-producer keys. Gates whether the
  /// native node is built with a producer key (see NodeService).
  final bool bpReleased;

  final String? github;
  final String? x;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: (json['id'] as num).toInt(),
        // Username-only platform accounts legitimately have no email.
        email: (json['email'] as String?) ?? '',
        emailConfirmed: json['email_confirmed'] == true,
        displayName: json['display_name'] as String?,
        isInWaitlist: json['is_in_waitlist'] == true,
        hasPlatformAccess: json['has_platform_access'] == true,
        bpRequested: json['bp_requested'] == true,
        bpReleased: json['bp_released'] == true,
        github: json['github'] as String?,
        x: json['x'] as String?,
      );
}
