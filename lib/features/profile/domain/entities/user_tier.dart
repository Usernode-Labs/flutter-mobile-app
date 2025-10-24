/// User tier system with point-based progression
///
/// Tiers:
/// - Basic: 0-99 points (1.0x slot multiplier)
/// - Bronze: 100-499 points (1.5x slot multiplier)
/// - Silver: 500-749 points (2.0x slot multiplier)
/// - Gold: 750-999 points (3.0x slot multiplier)
/// - Platinum: 1000+ points (4.0x slot multiplier)

enum TierLevel {
  basic(1, 'Basic', 0, 99),
  bronze(2, 'Bronze', 100, 499),
  silver(3, 'Silver', 500, 749),
  gold(4, 'Gold', 750, 999),
  platinum(5, 'Platinum', 1000, null);

  const TierLevel(this.level, this.name, this.minPoints, this.maxPoints);

  final int level;
  final String name;
  final int minPoints;
  final int? maxPoints; // null for platinum (no upper limit)

  /// Slot probability multiplier for VRF lottery
  /// Higher tier = better odds of winning slots
  double get slotMultiplier {
    switch (this) {
      case TierLevel.basic:
        return 1.0;
      case TierLevel.bronze:
        return 1.5;
      case TierLevel.silver:
        return 2.0;
      case TierLevel.gold:
        return 3.0;
      case TierLevel.platinum:
        return 4.0;
    }
  }

  /// Calculate tier from points
  static TierLevel fromPoints(int points) {
    if (points >= 1000) return TierLevel.platinum;
    if (points >= 750) return TierLevel.gold;
    if (points >= 500) return TierLevel.silver;
    if (points >= 100) return TierLevel.bronze;
    return TierLevel.basic;
  }

  /// Get next tier in progression
  TierLevel? get nextTier {
    switch (this) {
      case TierLevel.basic:
        return TierLevel.bronze;
      case TierLevel.bronze:
        return TierLevel.silver;
      case TierLevel.silver:
        return TierLevel.gold;
      case TierLevel.gold:
        return TierLevel.platinum;
      case TierLevel.platinum:
        return null; // Already at max tier
    }
  }
}

/// User tier state for current and next epoch
class UserTierState {
  // Current epoch stats
  final TierLevel currentTier;
  final int currentPoints;
  final double currentMultiplier;

  // Next epoch projections
  final TierLevel nextEpochTier;
  final int nextEpochPoints;
  final double nextEpochMultiplier;

  const UserTierState({
    required this.currentTier,
    required this.currentPoints,
    required this.currentMultiplier,
    required this.nextEpochTier,
    required this.nextEpochPoints,
    required this.nextEpochMultiplier,
  });

  /// Points needed to reach next tier (null if at max tier)
  int? get pointsToNextTier {
    final nextTier = currentTier.nextTier;
    if (nextTier == null) return null; // Already at platinum
    return nextTier.minPoints - currentPoints;
  }

  /// Progress to next tier (0.0 to 1.0)
  double get progressToNextTier {
    final nextTier = currentTier.nextTier;
    if (nextTier == null) return 1.0; // Already at max

    final tierRange = nextTier.minPoints - currentTier.minPoints;
    final currentProgress = currentPoints - currentTier.minPoints;
    return (currentProgress / tierRange).clamp(0.0, 1.0);
  }

  /// Will tier up in next epoch?
  bool get willTierUp => nextEpochTier.level > currentTier.level;

  @override
  String toString() =>
      'UserTierState(current: $currentTier (${currentPoints}pts), next: $nextEpochTier (${nextEpochPoints}pts))';
}
