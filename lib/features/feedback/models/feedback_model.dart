import 'dart:io';

class FeedbackModel {
  final String title;
  final String description;
  final String category;
  final bool includeDeviceInfo;
  final List<File>? screenshots;
  final DateTime timestamp;

  FeedbackModel({
    required this.title,
    required this.description,
    required this.category,
    this.includeDeviceInfo = true,
    this.screenshots,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'includeDeviceInfo': includeDeviceInfo,
      'timestamp': timestamp.toIso8601String(),
      // Note: screenshots are not serialized for JSON storage
    };
  }

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      includeDeviceInfo: json['includeDeviceInfo'] as bool? ?? true,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  FeedbackModel copyWith({
    String? title,
    String? description,
    String? category,
    bool? includeDeviceInfo,
    List<File>? screenshots,
    DateTime? timestamp,
  }) {
    return FeedbackModel(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      includeDeviceInfo: includeDeviceInfo ?? this.includeDeviceInfo,
      screenshots: screenshots ?? this.screenshots,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
