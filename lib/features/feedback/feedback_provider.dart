import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/feedback/github_issue_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'models/feedback_model.dart';

final _log = LoggingService.instance.withTag('usernode/FeedbackProvider');

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
  static const String _queueKeyBase = 'feedback_queue';
  static String get _queueKey => NetworkPrefs.prefixKey(_queueKeyBase);
  final GitHubIssueService _githubService;

  FeedbackSubmissionNotifier({GitHubIssueService? githubService})
      : _githubService = githubService ?? GitHubIssueService(),
        super(FeedbackSubmissionState(status: FeedbackSubmissionStatus.idle));

  Future<void> submitFeedback(FeedbackModel feedback) async {
    state = state.copyWith(status: FeedbackSubmissionStatus.submitting);

    try {
      final success = await _submitToGitHub(feedback);

      if (success) {
        state = state.copyWith(
          status: FeedbackSubmissionStatus.success,
          errorMessage: null,
        );
        // Process any queued feedback
        await _processQueue();
      } else {
        // Queue for later if submission failed
        await _queueFeedback(feedback);
        state = state.copyWith(
          status: FeedbackSubmissionStatus.error,
          errorMessage:
              'Failed to submit feedback. It has been queued for retry.',
        );
      }
    } catch (e) {
      // Queue for later if an exception occurred
      await _queueFeedback(feedback);
      state = state.copyWith(
        status: FeedbackSubmissionStatus.error,
        errorMessage: 'Network error. Feedback has been queued for retry.',
      );
    }
  }

  void reset() {
    state = FeedbackSubmissionState(status: FeedbackSubmissionStatus.idle);
  }

  // --- GitHub submission logic (from FeedbackRepository) ---

  Future<bool> _submitToGitHub(FeedbackModel feedback) async {
    return await _githubService.createIssue(
      title: feedback.title,
      description: feedback.description,
      category: feedback.category,
      includeDeviceInfo: feedback.includeDeviceInfo,
      screenshots: feedback.screenshots,
    );
  }

  // --- Queue logic (from FeedbackQueueRepository) ---

  Future<void> _queueFeedback(FeedbackModel feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _getQueue();
      queue.add(feedback);

      final jsonList = queue.map((f) => f.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(jsonList));

      _log.info('Feedback queued for later submission');
    } catch (e) {
      _log.error('Error queuing feedback', error: e);
    }
  }

  Future<List<FeedbackModel>> _getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_queueKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => FeedbackModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.error('Error getting feedback queue', error: e);
      return [];
    }
  }

  Future<void> _processQueue() async {
    try {
      final queue = await _getQueue();

      if (queue.isEmpty) {
        return;
      }

      _log.info('Processing ${queue.length} queued feedback items');

      final failedItems = <FeedbackModel>[];

      for (final feedback in queue) {
        final success = await _submitToGitHub(feedback);
        if (!success) {
          failedItems.add(feedback);
        }
      }

      // Update the queue with only failed items
      final prefs = await SharedPreferences.getInstance();
      if (failedItems.isEmpty) {
        await prefs.remove(_queueKey);
        _log.info('All queued feedback submitted successfully');
      } else {
        final jsonList = failedItems.map((f) => f.toJson()).toList();
        await prefs.setString(_queueKey, jsonEncode(jsonList));
        _log.warn('${failedItems.length} feedback items failed to submit');
      }
    } catch (e) {
      _log.error('Error processing feedback queue', error: e);
    }
  }
}

// Provider for FeedbackSubmissionNotifier
final feedbackSubmissionProvider =
    StateNotifierProvider<FeedbackSubmissionNotifier, FeedbackSubmissionState>(
        (ref) {
  return FeedbackSubmissionNotifier();
});
