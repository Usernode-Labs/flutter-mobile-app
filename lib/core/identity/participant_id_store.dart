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
Future<bool> clearGuestParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixAccountKeyFor(
    _participantIdKey,
    NetworkPrefs.guestBucket,
  );
  await prefs.remove(key);
  await prefs.reload();
  return !prefs.containsKey(key);
}

/// Install [participantId] into an explicit account [bucket] after the
/// reconcile confirmed the account belongs to that participant, and clean up
/// the guest-bucket staging copy — but ONLY when the staged value still
/// matches [participantId]. The equality check makes recovery tolerant of
/// unrelated or corrupt guest-bucket residue; it is not an account handoff.
/// The destination write happens before cleanup, so retries are safe.
Future<void> installParticipantIdInBucket({
  required int participantId,
  required String bucket,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    NetworkPrefs.prefixAccountKeyFor(_participantIdKey, bucket),
    participantId,
  );
  final guestKey = NetworkPrefs.prefixAccountKeyFor(
    _participantIdKey,
    NetworkPrefs.guestBucket,
  );
  if (bucket != NetworkPrefs.guestBucket &&
      prefs.getInt(guestKey) == participantId) {
    await prefs.remove(guestKey);
  }
}
