import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/group_model.dart';
import '../../models/section_model.dart';
import '../../models/topic_model.dart';
import '../../models/alarm_model.dart';
import '../database/database_service.dart';
import '../notifications/notification_service.dart';
import 'ai_image_service.dart';
import 'ai_document_generator.dart';

class AiActionResult {
  final bool success;
  final String action;
  final String title;
  final String message;
  final Map<String, dynamic> data;

  AiActionResult({
    required this.success,
    required this.action,
    required this.title,
    required this.message,
    this.data = const {},
  });
}

class AiToolRegistry {
  static final AiToolRegistry instance = AiToolRegistry._internal();
  AiToolRegistry._internal();

  final _db = DatabaseService.instance;
  final _notifications = NotificationService.instance;

  /// Execute an action requested by the AI
  Future<AiActionResult> execute(String action, Map<String, dynamic> params) async {
    try {
      switch (action.toLowerCase().trim()) {
        case 'create_group':
        case 'create_roadmap':
          return await _createGroup(params);

        case 'update_topic_status':
        case 'complete_topic':
          return await _updateTopicStatus(params);

        case 'set_alarm':
        case 'create_alarm':
          return await _setAlarm(params);

        case 'update_profile':
          return await _updateProfile(params);

        case 'get_app_summary':
        case 'analyze_learning_progress':
          return await _getAppSummary();

        case 'generate_image':
        case 'create_image':
          return await _generateImage(params);

        case 'generate_document':
        case 'create_document':
          return await _generateDocument(params);

        default:
          return AiActionResult(
            success: false,
            action: action,
            title: 'Action Not Supported',
            message: 'Unknown action: $action',
          );
      }
    } catch (e) {
      debugPrint('AiToolRegistry error executing $action: $e');
      return AiActionResult(
        success: false,
        action: action,
        title: 'Execution Error',
        message: 'Failed to execute $action: $e',
      );
    }
  }

  Future<AiActionResult> _createGroup(Map<String, dynamic> params) async {
    final name = (params['name'] as String?)?.trim() ?? 'New Goal Roadmap';
    final category = (params['category'] as String?)?.trim() ?? 'General';
    final duration = (params['duration'] as String?)?.trim() ?? '3 Months';
    final dailyTargetMins = (params['daily_target_minutes'] as num?)?.toInt() ?? 60;
    final colorHex = (params['color_hex'] as String?) ?? '#10B981';
    final iconName = (params['icon_name'] as String?) ?? 'school';

    final groupId = 'goal_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final group = GroupModel(
      id: groupId,
      name: name,
      description: (params['description'] as String?) ?? 'Created dynamically by ProgressAI assistant.',
      category: category,
      durationText: duration,
      dailyTargetMinutes: dailyTargetMins,
      colorHex: colorHex,
      iconName: iconName,
      startDate: now,
      endDate: now.add(const Duration(days: 90)),
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertGroup(group);

    // Parse sections and topics
    int totalTopicsCreated = 0;
    final rawSections = params['sections'] as List<dynamic>?;

    if (rawSections != null && rawSections.isNotEmpty) {
      int sOrder = 1;
      for (final sItem in rawSections) {
        if (sItem is Map) {
          final sName = (sItem['name'] as String?) ?? 'Section $sOrder';
          final monthNum = (sItem['month_number'] as num?)?.toInt() ?? 1;
          final sectionId = 'sec_${const Uuid().v4()}';

          await _db.insertSection(SectionModel(
            id: sectionId,
            groupId: groupId,
            name: sName,
            monthNumber: monthNum,
            orderIndex: sOrder,
            createdAt: now,
          ));

          final topicsList = sItem['topics'] as List<dynamic>?;
          if (topicsList != null) {
            int tOrder = 1;
            for (final tItem in topicsList) {
              String tTitle = '';
              String diff = 'Beginner';
              int estMins = 60;

              if (tItem is String) {
                tTitle = tItem;
              } else if (tItem is Map) {
                tTitle = (tItem['title'] as String?) ?? 'Topic $tOrder';
                diff = (tItem['difficulty'] as String?) ?? 'Beginner';
                estMins = (tItem['estimated_minutes'] as num?)?.toInt() ?? 60;
              }

              if (tTitle.isNotEmpty) {
                await _db.insertTopic(TopicModel(
                  id: 'top_${const Uuid().v4()}',
                  groupId: groupId,
                  sectionId: sectionId,
                  title: tTitle,
                  orderIndex: tOrder,
                  status: TopicStatus.incomplete,
                  priority: 'Normal',
                  difficulty: diff,
                  estimatedMinutes: estMins,
                  notes: 'Generated by ProgressAI',
                  createdAt: now,
                  updatedAt: now,
                ));
                totalTopicsCreated++;
                tOrder++;
              }
            }
          }
          sOrder++;
        }
      }
    } else {
      // Default initial section
      final sectionId = 'sec_${const Uuid().v4()}';
      await _db.insertSection(SectionModel(
        id: sectionId,
        groupId: groupId,
        name: 'Phase 1: Foundations',
        monthNumber: 1,
        orderIndex: 1,
        createdAt: now,
      ));
      await _db.insertTopic(TopicModel(
        id: 'top_${const Uuid().v4()}',
        groupId: groupId,
        sectionId: sectionId,
        title: 'Kickstart & Core Essentials',
        orderIndex: 1,
        status: TopicStatus.incomplete,
        priority: 'Normal',
        difficulty: 'Beginner',
        estimatedMinutes: 60,
        notes: 'Initial roadmap milestone',
        createdAt: now,
        updatedAt: now,
      ));
      totalTopicsCreated = 1;
    }

    return AiActionResult(
      success: true,
      action: 'create_group',
      title: 'Goal Created Successfully',
      message: 'Created "$name" with $totalTopicsCreated topics and daily target of $dailyTargetMins mins.',
      data: {
        'groupId': groupId,
        'groupName': name,
        'totalTopics': totalTopicsCreated,
      },
    );
  }

