import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

/// Resolves the [ChallengeDto] for the dApps challenge by subCategory.
final dappsChallengeProvider = Provider<ChallengeDto?>((ref) {
  final challenges = ref.watch(challengesProvider.select((s) => s.value?.data));
  if (challenges == null) return null;
  for (final c in challenges) {
    if (isDappsChallenge(c)) return c;
  }
  return null;
});

/// Whether dApps live functionality is enabled.
///
/// TODO: restore challenge gate before release.
final dappsLiveProvider = Provider<bool>((ref) {
  return true;
});
