class NotificationLogModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? groupId;
  final String? topicId;
  final DateTime timestamp;
  final bool isRead;

  NotificationLogModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.groupId,
    this.topicId,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'group_id': groupId,
      'topic_id': topicId,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory NotificationLogModel.fromMap(Map<String, dynamic> map) {
    return NotificationLogModel(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      category: (map['category'] as String?) ?? 'scheduled_reminder',
      groupId: map['group_id'] as String?,
      topicId: map['topic_id'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: (map['is_read'] as int?) == 1,
    );
  }
}