  Future<AiActionResult> _updateTopicStatus(Map<String, dynamic> params) async {
    final title = (params['topic_name'] as String?) ?? (params['title'] as String?) ?? '';
    final statusStr = ((params['status'] as String?) ?? 'completed').toLowerCase().trim();

    TopicStatus targetStatus = TopicStatus.completed;
    if (statusStr.contains('prog')) {
      targetStatus = TopicStatus.inProgress;
    } else if (statusStr.contains('incomp') || statusStr.contains('pend')) {
      targetStatus = TopicStatus.incomplete;
    }

    final db = await _db.database;
    // Find matching topic by title
    final res = await db.rawQuery(
      "SELECT * FROM topics WHERE title LIKE ? LIMIT 1",
      ['%$title%'],
    );

    if (res.isNotEmpty) {
      final topic = TopicModel.fromMap(res.first);
      final updated = topic.copyWith(
        status: targetStatus,
        completedDate: targetStatus == TopicStatus.completed ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
      await _db.updateTopic(updated);

      return AiActionResult(
        success: true,
        action: 'update_topic_status',
        title: 'Topic Status Updated',
        message: 'Marked "${topic.title}" as ${targetStatus.label}.',
        data: {'topicId': topic.id, 'newStatus': targetStatus.name},
      );
    } else {
      return AiActionResult(
        success: false,
        action: 'update_topic_status',
        title: 'Topic Not Found',
        message: 'Could not find a topic matching "$title".',
      );
    }
  }

  Future<AiActionResult> _setAlarm(Map<String, dynamic> params) async {
    final title = (params['title'] as String?)?.trim() ?? 'ProgressHub Study Session';
    final hour = (params['hour'] as num?)?.toInt() ?? 7;
    final minute = (params['minute'] as num?)?.toInt() ?? 0;
    final repeatDays = (params['repeat_days'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [1, 2, 3, 4, 5, 6, 7];

    final alarmId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final alarm = AlarmModel(
      id: alarmId,
      title: title,
      hour: hour,
      minute: minute,
      repeatDays: repeatDays,
      isEnabled: true,
      createdAt: DateTime.now(),
    );

    await _db.insertAlarm(alarm);
    await _notifications.scheduleAlarm(alarm);

    final timeFormatted = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return AiActionResult(
      success: true,
      action: 'set_alarm',
      title: 'Alarm Scheduled',
      message: 'Alarm "$title" scheduled natively for $timeFormatted daily.',
      data: {'alarmId': alarmId, 'time': timeFormatted},
    );
  }

  Future<AiActionResult> _updateProfile(Map<String, dynamic> params) async {
    final current = await _db.getUserProfile();
    final updated = current.copyWith(
      name: (params['name'] as String?)?.trim(),
      bio: (params['bio'] as String?)?.trim(),
      targetHoursPerDay: (params['target_hours_per_day'] as num?)?.toDouble(),
      motivationQuote: (params['motivation_quote'] as String?)?.trim(),
      updatedAt: DateTime.now(),
    );
    await _db.saveUserProfile(updated);

    return AiActionResult(
      success: true,
      action: 'update_profile',
      title: 'Profile Updated',
      message: 'Updated user profile details successfully.',
      data: updated.toMap(),
    );
  }

  Future<AiActionResult> _getAppSummary() async {
    final groups = await _db.getAllGroups();
    final stats = await _db.getOverallStats();
    final alarms = await _db.getAllAlarms();
    final profile = await _db.getUserProfile();

    final summary = StringBuffer();
    summary.writeln('User: ${profile.name} (Daily Target: ${profile.targetHoursPerDay} hrs)');
    summary.writeln('Active Groups (${groups.length}):');
    for (final g in groups) {
      summary.writeln('- ${g.name} (${g.totalTopics} topics, ${(g.progressPercentage * 100).toStringAsFixed(1)}% done)');
    }
    summary.writeln('Stats: Total ${stats['totalTopics']} topics, ${stats['completedTopics']} completed, Streak: ${stats['currentStreak']} days.');
    summary.writeln('Active Alarms: ${alarms.where((a) => a.isEnabled).length} alarms active.');

    return AiActionResult(
      success: true,
      action: 'get_app_summary',
      title: 'App Overview',
      message: summary.toString(),
      data: {
        'groupsCount': groups.length,
        'completedTopics': stats['completedTopics'],
        'currentStreak': stats['currentStreak'],
      },
    );
  }

  Future<AiActionResult> _generateImage(Map<String, dynamic> params) async {
    final prompt = (params['prompt'] as String?) ?? 'Futuristic landscape';
    final style = (params['style'] as String?) ?? 'Photorealistic';
    final aspectRatio = (params['aspect_ratio'] as String?) ?? '1:1';

    final result = await AiImageService.instance.generateImage(
      prompt: prompt,
      style: style,
      aspectRatio: aspectRatio,
    );

    if (result.success) {
      return AiActionResult(
        success: true,
        action: 'generate_image',
        title: 'AI Image Created',
        message: 'Successfully generated image for: "$prompt"',
        data: {
          'image_path': result.localFilePath,
          'image_url': result.webUrl,
          'prompt': prompt,
        },
      );
    } else {
      return AiActionResult(
        success: false,
        action: 'generate_image',
        title: 'Image Generation Failed',
        message: result.errorMessage ?? 'Failed to generate image',
      );
    }
  }

  Future<AiActionResult> _generateDocument(Map<String, dynamic> params) async {
    final format = (params['format'] as String?)?.toLowerCase().trim() ?? 'pdf';
    final title = (params['title'] as String?) ?? 'Document';
    final content = (params['content'] as String?) ?? '';

    GeneratedDocumentResult res;
    if (format == 'docx') {
      res = await AiDocumentGenerator.instance.generateDocx(title: title, content: content);
    } else if (format == 'xlsx') {
      final rawRows = params['rows'] as List<dynamic>?;
      final rows = rawRows?.map((r) => r is List ? r : [r.toString()]).toList() ?? [
        ['Item', 'Status', 'Date'],
        [title, 'Active', DateTime.now().toString().substring(0, 10)],
      ];
      res = await AiDocumentGenerator.instance.generateXlsx(title: title, rows: rows);
    } else if (format == 'pptx') {
      final rawSlides = params['slides'] as List<dynamic>?;
      final slides = rawSlides?.map((s) => s is Map<String, dynamic> ? s : {'title': s.toString(), 'points': []}).toList() ?? [
        {'title': title, 'points': ['Overview and key findings', 'Action plan']}
      ];
      res = await AiDocumentGenerator.instance.generatePptx(title: title, slides: slides);
    } else if (format == 'csv') {
      final rawRows = params['rows'] as List<dynamic>?;
      final rows = rawRows?.map((r) => r is List ? r : [r.toString()]).toList() ?? [
        ['Title', 'Content'],
        [title, content],
      ];
      res = await AiDocumentGenerator.instance.generateCsv(title: title, rows: rows);
    } else if (format == 'txt') {
      res = await AiDocumentGenerator.instance.generateTxt(title: title, content: content);
    } else {
      res = await AiDocumentGenerator.instance.generatePdf(title: title, content: content);
    }

    if (res.success) {
      return AiActionResult(
        success: true,
        action: 'generate_document',
        title: '${res.fileType.toUpperCase()} Document Created',
        message: 'Successfully generated ${res.fileName} (${res.formattedSize})',
        data: {
          'file_path': res.filePath,
          'file_name': res.fileName,
          'file_type': res.fileType,
          'file_size': res.fileSizeBytes,
        },
      );
    } else {
      return AiActionResult(
        success: false,
        action: 'generate_document',
        title: 'Document Generation Failed',
        message: res.errorMessage ?? 'Could not create document',
      );
    }
  }
}
