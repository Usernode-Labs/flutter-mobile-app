import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'vrf_status.dart';

/// Enhanced response from backend RPC that includes VRF calculation status
///
/// This model wraps the existing RpcEpochRewardsResp with additional
/// metadata about VRF calculation progress to enable smart epoch monitoring.
class BackendRPCResponse {
  /// The epoch number
  final int currentEpoch;

  /// The current global slot number
  final int currentSlot;

  /// VRF calculation status for this epoch
  final VRFStatus vrfStatus;

  /// List of won slots (only populated when VRF is complete)
  final List<RpcEpochWonSlot> wonSlots;

  /// VRF calculation progress (0.0 to 1.0)
  ///
  /// Note: This is currently inferred from the response and may not be accurate.
  /// A future backend enhancement could provide real VRF progress.
  final double? vrfProgress;

  /// Estimated time remaining for VRF calculation
  ///
  /// Note: This is currently unavailable but can be added in future backend updates.
  final Duration? vrfEstimatedTimeRemaining;

  /// Number of won slots in this epoch
  final int totalWonSlots;

  /// Number of blocks already produced in this epoch
  final int producedInEpoch;

  /// The original epoch rewards response from backend
  final RpcEpochRewardsResp originalResponse;

  const BackendRPCResponse({
    required this.currentEpoch,
    required this.currentSlot,
    required this.vrfStatus,
    required this.wonSlots,
    required this.totalWonSlots,
    required this.producedInEpoch,
    required this.originalResponse,
    this.vrfProgress,
    this.vrfEstimatedTimeRemaining,
  });

  /// Create a BackendRPCResponse from the existing RpcEpochRewardsResp
  ///
  /// This factory infers VRF status based on the response:
  /// - If wonSlots is present and non-empty: VRF is complete
  /// - If wonSlots is null or empty: VRF status is unknown (assumed complete for backwards compatibility)
  factory BackendRPCResponse.fromEpochRewards(
    RpcEpochRewardsResp epochRewards, {
    required int currentSlot,
    VRFStatus? overrideStatus,
  }) {
    // Infer VRF status from the response
    final VRFStatus status = overrideStatus ??
      (epochRewards.wonSlots != null ? VRFStatus.complete : VRFStatus.complete);

    final double? progress = status == VRFStatus.complete ? 1.0 : null;

    return BackendRPCResponse(
      currentEpoch: epochRewards.epoch,
      currentSlot: currentSlot,
      vrfStatus: status,
      wonSlots: epochRewards.wonSlots ?? [],
      totalWonSlots: epochRewards.winsInEpoch,
      producedInEpoch: epochRewards.producedInEpoch,
      originalResponse: epochRewards,
      vrfProgress: progress,
      vrfEstimatedTimeRemaining: null,
    );
  }

  /// Check if VRF calculation is complete and slots can be scheduled
  bool get canScheduleSlots => vrfStatus.canScheduleSlots && wonSlots.isNotEmpty;

  /// Check if there are any won slots in this epoch
  bool get hasWonSlots => wonSlots.isNotEmpty;

  @override
  String toString() {
    return 'BackendRPCResponse('
        'epoch: $currentEpoch, '
        'slot: $currentSlot, '
        'vrfStatus: ${vrfStatus.displayName}, '
        'wonSlots: ${wonSlots.length}, '
        'progress: ${vrfProgress != null ? "${(vrfProgress! * 100).toStringAsFixed(1)}%" : "unknown"}'
        ')';
  }
}
