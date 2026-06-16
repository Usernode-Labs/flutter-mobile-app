import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _participantIdKey = 'leaderboard:participant_id';

/// Synthetic participant/season used when [AppConfig.useMockChallenges] is on,
/// so the breakdown (and thus per-challenge progress) loads without onboarding.
const int kMockParticipantId = 1;
const int kMockSeasonId = 1;

/// Reads the persisted participant ID from SharedPreferences (network-prefixed).
/// Returns null until onboarding persists the ID.
final participantIdProvider = FutureProvider<int?>((ref) async {
  if (AppConfig.useMockChallenges) return kMockParticipantId;
  return loadParticipantId();
});

/// Persist a participant ID to SharedPreferences (network-prefixed).
Future<void> saveParticipantId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_participantIdKey);
  await prefs.setInt(key, id);
}

/// Loads the persisted participant ID directly from storage.
Future<int?> loadParticipantId() async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_participantIdKey);
  return prefs.getInt(key);
}

/// In-memory season/event selection shared across all leaderboard providers.
final seasonEventContextProvider = StateProvider<SeasonEventContext>(
  (ref) => AppConfig.useMockChallenges
      ? const SeasonEventContext(
          seasonId: kMockSeasonId,
          seasonName: 'Season 1',
        )
      : const SeasonEventContext(),
);

/// Set of event IDs the participant has data in (from season-scope breakdown).
///
/// Updated by the bootstrap or breakdown provider whenever season-scope
/// data is available. Used by the event picker to show ended events
/// the user participated in.
final participantEventIdsProvider = StateProvider<Set<int>>(
  (ref) => const {},
);
