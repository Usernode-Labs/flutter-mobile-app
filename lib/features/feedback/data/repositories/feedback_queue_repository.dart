import 'dart:convert';

import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feedback_model.dart';
import 'feedback_repository.dart';

class FeedbackQueueRepository {
  static const String _queueKey = 'feedback_queue';
  final FeedbackRepository _feedbackRepository;

  FeedbackQueueRepository({
    FeedbackRepository? feedbackRepository,
  }) : _feedbackRepository = feedbackRepository ?? FeedbackRepository();

  /// Adds feedback to the offline queue
  Future<void> queueFeedback(FeedbackModel feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = await _getQueue();
      queue.add(feedback);

      final jsonList = queue.map((f) => f.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(jsonList));

      LoggingService.instance.info('Feedback queued for later submission');
    } catch (e) {
      LoggingService.instance.error('Error queuing feedback', error: e);
    }
  }

  /// Gets all queued feedback items
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
      LoggingService.instance.error('Error getting feedback queue', error: e);
      return [];
    }
  }

  /// Processes all queued feedback items
  Future<void> processQueue() async {
    try {
      final queue = await _getQueue();

      if (queue.isEmpty) {
        return;
      }

      LoggingService.instance
          .info('Processing ${queue.length} queued feedback items');

      final failedItems = <FeedbackModel>[];

      for (final feedback in queue) {
        final success = await _feedbackRepository.submitFeedback(feedback);
        if (!success) {
          failedItems.add(feedback);
        }
      }

      // Update the queue with only failed items
      final prefs = await SharedPreferences.getInstance();
      if (failedItems.isEmpty) {
        await prefs.remove(_queueKey);
        LoggingService.instance
            .info('All queued feedback submitted successfully');
      } else {
        final jsonList = failedItems.map((f) => f.toJson()).toList();
        await prefs.setString(_queueKey, jsonEncode(jsonList));
        LoggingService.instance
            .warn('${failedItems.length} feedback items failed to submit');
      }
    } catch (e) {
      LoggingService.instance
          .error('Error processing feedback queue', error: e);
    }
  }

  /// Gets the number of items in the queue
  Future<int> getQueueSize() async {
    final queue = await _getQueue();
    return queue.length;
  }

  /// Clears the entire queue
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
