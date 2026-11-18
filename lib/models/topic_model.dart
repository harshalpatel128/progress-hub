import 'dart:convert';

enum TopicStatus {
  incomplete,
  inProgress,
  completed;

  static TopicStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return TopicStatus.inProgress;
      case 'completed':
        return TopicStatus.completed;
      case 'incomplete':
      default:
        return TopicStatus.incomplete;
    }
  }

  String get dbValue {
    switch (this) {
      case TopicStatus.inProgress:
        return 'in_progress';
      case TopicStatus.completed:
        return 'completed';
      case TopicStatus.incomplete:
        return 'incomplete';
    }
  }

  String get label {
    switch (this) {
      case TopicStatus.inProgress:
        return 'In Progress';
      case TopicStatus.completed:
        return 'Completed';
      case TopicStatus.incomplete:
        return 'Incomplete';
    }
  }
}

class SubTask {
  String id;
  String title;
  bool isCompleted;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted,
  };

  factory SubTask.fromMap(Map<String, dynamic> map) => SubTask(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    isCompleted: map['is_completed'] == true || map['is_completed'] == 1 || map['isCompleted'] == true,
  );
}

class TopicResource {
  String title;
  String url;

  TopicResource({required this.title, required this.url});

  Map<String, dynamic> toMap() => {'title': title, 'url': url};
  factory TopicResource.fromMap(Map<String, dynamic> map) => TopicResource(
    title: map['title']?.toString() ?? '',
    url: map['url']?.toString() ?? '',
  );
}

class TopicModel {
  final String id;
  final String groupId;
  final String sectionId;
  final int orderIndex;
  final String title;
  final TopicStatus status;
  final String priority; // High, Medium, Normal
  final String difficulty; // Beginner, Intermediate, Advanced
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final int estimatedMinutes;
  final int actualMinutes;
  final String notes;
  final List<SubTask> subtasks;
  final List<TopicResource> resources;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display helpers
  final String? sectionName;
  final int? monthNumber;

  TopicModel({
    required this.id,
    required this.groupId,
    required this.sectionId,
    required this.orderIndex,
    required this.title,
    this.status = TopicStatus.incomplete,
    this.priority = 'Normal',
    this.difficulty = 'Beginner',
    this.startDate,
    this.dueDate,
    this.completedDate,
    this.estimatedMinutes = 60,
    this.actualMinutes = 0,
    this.notes = '',
    List<SubTask>? subtasks,
    List<TopicResource>? resources,
    List<String>? attachments,
    required this.createdAt,
    required this.updatedAt,
    this.sectionName,
    this.monthNumber,
  })  : subtasks = subtasks ?? [],
        resources = resources ?? [],
        attachments = attachments ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'section_id': sectionId,
      'order_index': orderIndex,
      'title': title,
      'status': status.dbValue,
      'priority': priority,
      'difficulty': difficulty,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'actual_minutes': actualMinutes,
      'notes': notes,
      'subtasks_json': jsonEncode(subtasks.map((e) => e.toMap()).toList()),
      'resources_json': jsonEncode(resources.map((e) => e.toMap()).toList()),
      'attachments_json': jsonEncode(attachments),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TopicModel.fromMap(Map<String, dynamic> map, {String? sectionName, int? monthNumber}) {
    List<SubTask> parsedSubtasks = [];
    if (map['subtasks_json'] != null && map['subtasks_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['subtasks_json']);
        if (decoded is List) {
          parsedSubtasks = decoded.map((e) => SubTask.fromMap(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    List<TopicResource> parsedResources = [];
    if (map['resources_json'] != null && map['resources_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['resources_json']);
        if (decoded is List) {
          parsedResources = decoded.map((e) => TopicResource.fromMap(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    List<String> parsedAttachments = [];
    if (map['attachments_json'] != null && map['attachments_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['attachments_json']);
        if (decoded is List) {
          parsedAttachments = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return TopicModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      sectionId: map['section_id'] as String,
      orderIndex: (map['order_index'] as int?) ?? 1,
      title: map['title'] as String,
      status: TopicStatus.fromString(map['status']?.toString() ?? 'incomplete'),
      priority: (map['priority'] as String?) ?? 'Normal',
      difficulty: (map['difficulty'] as String?) ?? 'Beginner',
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date']) : null,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date']) : null,
      completedDate: map['completed_date'] != null ? DateTime.tryParse(map['completed_date']) : null,
      estimatedMinutes: (map['estimated_minutes'] as int?) ?? 60,
      actualMinutes: (map['actual_minutes'] as int?) ?? 0,
      notes: (map['notes'] as String?) ?? '',
      subtasks: parsedSubtasks,
      resources: parsedResources,
      attachments: parsedAttachments,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      sectionName: sectionName ?? (map['section_name'] as String?),
      monthNumber: monthNumber ?? (map['month_number'] as int?),
    );
  }

  TopicModel copyWith({
    String? id,
    String? groupId,
    String? sectionId,
    int? orderIndex,
    String? title,
    TopicStatus? status,
    String? priority,
    String? difficulty,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedDate,
    int? estimatedMinutes,
    int? actualMinutes,
    String? notes,
    List<SubTask>? subtasks,
    List<TopicResource>? resources,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sectionName,
    int? monthNumber,
  }) {
    return TopicModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      sectionId: sectionId ?? this.sectionId,
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      completedDate: completedDate ?? this.completedDate,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      resources: resources ?? this.resources,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sectionName: sectionName ?? this.sectionName,
      monthNumber: monthNumber ?? this.monthNumber,
    );
  }
}
