import 'package:uuid/uuid.dart';

/// Types of notifications in the app
enum NotificationType {
  blockProduced('block_produced'),
  slotWon('slot_won'),
  rewardEarned('reward_earned'),
  transactionSent('transaction_sent'),
  transactionReceived('transaction_received'),
  nodeSync('node_sync'),
  error('error'),
  info('info');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.info,
    );
  }
}

/// Represents a single notification in the app
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    this.data,
  });

  /// Create a new notification with generated ID
  factory AppNotification.create({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: const Uuid().v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now().toUtc(),
      isRead: false,
      data: data,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.value,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        if (data != null) 'data': data,
      };

  /// Create from JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.fromString(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// Copy with modifications
  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AppNotification{id: $id, title: $title, type: $type, isRead: $isRead}';
  }
}
