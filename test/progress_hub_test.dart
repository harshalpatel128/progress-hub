import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:progress_hub/core/database/database_service.dart';
import 'package:progress_hub/models/group_model.dart';
import 'package:progress_hub/models/section_model.dart';
import 'package:progress_hub/models/topic_model.dart';
import 'package:progress_hub/models/alarm_model.dart';
import 'package:progress_hub/models/daily_progress_model.dart';
import 'package:progress_hub/core/ai/ai_tool_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.initForTest();
  });

  group('Curriculum Import Tests (Requirement 2)', () {
    test('Imports exactly 405 topics across 6 months on first launch', () async {
      final count = await dbService.importPythonCurriculum(force: true);
      expect(count, equals(405));

      final groups = await dbService.getAllGroups();
      expect(groups.length, equals(1));
      final defaultGroup = groups.first;
      expect(defaultGroup.id, equals('python_ai_roadmap_default'));
      expect(defaultGroup.name, equals('Python & AI Developer Roadmap'));
      expect(defaultGroup.totalTopics, equals(405));

      // Verify Month Divisions & exact topic counts
      final db = await dbService.database;

      final month1Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 1
      '''));
      expect(month1Count, equals(95)); // Month 1: 95 Topics

      final month2Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 2
      '''));
      expect(month2Count, equals(60)); // Month 2: 60 Topics

      final month3Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 3
      '''));
      expect(month3Count, equals(70)); // Month 3: 70 Topics

      final month4Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 4
      '''));
      expect(month4Count, equals(60)); // Month 4: 60 Topics

      final month5Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 5
      '''));
      expect(month5Count, equals(65)); // Month 5: 65 Topics

      final month6Count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM topics t
        JOIN sections s ON t.section_id = s.id
        WHERE s.month_number = 6
      '''));
      expect(month6Count, equals(55)); // Month 6: 55 Topics

      // Total sum verification
      expect(
        month1Count! + month2Count! + month3Count! + month4Count! + month5Count! + month6Count!,
        equals(405),
      );
    });

    test('Second import without force never duplicates topics', () async {
      await dbService.importPythonCurriculum(force: true);
      // Run import again without force
      final count = await dbService.importPythonCurriculum(force: false);
      expect(count, equals(405));

      final groups = await dbService.getAllGroups();
      expect(groups.length, equals(1));
      expect(groups.first.totalTopics, equals(405));
    });
  });

  group('Dynamic Group Management (Requirement 3)', () {
    test('Can create unlimited independent custom groups with custom hierarchy', () async {
      final now = DateTime.now();

      // Create Gym & Fitness Group
      final gymGroup = GroupModel(
        id: 'group_gym',
        name: 'Gym & Fitness',
        description: 'Strength training and cardio regime',
        category: 'Fitness',
        colorHex: '#EF4444',
        iconName: 'fitness',
        dailyTargetMinutes: 45,
        createdAt: now,
        updatedAt: now,
      );
      await dbService.insertGroup(gymGroup);

      // Add custom sections: Month 1, Week 1 & Week 2
      final secWeek1 = SectionModel(
        id: 'sec_gym_w1',
        groupId: gymGroup.id,
        name: 'Week 1: Foundations',
        monthNumber: 1,
        orderIndex: 1,
        createdAt: now,
      );
      await dbService.insertSection(secWeek1);

      // Add Topics to gym group
      final chestTopic = TopicModel(
        id: 'top_chest',
        groupId: gymGroup.id,
        sectionId: secWeek1.id,
        orderIndex: 1,
        title: 'Chest Workout (Bench Press & Pushups)',
        priority: 'High',
        difficulty: 'Beginner',
        estimatedMinutes: 45,
        createdAt: now,
        updatedAt: now,
      );
      await dbService.insertTopic(chestTopic);

      final retrieved = await dbService.getGroupById(gymGroup.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Gym & Fitness'));
      expect(retrieved.totalTopics, equals(1));

      // Test Deletion
      await dbService.deleteGroup(gymGroup.id);
      final deleted = await dbService.getGroupById(gymGroup.id);
      expect(deleted, isNull);
    });
  });

  group('Topic Status Management & Persistence (Requirement 4)', () {
    test('Updates status instantly and persists completed date', () async {
      await dbService.importPythonCurriculum(force: true);

      final topics = await dbService.getTopicsForGroup('python_ai_roadmap_default', limit: 1);
      expect(topics.isNotEmpty, isTrue);
      final firstTopic = topics.first;

      expect(firstTopic.status, equals(TopicStatus.incomplete));
      expect(firstTopic.completedDate, isNull);

      // Mark in progress
      await dbService.updateTopicStatus(firstTopic.id, TopicStatus.inProgress);
      var updated = await dbService.getTopicById(firstTopic.id);
      expect(updated!.status, equals(TopicStatus.inProgress));
      expect(updated.completedDate, isNull);

      // Mark completed
      await dbService.updateTopicStatus(firstTopic.id, TopicStatus.completed);
      updated = await dbService.getTopicById(firstTopic.id);
      expect(updated!.status, equals(TopicStatus.completed));
      expect(updated.completedDate, isNotNull);

      // Reset to incomplete
      await dbService.updateTopicStatus(firstTopic.id, TopicStatus.incomplete);
      updated = await dbService.getTopicById(firstTopic.id);
      expect(updated!.status, equals(TopicStatus.incomplete));
      expect(updated.completedDate, isNull);
    });
  });

  group('Alarms & Scheduling Tests (Requirements 5 & 9)', () {
    test('Creates, edits and queries independent alarms with repeat days', () async {
      final alarm = AlarmModel(
        id: 101,
        title: 'Python Morning Code Session',
        hour: 7,
        minute: 0,
        repeatDays: [1, 2, 3, 4, 5],
        groupId: 'python_ai_roadmap_default',
        createdAt: DateTime.now(),
      );

      await dbService.insertAlarm(alarm);
      var alarms = await dbService.getAllAlarms();
      expect(alarms.length, equals(1));
      expect(alarms.first.title, equals('Python Morning Code Session'));
      expect(alarms.first.repeatDays, equals([1, 2, 3, 4, 5]));

      // Update alarm
      final modified = alarm.copyWith(hour: 6, minute: 30, title: 'Early Python Study');
      await dbService.updateAlarm(modified);

      alarms = await dbService.getAllAlarms();
      expect(alarms.first.hour, equals(6));
      expect(alarms.first.minute, equals(30));
      expect(alarms.first.title, equals('Early Python Study'));

      // Delete alarm
      await dbService.deleteAlarm(101);
      alarms = await dbService.getAllAlarms();
      expect(alarms.isEmpty, isTrue);
    });

    test('Stores and updates custom audio song path and name for alarms', () async {
      final alarmWithSong = AlarmModel(
        id: 301,
        title: 'Morning Motivation Song',
        hour: 6,
        minute: 0,
        customAudioPath: '/data/user/0/com.progresshub.progress_hub/app_flutter/custom_alarms/song.mp3',
        customAudioName: 'MyFavoriteSong.mp3',
        createdAt: DateTime.now(),
      );

      await dbService.insertAlarm(alarmWithSong);
      final retrieved = await dbService.getAlarmById(301);

      expect(retrieved, isNotNull);
      expect(retrieved!.customAudioPath, equals('/data/user/0/com.progresshub.progress_hub/app_flutter/custom_alarms/song.mp3'));
      expect(retrieved.customAudioName, equals('MyFavoriteSong.mp3'));

      await dbService.deleteAlarm(301);
    });

    test('Filters independent alarms per group and auto-creates initial section & schedules on new group', () async {
      const g1 = 'group_alpha';
      const g2 = 'group_beta';

      await dbService.insertGroup(GroupModel(id: g1, name: 'Alpha Goal', createdAt: DateTime.now(), updatedAt: DateTime.now()));
      await dbService.insertGroup(GroupModel(id: g2, name: 'Beta Goal', createdAt: DateTime.now(), updatedAt: DateTime.now()));

      // Verify automatic section and schedules creation
      final alphaSections = await dbService.getSectionsForGroup(g1);
      expect(alphaSections.isNotEmpty, isTrue);
      expect(alphaSections.first.name, contains('Section 1'));

      final alphaSchedules = await dbService.getSchedulesForGroup(g1);
      expect(alphaSchedules.length, equals(7)); // Mon-Sun

      // Add independent alarms
      await dbService.insertAlarm(AlarmModel(
        id: 201,
        title: 'Alpha Morning Alarm',
        hour: 7,
        minute: 0,
        groupId: g1,
        createdAt: DateTime.now(),
      ));
      await dbService.insertAlarm(AlarmModel(
        id: 202,
        title: 'Beta Evening Warning',
        hour: 20,
        minute: 30,
        groupId: g2,
        createdAt: DateTime.now(),
      ));

      final aAlarms = await dbService.getAlarmsForGroup(g1);
      final bAlarms = await dbService.getAlarmsForGroup(g2);

      expect(aAlarms.length, equals(1));
      expect(aAlarms.first.title, equals('Alpha Morning Alarm'));
      expect(bAlarms.length, equals(1));
      expect(bAlarms.first.title, equals('Beta Evening Warning'));

      // Cleanup
      await dbService.deleteAlarm(201);
      await dbService.deleteAlarm(202);
      await dbService.deleteGroup(g1);
      await dbService.deleteGroup(g2);
    });
  });

  group('Daily Progress & Streak Calculation (Requirements 7 & 10)', () {
    test('Daily evaluation marks target correctly and calculates streak without penalizing rest days', () async {
      const gId = 'test_group_progress';
      final now = DateTime.now();

      final group = GroupModel(
        id: gId,
        name: 'Daily Test Group',
        dailyTargetMinutes: 60,
        createdAt: now,
        updatedAt: now,
      );
      await dbService.insertGroup(group);

      // Day 1: Completed target
      await dbService.setDailyProgress(DailyProgressModel(
        id: '${gId}_2026-11-01',
        groupId: gId,
        dateString: '2026-11-01',
        completedMinutes: 60,
        topicsCompletedCount: 1,
        status: DailyProgressStatus.completed,
        updatedAt: now,
      ));

      // Day 2: Completed target
      await dbService.setDailyProgress(DailyProgressModel(
        id: '${gId}_2026-11-02',
        groupId: gId,
        dateString: '2026-11-02',
        completedMinutes: 75,
        topicsCompletedCount: 2,
        status: DailyProgressStatus.completed,
        updatedAt: now,
      ));

      // Day 3: Scheduled Rest Day (Should NOT break streak!)
      await dbService.setDailyProgress(DailyProgressModel(
        id: '${gId}_2026-11-03',
        groupId: gId,
        dateString: '2026-11-03',
        completedMinutes: 0,
        topicsCompletedCount: 0,
        status: DailyProgressStatus.restDay,
        updatedAt: now,
      ));

      // Day 4: Completed target
      await dbService.setDailyProgress(DailyProgressModel(
        id: '${gId}_2026-11-04',
        groupId: gId,
        dateString: '2026-11-04',
        completedMinutes: 60,
        topicsCompletedCount: 1,
        status: DailyProgressStatus.completed,
        updatedAt: now,
      ));

      final streak = await dbService.calculateStreaks(groupId: gId);
      expect(streak['currentStreak'], equals(3)); // 3 active study days maintained across the rest day
      expect(streak['missedDaysCount'], equals(0)); // Rest day was NOT counted as missed!
    });
  });

  group('Backup & Restore Integrity (Requirement 14)', () {
    test('Exports all database contents to JSON and restores successfully', () async {
      await dbService.importPythonCurriculum(force: true);

      final exportedJson = await dbService.exportBackupJson();
      expect(exportedJson.isNotEmpty, isTrue);

      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      expect(decoded['app_name'], equals('ProgressHub'));
      expect((decoded['topics'] as List).length, equals(405));

      // Clear or mutate database, then restore
      final db = await dbService.database;
      await db.delete('topics');
      expect(Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM topics')), equals(0));

      // Restore from JSON
      final success = await dbService.restoreFromBackupJson(exportedJson);
      expect(success, isTrue);

      final restoredCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM topics'));
      expect(restoredCount, equals(405));
    });
  });

  group('User Profile Persistence', () {
    test('Creates default user profile and allows updates', () async {
      final profile = await dbService.getUserProfile();
      expect(profile.name, isNotEmpty);
      expect(profile.email, contains('@'));

      final updated = profile.copyWith(
        name: 'Harsh Developer',
        bio: 'Building world-class Flutter apps.',
        targetHoursPerDay: 3.5,
      );
      await dbService.saveUserProfile(updated);

      final retrieved = await dbService.getUserProfile();
      expect(retrieved.name, equals('Harsh Developer'));
      expect(retrieved.bio, equals('Building world-class Flutter apps.'));
      expect(retrieved.targetHoursPerDay, equals(3.5));
    });
  });

  group('ProgressAI Autonomous Controller Engine', () {
    test('AI Tool creates custom roadmap dynamically in SQLite', () async {
      final result = await AiToolRegistry.instance.execute('create_group', {
        'name': 'AI Test Roadmap',
        'category': 'AI Testing',
        'duration': '3 Months',
        'daily_target_minutes': 45,
        'sections': [
          {
            'name': 'Phase 1: Basics',
            'month_number': 1,
            'topics': ['AI Topic 1', 'AI Topic 2', 'AI Topic 3'],
          },
        ],
      });

      expect(result.success, isTrue);
      expect(result.data['totalTopics'], equals(3));

      final groups = await dbService.getAllGroups();
      final aiGroup = groups.firstWhere((g) => g.name == 'AI Test Roadmap');
      expect(aiGroup.dailyTargetMinutes, equals(45));

      final topics = await dbService.getTopicsForGroup(aiGroup.id);
      expect(topics.length, equals(3));
      expect(topics.first.title, equals('AI Topic 1'));

      // Test AI completing a topic
      final updateResult = await AiToolRegistry.instance.execute('update_topic_status', {
        'topic_name': 'AI Topic 1',
        'status': 'completed',
      });
      expect(updateResult.success, isTrue);

      final updatedTopics = await dbService.getTopicsForGroup(aiGroup.id);
      expect(updatedTopics.first.status, equals(TopicStatus.completed));

      // Cleanup
      await dbService.deleteGroup(aiGroup.id);
    });
  });
}
