/// Strongly-typed model representing in-app & push notifications for employees and managers
class AppNotification {
  final String id;
  final String recipientId; // Employee user ID who owns the notification
  final String type; // 'ATTENDANCE_APPROVED', 'ATTENDANCE_REJECTED', etc.
  final String title;
  final String message;
  final String? reason;
  final String? attendanceId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    this.reason,
    this.attendanceId,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      message: message,
      reason: reason,
      attendanceId: attendanceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final rawId = source['id'] ?? source['notification_id'] ?? source['notificationId'] ?? '';
    final rId = source['recipient_id']?.toString() ??
        source['recipientId']?.toString() ??
        source['employee_id']?.toString() ??
        source['user_id']?.toString() ??
        '';

    final rawType = source['type']?.toString().toUpperCase() ?? 'ATTENDANCE_APPROVED';
    final rawTitle = source['title']?.toString() ?? 'Attendance Notification';
    final rawMessage = source['message']?.toString() ?? source['body']?.toString() ?? '';
    final rawReason = source['reason']?.toString() ?? source['rejection_reason']?.toString();
    final attId = source['attendance_id']?.toString() ?? source['reference_id']?.toString();
    final readStatus = source['is_read'] as bool? ?? source['read'] as bool? ?? false;

    DateTime parsedDate = DateTime.now();
    if (source['created_at'] != null) {
      parsedDate = DateTime.tryParse(source['created_at'].toString()) ?? DateTime.now();
    } else if (source['createdAt'] != null) {
      parsedDate = DateTime.tryParse(source['createdAt'].toString()) ?? DateTime.now();
    }

    return AppNotification(
      id: rawId.toString(),
      recipientId: rId,
      type: rawType,
      title: rawTitle,
      message: rawMessage,
      reason: rawReason,
      attendanceId: attId,
      isRead: readStatus,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient_id': recipientId,
        'type': type,
        'title': title,
        'message': message,
        if (reason != null) 'reason': reason,
        if (attendanceId != null) 'attendance_id': attendanceId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}
