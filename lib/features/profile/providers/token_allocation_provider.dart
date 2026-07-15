import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _revealedPreferenceKey = 'profile:token-allocation-revealed';

/// A participant's token allocation for the selected season/event scope.
class TokenAllocation {
  const TokenAllocation({
    required this.amount,
    required this.acknowledged,
    this.termsAccepted = true,
  });

  /// Whole-token amount returned by `GET /api/v2/mobile/me/ranking`.
  ///
  /// The backend forces this to 0 while [termsAccepted] is false, so it is not
  /// a real balance in that state and must not be shown as one.
  final int amount;

  /// Whether the user has already revealed (acknowledged) this allocation.
  /// Persisted so the celebration only plays once across refetches/restarts.
  final bool acknowledged;

  /// Whether the participant has accepted the current terms version.
  final bool termsAccepted;

  TokenAllocation copyWith({bool? acknowledged}) => TokenAllocation(
        amount: amount,
        acknowledged: acknowledged ?? this.acknowledged,
        termsAccepted: termsAccepted,
      );
}

/// Provides the allocation from the active scoped ranking response.
final tokenAllocationProvider =
    AsyncNotifierProvider<TokenAllocationController, TokenAllocation?>(
  TokenAllocationController.new,
);

class TokenAllocationController extends AsyncNotifier<TokenAllocation?> {
  String? _preferenceKey;

  @override
  Future<TokenAllocation?> build() async {
    final participantId = ref.watch(participantIdProvider).valueOrNull;
    final scope = ref.watch(seasonEventContextProvider);
    final ranking = await ref.watch(rankingProvider.future);
    if (participantId == null || ranking == null) return null;

    final seasonId = scope.seasonId ?? ranking.seasonId;
    final eventId = scope.eventId ?? ranking.eventId;
    final allocationKey = [
      participantId,
      seasonId ?? 'all',
      eventId ?? 'all',
      ranking.totalTokens,
    ].join(':');
    _preferenceKey = NetworkPrefs.prefixKey(
      '$_revealedPreferenceKey:$allocationKey',
    );
    final preferences = await SharedPreferences.getInstance();

    return TokenAllocation(
      amount: ranking.totalTokens,
      acknowledged: preferences.getBool(_preferenceKey!) ?? false,
      termsAccepted: ranking.termsAccepted,
    );
  }

  /// Persists the reveal for this participant, scope, and allocation value.
  Future<void> acknowledge() async {
    final current = state.valueOrNull;
    if (current == null || current.acknowledged) return;
    final preferenceKey = _preferenceKey;
    if (preferenceKey == null) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(preferenceKey, true);
    state = AsyncData(current.copyWith(acknowledged: true));
  }
}
