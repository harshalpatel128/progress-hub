enum DailyProgressStatus {
  completed,
  partiallyCompleted,
  missed,
  restDay,
  holiday,
  skipped;

  static DailyProgressStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'completed':
        return DailyProgressStatus.completed;
      case 'partially_completed':
      case 'partiallycompleted':
        return DailyProgressStatus.partiallyCompleted;
      case 'missed':
        return DailyProgressStatus.missed;
      case 'rest_day':
      case 'restday':
        return DailyProgressStatus.restDay;
      case 'holiday':
        return DailyProgressStatus.holiday;
      case 'skipped':
        return DailyProgressStatus.skipped;
      default:
        return DailyProgressStatus.missed;
    }
  }

  String get dbValue {
    switch (this) {
      case DailyProgressStatus.completed:
        return 'completed';
      case DailyProgressStatus.partiallyCompleted:
        return 'partially_completed';
      case DailyProgressStatus.missed:
        return 'missed';
      case DailyProgressStatus.restDay:
        return 'rest_day';
      case DailyProgressStatus.holiday:
        return 'holiday';
      case DailyProgressStatus.skipped:
        return 'skipped';
    }
  }

  String get label {
    switch (this) {
      case DailyProgressStatus.completed:
        return 'Completed';
      case DailyProgressStatus.partiallyCompleted:
        return 'Partially Completed';
      case DailyProgressStatus.missed:
        return 'Missed';
      case DailyProgressStatus.restDay:
        return 'Rest Day';
      case DailyProgressStatus.holiday:
        return 'Holiday';
      case DailyProgressStatus.skipped:
        return 'Skipped';
    }
  }
}

class DailyProgressModel {
  final String id;
  final String groupId;
  final String dateString; // "YYYY-MM-DD"
  final int targetMinutes;
  final int completedMinutes;
  final int topicsCompletedCount;
  final DailyProgressStatus status;
  final String notes;
  final DateTime updatedAt;

  DailyProgressModel({
    required this.id,
    required this.groupId,
    required this.dateString,
    this.targetMinutes = 60,
    this.completedMinutes = 0,
    this.topicsCompletedCount = 0,
    this.status = DailyProgressStatus.missed,
    this.notes = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'date_string': dateString,
      'target_minutes': targetMinutes,
      'completed_minutes': completedMinutes,
      'topics_completed_count': topicsCompletedCount,
      'status': status.dbValue,
      'notes': notes,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DailyProgressModel.fromMap(Map<String, dynamic> map) {
    return DailyProgressModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      dateString: map['date_string'] as String,
      targetMinutes: (map['target_minutes'] as int?) ?? 60,
      completedMinutes: (map['completed_minutes'] as int?) ?? 0,
      topicsCompletedCount: (map['topics_completed_count'] as int?) ?? 0,
      status: DailyProgressStatus.fromString(map['status']?.toString() ?? 'missed'),
      notes: (map['notes'] as String?) ?? '',
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
