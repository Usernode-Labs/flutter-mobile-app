import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/config/app_config.dart';

final _log = LoggingService.instance.withTag('GitHubIssueService');

class GitHubIssueService {
  GitHubIssueService();

  /// Creates a GitHub issue with the provided feedback
  Future<bool> createIssue({
    required String title,
    required String description,
    required String category,
    bool includeDeviceInfo = true,
    List<File>? screenshots,
  }) async {
    try {
      final token = AppConfig.githubToken;
      if (token.isEmpty) {
        _log.error('GitHub token not configured');
        return false;
      }

      // Build the issue body
      final body = await _buildIssueBody(
        description: description,
        category: category,
        includeDeviceInfo: includeDeviceInfo,
      );

      // Create the issue
      final issueUrl = Uri.parse(
        'https://api.github.com/repos/${AppConfig.githubOwner}/${AppConfig.githubRepo}/issues',
      );

      final response = await http.post(
        issueUrl,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'labels': [_getCategoryLabel(category)],
        }),
      );

      if (response.statusCode == 201) {
        final issueData = jsonDecode(response.body);
        final issueNumber = issueData['number'];
        _log.info('GitHub issue created successfully: #$issueNumber');

        // Upload screenshots if provided
        if (screenshots != null && screenshots.isNotEmpty) {
          await _uploadScreenshots(issueNumber, screenshots, token);
        }

        return true;
      } else {
        _log.error(
          'Failed to create GitHub issue: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      _log.error('Error creating GitHub issue',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Builds the issue body with description and optional device info
  Future<String> _buildIssueBody({
    required String description,
    required String category,
    required bool includeDeviceInfo,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('## Description');
    buffer.writeln(description);
    buffer.writeln();

    buffer.writeln('## Category');
    buffer.writeln(category);
    buffer.writeln();

    if (includeDeviceInfo) {
      buffer.writeln('## Device Information');
      buffer.writeln('```');
      buffer.writeln(await _getDeviceInfo());
      buffer.writeln('```');
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('*Submitted via in-app feedback*');

    return buffer.toString();
  }

  /// Collects device and app information
  Future<String> _getDeviceInfo() async {
    final buffer = StringBuffer();

    try {
      // App info
      final packageInfo = await PackageInfo.fromPlatform();
      buffer.writeln('App Version: ${packageInfo.version}');
      buffer.writeln('Build Number: ${packageInfo.buildNumber}');
      buffer.writeln('Package Name: ${packageInfo.packageName}');

      // Device info
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        buffer.writeln('Platform: Android ${androidInfo.version.release}');
        buffer.writeln(
            'Device: ${androidInfo.manufacturer} ${androidInfo.model}');
        buffer.writeln('SDK: ${androidInfo.version.sdkInt}');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        buffer.writeln('Platform: iOS ${iosInfo.systemVersion}');
        buffer.writeln('Device: ${iosInfo.model}');
        buffer.writeln('Name: ${iosInfo.name}');
      }
    } catch (e) {
      buffer.writeln('Error collecting device info: $e');
    }

    return buffer.toString();
  }

  /// Gets the appropriate label for the category
  String _getCategoryLabel(String category) {
    switch (category) {
      case 'Bug Report':
        return 'bug';
      case 'Feature Request':
        return 'enhancement';
      case 'General Feedback':
        return 'feedback';
      default:
        return 'feedback';
    }
  }

  /// Uploads screenshots as comments to the issue
  Future<void> _uploadScreenshots(
    int issueNumber,
    List<File> screenshots,
    String token,
  ) async {
    try {
      for (var i = 0; i < screenshots.length; i++) {
        // GitHub doesn't support direct image uploads to issues via API
        // In production, you might want to upload to a separate image hosting service
        final commentUrl = Uri.parse(
          'https://api.github.com/repos/${AppConfig.githubOwner}/${AppConfig.githubRepo}/issues/$issueNumber/comments',
        );

        // For now, we'll just add a comment noting that screenshots were captured
        // You could extend this to upload to an image hosting service
        await http.post(
          commentUrl,
          headers: {
            'Accept': 'application/vnd.github.v3+json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'body':
                '**Screenshot ${i + 1}**\n\n_(Screenshot captured but not uploaded - consider using an image hosting service for attachments)_',
          }),
        );
      }
    } catch (e) {
      _log.error('Error uploading screenshots', error: e);
    }
  }
}
