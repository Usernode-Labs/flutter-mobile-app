import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_model.dart';
import '../../data/repositories/feedback_queue_repository.dart';
import '../../data/repositories/feedback_repository.dart';

// Provider for FeedbackRepository
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository();
});

// Provider for FeedbackQueueRepository
final feedbackQueueRepositoryProvider =
    Provider<FeedbackQueueRepository>((ref) {
  return FeedbackQueueRepository(
    feedbackRepository: ref.watch(feedbackRepositoryProvider),
  );
});

// State for feedback submission
enum FeedbackSubmissionStatus {
  idle,
  submitting,
  success,
  error,
}

class FeedbackSubmissionState {
  final FeedbackSubmissionStatus status;
  final String? errorMessage;

  FeedbackSubmissionState({
    required this.status,
    this.errorMessage,
  });

  FeedbackSubmissionState copyWith({
    FeedbackSubmissionStatus? status,
    String? errorMessage,
  }) {
    return FeedbackSubmissionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// StateNotifier for managing feedback submission
class FeedbackSubmissionNotifier
    extends StateNotifier<FeedbackSubmissionState> {
  final FeedbackRepository _repository;
  final FeedbackQueueRepository _queueRepository;

  FeedbackSubmissionNotifier(this._repository, this._queueRepository)
      : super(FeedbackSubmissionState(status: FeedbackSubmissionStatus.idle));

  Future<void> submitFeedback(FeedbackModel feedback) async {
    state = state.copyWith(status: FeedbackSubmissionStatus.submitting);

    try {
      final success = await _repository.submitFeedback(feedback);

      if (success) {
        state = state.copyWith(
          status: FeedbackSubmissionStatus.success,
          errorMessage: null,
        );

        // Process any queued feedback
        await _queueRepository.processQueue();
      } else {
        // Queue for later if submission failed
        await _queueRepository.queueFeedback(feedback);

        state = state.copyWith(
          status: FeedbackSubmissionStatus.error,
          errorMessage:
              'Failed to submit feedback. It has been queued for retry.',
        );
      }
    } catch (e) {
      // Queue for later if an exception occurred
      await _queueRepository.queueFeedback(feedback);

      state = state.copyWith(
        status: FeedbackSubmissionStatus.error,
        errorMessage: 'Network error. Feedback has been queued for retry.',
      );
    }
  }

  void reset() {
    state = FeedbackSubmissionState(status: FeedbackSubmissionStatus.idle);
  }
}

// Provider for FeedbackSubmissionNotifier
final feedbackSubmissionProvider =
    StateNotifierProvider<FeedbackSubmissionNotifier, FeedbackSubmissionState>(
        (ref) {
  return FeedbackSubmissionNotifier(
    ref.watch(feedbackRepositoryProvider),
    ref.watch(feedbackQueueRepositoryProvider),
  );
});
