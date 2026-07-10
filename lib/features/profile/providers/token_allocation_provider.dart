import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A participant's season token allocation — the reward amount surfaced on the
/// profile as a "little win" reveal.
///
/// DRAFT: the values here are mocked. The real allocation will come from the
/// rewards API once it exists. Expected response shape (subject to change),
/// e.g. `GET /v1/seasons/{seasonId}/token-allocation` scoped to the current
/// participant:
///
/// ```json
/// {
///   "season_id": 2,
///   "amount": 1250,        // integer whole-token amount allocated
///   "unit": "UNODE",       // token ticker / symbol
///   "acknowledged": false  // whether the user has already revealed it
/// }
/// ```
class TokenAllocation {
  const TokenAllocation({
    required this.amount,
    required this.unit,
    required this.acknowledged,
  });

  /// Whole-token amount allocated to the participant for the season.
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

  // TODO(rewards-api): add a JSON factory once the endpoint lands, e.g.
  // factory TokenAllocation.fromJson(Map<String, dynamic> json) =>
  //     TokenAllocation(
  //       amount: json['amount'] as int,
  //       unit: json['unit'] as String,
  //       acknowledged: json['acknowledged'] as bool? ?? false,
  //     );
}

/// Provides the current participant's season token allocation.
///
/// DRAFT: returns a mocked value. Replace [TokenAllocationController.build]
/// with a real service call — e.g.
/// `ref.read(rewardsApiServiceProvider).getTokenAllocation(seasonId, participantId)`
/// — following the async provider pattern used by `rankingProvider` /
/// `LeaderboardApiService`.
final tokenAllocationProvider =
    AsyncNotifierProvider<TokenAllocationController, TokenAllocation>(
  TokenAllocationController.new,
);

class TokenAllocationController extends AsyncNotifier<TokenAllocation> {
  @override
  Future<TokenAllocation> build() async {
    // TODO(rewards-api): fetch from the rewards endpoint. Mocked for the draft.
    return const TokenAllocation(
      amount: 1250,
      unit: 'UNODE',
      acknowledged: false,
    );
  }

  /// Marks the allocation as revealed so the celebration only plays once.
  ///
  /// DRAFT: updates in-memory state only. The finisher should persist this —
  /// e.g. POST an acknowledgement to the rewards API and/or store a flag in
  /// secure storage — so a revisit renders the settled state without replaying
  /// the celebration.
  Future<void> acknowledge() async {
    final current = state.valueOrNull;
    if (current == null || current.acknowledged) return;
    state = AsyncData(current.copyWith(acknowledged: true));
    // TODO(rewards-api): persist acknowledgement (backend + local cache).
  }
}
