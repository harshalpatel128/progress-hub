class SectionModel {
  final String id;
  final String groupId;
  final String name;
  final int monthNumber;
  final int orderIndex;
  final DateTime createdAt;

  SectionModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.monthNumber = 1,
    this.orderIndex = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'month_number': monthNumber,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SectionModel.fromMap(Map<String, dynamic> map) {
    return SectionModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      name: map['name'] as String,
      monthNumber: (map['month_number'] as int?) ?? 1,
      orderIndex: (map['order_index'] as int?) ?? 1,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
