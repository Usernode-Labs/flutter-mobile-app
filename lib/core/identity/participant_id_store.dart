import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _participantIdKey = 'leaderboard:participant_id';

/// Reads the participant ID stored in the ACTIVE bucket (null when none).
Future<int?> loadParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(NetworkPrefs.prefixAccountKey(_participantIdKey));
}

/// Reads the participant ID stored in an explicit [bucket].
Future<int?> loadParticipantIdInBucket(String bucket) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs
      .getInt(NetworkPrefs.prefixAccountKeyFor(_participantIdKey, bucket));
}

/// Persist a participant ID into the ACTIVE bucket. Used by the bootstrap
/// identity override (test/dev tooling).
Future<void> saveParticipantId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(NetworkPrefs.prefixAccountKey(_participantIdKey), id);
}

/// Stage a participant ID in the guest bucket at login, before the account
/// reconcile has determined which account bucket it belongs in. Together
/// with the reconcile-pending marker this is the crash-recovery payload:
/// both are persisted BEFORE the session token becomes boot-restorable.
Future<void> stageParticipantIdInGuestBucket(int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    NetworkPrefs.prefixAccountKeyFor(
        _participantIdKey, NetworkPrefs.guestBucket),
    id,
  );
}

/// Remove a staged/leftover participant ID from the guest bucket so a guest
/// session can never resolve a previous authenticated user's ID.
Future<void> clearGuestParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(
    NetworkPrefs.prefixAccountKeyFor(
        _participantIdKey, NetworkPrefs.guestBucket),
  );
}

/// Install [participantId] into an explicit account [bucket] after the
/// reconcile confirmed the account belongs to that participant, and clean up
/// the guest-bucket staging copy — but ONLY when the staged value still
/// matches [participantId]. If another user logged in mid-reconcile, the
/// staged value is THEIR id and must be left for their own reconcile.
///
/// Idempotent and retry-safe: the destination write happens before the
/// staged copy is removed.
Future<void> installParticipantIdInBucket({
  required int participantId,
  required String bucket,
  String? network,
}) async {
  final prefs = await SharedPreferences.getInstance();
  String keyFor(String targetBucket) => network == null
      ? NetworkPrefs.prefixAccountKeyFor(_participantIdKey, targetBucket)
      : NetworkPrefs.prefixKeyWith(
          'acct:$targetBucket:$_participantIdKey',
          network,
        );
  await prefs.setInt(
    keyFor(bucket),
    participantId,
  );
  final guestKey = keyFor(NetworkPrefs.guestBucket);
  if (bucket != NetworkPrefs.guestBucket &&
      prefs.getInt(guestKey) == participantId) {
    await prefs.remove(guestKey);
  }
}
