import 'dart:convert';

class AlarmModel {
  final int id;
  final String title;
  final int hour;
  final int minute;
  final bool isEnabled;
  final List<int> repeatDays; // 1 = Monday ... 7 = Sunday. Empty = one-time today/tomorrow
  final String? groupId;
  final String? groupName;
  final String? topicId;
  final String? topicName;
  final String soundName;
  final String? customAudioPath;
  final String? customAudioName;
  final bool vibrationEnabled;
  final int snoozeDurationMinutes;
  final DateTime createdAt;

  AlarmModel({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    List<int>? repeatDays,
    this.groupId,
    this.groupName,
    this.topicId,
    this.topicName,
    this.soundName = 'default',
    this.customAudioPath,
    this.customAudioName,
    this.vibrationEnabled = true,
    this.snoozeDurationMinutes = 10,
    required this.createdAt,
  }) : repeatDays = repeatDays ?? [1, 2, 3, 4, 5, 6, 7];

  String get timeFormatted {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String get repeatDaysSummary {
    if (repeatDays.isEmpty) return 'One-time';
    if (repeatDays.length == 7) return 'Everyday';
    if (repeatDays.length == 5 && !repeatDays.contains(6) && !repeatDays.contains(7)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && repeatDays.contains(6) && repeatDays.contains(7)) {
      return 'Weekends';
    }
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return repeatDays.map((d) => dayNames[d] ?? '').join(', ');
  }

  String get repeatDaysText => repeatDaysSummary;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'is_enabled': isEnabled ? 1 : 0,
      'repeat_days_json': jsonEncode(repeatDays),
      'group_id': groupId,
      'topic_id': topicId,
      'sound_name': soundName,
      'custom_audio_path': customAudioPath,
      'custom_audio_name': customAudioName,
      'vibration_enabled': vibrationEnabled ? 1 : 0,
      'snooze_duration_minutes': snoozeDurationMinutes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AlarmModel.fromMap(Map<String, dynamic> map, {String? groupName, String? topicName}) {
    List<int> parsedDays = [1, 2, 3, 4, 5, 6, 7];
    if (map['repeat_days_json'] != null && map['repeat_days_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['repeat_days_json']);
        if (decoded is List) {
          parsedDays = decoded.map((e) => int.parse(e.toString())).toList();
        }
      } catch (_) {}
    }

    return AlarmModel(
      id: map['id'] as int,
      title: map['title'] as String,
      hour: (map['hour'] as int?) ?? 8,
      minute: (map['minute'] as int?) ?? 0,
      isEnabled: (map['is_enabled'] as int?) == 1,
      repeatDays: parsedDays,
      groupId: map['group_id'] as String?,
      groupName: groupName ?? (map['group_name'] as String?),
      topicId: map['topic_id'] as String?,
      topicName: topicName ?? (map['topic_name'] as String?),
      soundName: (map['sound_name'] as String?) ?? 'default',
      customAudioPath: map['custom_audio_path'] as String?,
      customAudioName: map['custom_audio_name'] as String?,
      vibrationEnabled: (map['vibration_enabled'] as int?) == 1,
      snoozeDurationMinutes: (map['snooze_duration_minutes'] as int?) ?? 10,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  AlarmModel copyWith({
    int? id,
    String? title,
    int? hour,
    int? minute,
    bool? isEnabled,
    List<int>? repeatDays,
    String? groupId,
    String? groupName,
    String? topicId,
    String? topicName,
    String soundName = 'default',
    String? customAudioPath,
    String? customAudioName,
    bool? vibrationEnabled,
    int? snoozeDurationMinutes,
    DateTime? createdAt,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      soundName: soundName,
      customAudioPath: customAudioPath ?? this.customAudioPath,
      customAudioName: customAudioName ?? this.customAudioName,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
