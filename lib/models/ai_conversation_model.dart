class AiConversationModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String modelUsed;

  AiConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.modelUsed = 'gemini-1.5-flash',
  });

  AiConversationModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? modelUsed,
  }) {
    return AiConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      modelUsed: modelUsed ?? this.modelUsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_pinned': isPinned ? 1 : 0,
      'model_used': modelUsed,
    };
  }

  factory AiConversationModel.fromMap(Map<String, dynamic> map) {
    return AiConversationModel(
      id: (map['id'] as String?) ?? 'conv_${DateTime.now().millisecondsSinceEpoch}',
      title: (map['title'] as String?) ?? 'New Chat',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isPinned: (map['is_pinned'] as num?)?.toInt() == 1,
      modelUsed: (map['model_used'] as String?) ?? 'gemini-1.5-flash',
    );
  }
}
