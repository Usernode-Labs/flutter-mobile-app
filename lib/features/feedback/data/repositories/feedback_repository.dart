import '../../../../core/services/github_issue_service.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final GitHubIssueService _githubService;

  FeedbackRepository({GitHubIssueService? githubService})
      : _githubService = githubService ?? GitHubIssueService();

  /// Submits feedback to GitHub issues
  Future<bool> submitFeedback(FeedbackModel feedback) async {
    return await _githubService.createIssue(
      title: feedback.title,
      description: feedback.description,
      category: feedback.category,
      includeDeviceInfo: feedback.includeDeviceInfo,
      screenshots: feedback.screenshots,
    );
  }
}
