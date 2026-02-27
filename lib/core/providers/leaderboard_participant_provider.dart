import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _participantIdKey = 'leaderboard:participant_id';

// TODO(leaderboard): Remove dev fallback once real registration flow persists participant ID.
const _kDevFallbackParticipantId = 19;

/// Reads the persisted participant ID from SharedPreferences (network-prefixed).
/// Falls back to [_kDevFallbackParticipantId] during development so ranking/breakdown
/// providers are never blocked by a missing participant.
final participantIdProvider = FutureProvider<int?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_participantIdKey);
  return prefs.getInt(key) ?? _kDevFallbackParticipantId;
});

/// Persist a participant ID to SharedPreferences (network-prefixed).
Future<void> saveParticipantId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final key = NetworkPrefs.prefixKey(_participantIdKey);
  await prefs.setInt(key, id);
}

/// In-memory season/event selection shared across all leaderboard providers.
final seasonEventContextProvider = StateProvider<SeasonEventContext>(
  (ref) => const SeasonEventContext(),
);
