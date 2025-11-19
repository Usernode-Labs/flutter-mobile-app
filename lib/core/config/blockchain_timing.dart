import 'app_constants.dart';

/// Centralized blockchain timing configuration.
///
/// All timing values are derived from the base blockchain constants:
/// - slotDurationMs: Duration of each slot in milliseconds
/// - slotsPerEpoch: Number of slots in an epoch
///
/// This ensures all timing scales proportionally when blockchain parameters change.
class BlockchainTiming {
  // Private constructor to prevent instantiation
  BlockchainTiming._();

  // Base constants from AppConstants
  static int get slotDurationMs => AppConstants.slotDurationMs;
  static int get slotsPerEpoch => AppConstants.slotsPerEpoch;

  /// How far in advance to schedule alarms before slot time.
  /// Current: 12 slots = 1 minute (with 5s slots)
  static Duration get alarmAdvanceTime =>
      Duration(milliseconds: slotDurationMs * 12);

  /// How often to poll node status during slot monitoring.
  /// Current: 1 slot = 5 seconds (with 5s slots)
  static Duration get pollInterval => Duration(milliseconds: slotDurationMs);

  /// Maximum time to monitor for block production after slot time.
  /// Current: 24 slots = 2 minutes (with 5s slots)
  static Duration get monitoringTimeout =>
      Duration(milliseconds: slotDurationMs * 24);

  /// Default epoch check interval (used when epoch progress is unknown).
  /// Current: 15 minutes
  static Duration get epochCheckIntervalDefault => const Duration(minutes: 15);

  /// Calculate dynamic epoch check interval based on progress through epoch.
  /// - Early epoch (0-25%): Check every 30 minutes
  /// - Mid epoch (25-75%): Check every 15 minutes
  /// - Late epoch (75-100%): Check every 5 minutes
  ///
  /// This adaptive approach reduces unnecessary checks early in the epoch
  /// while ensuring timely detection of epoch transitions.
  static Duration getEpochCheckInterval(double epochProgress) {
    if (epochProgress < 0.25) {
      return const Duration(minutes: 30); // Early: check infrequently
    } else if (epochProgress < 0.75) {
      return const Duration(minutes: 15); // Mid: check moderately
    } else {
      return const Duration(minutes: 5); // Late: check frequently
    }
  }

  /// Auto-cancel listener timeout for foreground service callbacks.
  /// Current: 24 slots = 2 minutes (with 5s slots)
  /// Matches the monitoring timeout duration
  static Duration get listenerAutoCancel =>
      Duration(milliseconds: slotDurationMs * 24);

  // Informational getters

  /// Total duration of one epoch.
  /// Current: 720 slots × 5s = 3600 seconds = 1 hour
  static Duration get epochDuration =>
      Duration(milliseconds: slotDurationMs * slotsPerEpoch);

  /// Number of slots that occur in one minute.
  /// Current: 60000ms / 5000ms = 12 slots/minute
  static int get slotsPerMinute => 60000 ~/ slotDurationMs;

  /// Number of slots that occur in one hour.
  /// Current: 3600000ms / 5000ms = 720 slots/hour
  static int get slotsPerHour => 3600000 ~/ slotDurationMs;

  /// Duration of monitoring window (before + after slot time).
  /// Current: (12 + 24) slots = 36 slots = 3 minutes
  static Duration get monitoringWindow =>
      Duration(milliseconds: slotDurationMs * (12 + 24));

  /// Convert a number of slots to a Duration.
  static Duration slotsToTimer(int slots) =>
      Duration(milliseconds: slotDurationMs * slots);

  /// Convert a Duration to approximate number of slots.
  static int durationToSlots(Duration duration) =>
      duration.inMilliseconds ~/ slotDurationMs;
}
