import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/ranking_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _unit = 'UNODE';
const _revealedPreferenceKey = 'profile:token-allocation-revealed';

/// A participant's token allocation for the selected season/event scope.
class TokenAllocation {
  const TokenAllocation({
    required this.amount,
    required this.unit,
    required this.acknowledged,
  });

  /// Whole-token amount returned by `GET /api/v2/mobile/me/ranking`.
  final int amount;

  /// Token ticker / symbol, e.g. "UNODE".
  final String unit;

  /// Whether the user has already revealed (acknowledged) this allocation.
  /// Persisted so the celebration only plays once across refetches/restarts.
  final bool acknowledged;

  TokenAllocation copyWith({bool? acknowledged}) => TokenAllocation(
        amount: amount,
        unit: unit,
        acknowledged: acknowledged ?? this.acknowledged,
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
      unit: _unit,
      acknowledged: preferences.getBool(_preferenceKey!) ?? false,
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
