import 'dart:convert';

class UserProfileModel {
  final String id;
  final String name;
  final String email;
  final String bio;
  final double targetHoursPerDay;
  final String avatarColorHex;
  final String motivationQuote;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.bio = 'Dedicated learner pursuing software engineering and personal mastery.',
    this.targetHoursPerDay = 2.0,
    this.avatarColorHex = '#10B981',
    this.motivationQuote = 'Small daily improvements over time lead to stunning results.',
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    String? bio,
    double? targetHoursPerDay,
    String? avatarColorHex,
    String? motivationQuote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      targetHoursPerDay: targetHoursPerDay ?? this.targetHoursPerDay,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      motivationQuote: motivationQuote ?? this.motivationQuote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'bio': bio,
      'target_hours_per_day': targetHoursPerDay,
      'avatar_color_hex': avatarColorHex,
      'motivation_quote': motivationQuote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Harsh Patel',
      email: map['email'] as String? ?? 'harsh@progresshub.app',
      bio: map['bio'] as String? ?? 'Dedicated learner pursuing software engineering and personal mastery.',
      targetHoursPerDay: (map['target_hours_per_day'] as num?)?.toDouble() ?? 2.0,
      avatarColorHex: map['avatar_color_hex'] as String? ?? '#10B981',
      motivationQuote: map['motivation_quote'] as String? ?? 'Small daily improvements over time lead to stunning results.',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfileModel.fromJson(String source) =>
      UserProfileModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
