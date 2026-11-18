class ScheduleModel {
  final String id;
  final String groupId;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final String startTime; // "09:00"
  final String endTime; // "11:00"
  final int sessionMinutes;
  final int breakMinutes;
  final bool isRestDay;
  final DateTime createdAt;

  ScheduleModel({
    required this.id,
    required this.groupId,
    required this.dayOfWeek,
    this.startTime = '09:00',
    this.endTime = '10:00',
    this.sessionMinutes = 60,
    this.breakMinutes = 10,
    this.isRestDay = false,
    required this.createdAt,
  });

  String get dayName {
    const names = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday'
    };
    return names[dayOfWeek] ?? 'Day $dayOfWeek';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'session_minutes': sessionMinutes,
      'break_minutes': breakMinutes,
      'is_rest_day': isRestDay ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      dayOfWeek: (map['day_of_week'] as int?) ?? 1,
      startTime: (map['start_time'] as String?) ?? '09:00',
      endTime: (map['end_time'] as String?) ?? '10:00',
      sessionMinutes: (map['session_minutes'] as int?) ?? 60,
      breakMinutes: (map['break_minutes'] as int?) ?? 10,
      isRestDay: (map['is_rest_day'] as int?) == 1,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
