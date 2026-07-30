import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

const _participantIdKey = 'leaderboard:participant_id';

/// Reads the persisted participant ID from SharedPreferences (network-prefixed).
/// Written by [AuthStatusNotifier.completeLogin] from the v4 session's
/// `user.id`; null until the user has signed in at least once.
final participantIdProvider = FutureProvider<int?>((ref) async {
  // Re-read storage on every auth transition so a fresh login's id is
  // picked up without an app restart (and a logout's stale id isn't
  // served to a new session).
  ref.watch(authStatusProvider);
  return loadParticipantId();
});

/// Persist a participant ID to SharedPreferences (network-prefixed).
Future<void> saveParticipantId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixAccountKey(_participantIdKey);
  await prefs.setInt(key, id);
}

/// Stage a participant ID in the guest bucket, regardless of which bucket is
/// active. Called at login: the signed-in user's account bucket may not
/// exist yet (fresh install) or may not be active yet (a previous user's
/// account is still the active one), so writing to the ACTIVE bucket could
/// pollute another identity's data. The post-sign-in account reconcile moves
/// the staged value into the right bucket ([migrateGuestParticipantId]).
Future<void> stageParticipantIdInGuestBucket(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixAccountKeyFor(
    _participantIdKey,
    NetworkPrefs.guestBucket,
  );
  await prefs.setInt(key, id);
}

/// Remove a staged/leftover participant ID from the guest bucket so a guest
/// session can never resolve a previous authenticated user's ID. Called on
/// logout and when the user explicitly continues as guest.
Future<void> clearGuestParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixAccountKeyFor(
    _participantIdKey,
    NetworkPrefs.guestBucket,
  );
  await prefs.remove(key);
}

/// Loads the persisted participant ID directly from storage.
Future<int?> loadParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixAccountKey(_participantIdKey);
  return prefs.getInt(key);
}

/// Moves a participant ID persisted under the guest bucket into the currently
/// active account bucket.
///
/// A login that happens before any on-chain account exists writes the ID
/// under [NetworkPrefs.guestBucket]; once the account is provisioned and its
/// bucket becomes active, the ID must move so (a) it resolves after restarts
/// and (b) a later guest session cannot read the previous user's ID out of
/// the guest bucket.
///
/// Idempotent and retry-safe: reads from the explicitly addressed guest key,
/// writes the destination first, and removes the source only after the write
/// succeeds. A no-op when the guest bucket is active (nowhere to move to) or
/// when the source is empty. An existing destination value is overwritten —
/// the guest-bucket copy is always the most recent login's ID.
Future<void> migrateGuestParticipantId() async {
  final destKey = NetworkPrefs.prefixAccountKey(_participantIdKey);
  final sourceKey = NetworkPrefs.prefixAccountKeyFor(
    _participantIdKey,
    NetworkPrefs.guestBucket,
  );
  if (destKey == sourceKey) return; // Guest bucket still active.

  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getInt(sourceKey);
  if (value == null) return;

  await prefs.setInt(destKey, value);
  await prefs.remove(sourceKey);
}

/// In-memory season/event selection shared across all leaderboard providers.
final seasonEventContextProvider = StateProvider<SeasonEventContext>(
  (ref) => const SeasonEventContext(),
);

/// Set of event IDs the participant has data in (from season-scope breakdown).
///
/// Updated by the bootstrap or breakdown provider whenever season-scope
/// data is available. Used by the event picker to show ended events
/// the user participated in.
final participantEventIdsProvider = StateProvider<Set<int>>(
  (ref) => const {},
);
