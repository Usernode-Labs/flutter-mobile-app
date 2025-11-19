/// VRF (Verifiable Random Function) calculation status for an epoch
///
/// The VRF calculation determines which slots a validator has won in an epoch.
/// This enum tracks the status of that calculation.
enum VRFStatus {
  /// VRF calculation hasn't started yet for this epoch
  notStarted,

  /// VRF calculation is currently in progress
  inProgress,

  /// VRF calculation is complete and won slots are available
  complete,

  /// An error occurred during VRF calculation
  error,
}

extension VRFStatusExtension on VRFStatus {
  String get displayName {
    switch (this) {
      case VRFStatus.notStarted:
        return 'Not Started';
      case VRFStatus.inProgress:
        return 'In Progress';
      case VRFStatus.complete:
        return 'Complete';
      case VRFStatus.error:
        return 'Error';
    }
  }

  bool get isComplete => this == VRFStatus.complete;
  bool get isInProgress => this == VRFStatus.inProgress;
  bool get canScheduleSlots => this == VRFStatus.complete;
}
