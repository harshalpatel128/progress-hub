import 'dart:convert';

class WebSourceModel {
  final String title;
  final String url;
  final String? snippet;

  WebSourceModel({
    required this.title,
    required this.url,
    this.snippet,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'url': url,
    'snippet': snippet,
  };

  factory WebSourceModel.fromMap(Map<String, dynamic> map) => WebSourceModel(
    title: (map['title'] as String?) ?? 'Source',
    url: (map['url'] as String?) ?? '',
    snippet: map['snippet'] as String?,
  );
}

class MessageAttachmentModel {
  final String path;
  final String name;
  final String type; // 'image', 'pdf', 'docx', 'xlsx', 'csv', 'txt'
  final int? sizeBytes;

  MessageAttachmentModel({
    required this.path,
    required this.name,
    required this.type,
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
    'path': path,
    'name': name,
    'type': type,
    'size_bytes': sizeBytes,
  };

  factory MessageAttachmentModel.fromMap(Map<String, dynamic> map) => MessageAttachmentModel(
    path: (map['path'] as String?) ?? '',
    name: (map['name'] as String?) ?? 'file',
    type: (map['type'] as String?) ?? 'file',
    sizeBytes: map['size_bytes'] as int?,
  );
}

class AiMessageModel {
  final String id;
  final String conversationId;
  final String sender; // 'user', 'ai', 'system'
  final String text;
  final String? actionType;
  final String? actionTitle;
  final String? actionDetails;
  final Map<String, dynamic>? actionData;
  final List<MessageAttachmentModel> attachments;
  final List<WebSourceModel> sources;
  final String? imageUrl; // For AI Generated Images
  final String? generatedFilePath; // For PDF, DOCX, XLSX, PPTX, CSV
  final String? generatedFileName;
  final int thumbsRating; // 0, 1, -1
  final DateTime timestamp;

  AiMessageModel({
    required this.id,
    this.conversationId = 'default_conv',
    required this.sender,
    required this.text,
    this.actionType,
    this.actionTitle,
    this.actionDetails,
    this.actionData,
    this.attachments = const [],
    this.sources = const [],
    this.imageUrl,
    this.generatedFilePath,
    this.generatedFileName,
    this.thumbsRating = 0,
    required this.timestamp,
  });

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  bool get hasAction => actionType != null && actionType != 'info';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasGeneratedFile => generatedFilePath != null && generatedFilePath!.isNotEmpty;
  bool get hasSources => sources.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;

  AiMessageModel copyWith({
    String? id,
    String? conversationId,
    String? sender,
    String? text,
    String? actionType,
    String? actionTitle,
    String? actionDetails,
    Map<String, dynamic>? actionData,
    List<MessageAttachmentModel>? attachments,
    List<WebSourceModel>? sources,
    String? imageUrl,
    String? generatedFilePath,
    String? generatedFileName,
    int? thumbsRating,
    DateTime? timestamp,
  }) {
    return AiMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      actionType: actionType ?? this.actionType,
      actionTitle: actionTitle ?? this.actionTitle,
      actionDetails: actionDetails ?? this.actionDetails,
      actionData: actionData ?? this.actionData,
      attachments: attachments ?? this.attachments,
      sources: sources ?? this.sources,
      imageUrl: imageUrl ?? this.imageUrl,
      generatedFilePath: generatedFilePath ?? this.generatedFilePath,
      generatedFileName: generatedFileName ?? this.generatedFileName,
      thumbsRating: thumbsRating ?? this.thumbsRating,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': sender,
      'content': text,
      'has_action': hasAction ? 1 : 0,
      'action_type': actionType,
      'action_title': actionTitle,
      'action_details': actionDetails,
      'action_data_json': actionData != null ? jsonEncode(actionData) : null,
      'attachments_json': attachments.isNotEmpty ? jsonEncode(attachments.map((a) => a.toMap()).toList()) : null,
      'sources_json': sources.isNotEmpty ? jsonEncode(sources.map((s) => s.toMap()).toList()) : null,
      'image_url': imageUrl,
      'generated_file_path': generatedFilePath,
      'generated_file_name': generatedFileName,
      'thumbs_rating': thumbsRating,
      'created_at': timestamp.toIso8601String(),
    };
  }

  factory AiMessageModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? data;
    final rawData = map['action_data_json'] ?? map['action_data'];
    if (rawData != null && rawData is String && rawData.isNotEmpty) {
      try {
        data = jsonDecode(rawData) as Map<String, dynamic>;
      } catch (_) {}
    }

    final attachmentsList = <MessageAttachmentModel>[];
    if (map['attachments_json'] != null && map['attachments_json'] is String) {
      try {
        final decoded = jsonDecode(map['attachments_json'] as String) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            attachmentsList.add(MessageAttachmentModel.fromMap(item));
          }
        }
      } catch (_) {}
    }

    final sourcesList = <WebSourceModel>[];
    if (map['sources_json'] != null && map['sources_json'] is String) {
      try {
        final decoded = jsonDecode(map['sources_json'] as String) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            sourcesList.add(WebSourceModel.fromMap(item));
          }
        }
      } catch (_) {}
    }

    return AiMessageModel(
      id: (map['id'] as String?) ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: (map['conversation_id'] as String?) ?? 'default_conv',
      sender: (map['role'] as String?) ?? (map['sender'] as String?) ?? 'ai',
      text: (map['content'] as String?) ?? (map['text'] as String?) ?? '',
      actionType: map['action_type'] as String?,
      actionTitle: map['action_title'] as String?,
      actionDetails: map['action_details'] as String?,
      actionData: data,
      attachments: attachmentsList,
      sources: sourcesList,
      imageUrl: map['image_url'] as String?,
      generatedFilePath: map['generated_file_path'] as String?,
      generatedFileName: map['generated_file_name'] as String?,
      thumbsRating: (map['thumbs_rating'] as num?)?.toInt() ?? 0,
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : (map['timestamp'] != null
              ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
