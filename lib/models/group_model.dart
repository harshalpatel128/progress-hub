class GroupModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String colorHex;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final String durationText;
  final int dailyTargetMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  // Computed / UI properties
  final int totalTopics;
  final int completedTopics;
  final int inProgressTopics;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.iconName = 'school',
    this.colorHex = '#2196F3',
    this.category = 'General',
    this.startDate,
    this.endDate,
    this.durationText = '6 Months',
    this.dailyTargetMinutes = 60,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.totalTopics = 0,
    this.completedTopics = 0,
    this.inProgressTopics = 0,
  });

  double get progressPercentage =>
      totalTopics == 0 ? 0.0 : (completedTopics / totalTopics).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'color_hex': colorHex,
      'category': category,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'duration_text': durationText,
      'daily_target_minutes': dailyTargetMinutes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, {
    int totalTopics = 0,
    int completedTopics = 0,
    int inProgressTopics = 0,
  }) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      iconName: (map['icon_name'] as String?) ?? 'school',
      colorHex: (map['color_hex'] as String?) ?? '#2196F3',
      category: (map['category'] as String?) ?? 'General',
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date']) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date']) : null,
      durationText: (map['duration_text'] as String?) ?? '6 Months',
      dailyTargetMinutes: (map['daily_target_minutes'] as int?) ?? 60,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      isArchived: (map['is_archived'] as int?) == 1,
      totalTopics: totalTopics,
      completedTopics: completedTopics,
      inProgressTopics: inProgressTopics,
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? durationText,
    int? dailyTargetMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    int? totalTopics,
    int? completedTopics,
    int? inProgressTopics,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationText: durationText ?? this.durationText,
      dailyTargetMinutes: dailyTargetMinutes ?? this.dailyTargetMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      totalTopics: totalTopics ?? this.totalTopics,
      completedTopics: completedTopics ?? this.completedTopics,
      inProgressTopics: inProgressTopics ?? this.inProgressTopics,
    );
  }
}
