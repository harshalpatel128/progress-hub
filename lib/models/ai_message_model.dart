import 'dart:convert';

class AiMessageModel {
  final String id;
  final String sender; // 'user', 'ai', 'system'
  final String text;
  final String? actionType; // 'group_created', 'topic_updated', 'alarm_set', 'profile_updated', 'theme_changed', 'info'
  final String? actionTitle;
  final String? actionDetails;
  final Map<String, dynamic>? actionData;
  final DateTime timestamp;

  AiMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.actionType,
    this.actionTitle,
    this.actionDetails,
    this.actionData,
    required this.timestamp,
  });

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  bool get hasAction => actionType != null && actionType != 'info';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'action_type': actionType,
      'action_title': actionTitle,
      'action_details': actionDetails,
      'action_data': actionData != null ? jsonEncode(actionData) : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AiMessageModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? data;
    if (map['action_data'] != null) {
      try {
        data = jsonDecode(map['action_data'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return AiMessageModel(
      id: map['id'] as String,
      sender: map['sender'] as String,
      text: map['text'] as String,
      actionType: map['action_type'] as String?,
      actionTitle: map['action_title'] as String?,
      actionDetails: map['action_details'] as String?,
      actionData: data,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
