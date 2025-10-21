/// Points calculation service
///
/// Points are earned through:
/// - Blocks produced: 10 points per block
/// - Identity verification: 50 bonus points
/// - Token locking/staking: 1 point per 100 tokens locked
/// - Referrals: 25 points per referral
///
/// NOTE: This is a mock implementation. Will be replaced with backend calculation.
class PointsCalculator {
  /// Calculate total points based on various factors
  static int calculatePoints({
    required int blocksProduced,
    required bool isIdentityVerified,
    required int lockedTokens,
    required int referrals,
  }) {
    int points = 0;

    // Blocks produced: 10 points per block
    points += blocksProduced * 10;

    // Identity verification: 50 bonus points
    if (isIdentityVerified) {
      points += 50;
    }

    // Token locking: 1 point per 100 tokens locked
    points += (lockedTokens / 100).floor();

    // Referrals: 25 points per referral
    points += referrals * 25;

    return points;
  }

  /// Project next epoch points based on expected performance
  ///
  /// Simple projection: current points + expected new blocks * 10
  /// In production, this would factor in:
  /// - Expected VRF wins
  /// - Historical production rate
  /// - Tier multiplier effects
  static int projectNextEpochPoints({
    required int currentPoints,
    required int expectedBlocksNextEpoch,
  }) {
    // Points earned from expected blocks
    final newPoints = expectedBlocksNextEpoch * 10;

    return currentPoints + newPoints;
  }

  /// Get points breakdown for display
  static Map<String, int> getPointsBreakdown({
    required int blocksProduced,
    required bool isIdentityVerified,
    required int lockedTokens,
    required int referrals,
  }) {
    return {
      'blocks': blocksProduced * 10,
      'identity': isIdentityVerified ? 50 : 0,
      'staking': (lockedTokens / 100).floor(),
      'referrals': referrals * 25,
    };
  }

  /// Get human-readable points rules
  static const Map<String, String> pointsRules = {
    'Blocks Produced': '10 points per block',
    'Identity Verified': '+50 bonus points',
    'Token Locking': '1 point per 100 tokens',
    'Referrals': '25 points per referral',
  };
}
