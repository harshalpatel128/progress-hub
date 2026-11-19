import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../models/group_model.dart';
import '../../models/section_model.dart';
import '../../models/topic_model.dart';
import '../../models/alarm_model.dart';
import '../../models/schedule_model.dart';
import '../../models/daily_progress_model.dart';
import '../../models/notification_log_model.dart';
import '../../models/user_profile_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase({String? inMemoryPath}) async {
    // Initialize FFI SQLite factory for Windows, Linux, and macOS Desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (inMemoryPath != null) {
      path = inMemoryPath;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      path = p.join(docsDir.path, 'progress_hub.db');
    }

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    try {
      await db.execute('ALTER TABLE alarms ADD COLUMN custom_audio_path TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE alarms ADD COLUMN custom_audio_name TEXT');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT NOT NULL,
          bio TEXT DEFAULT '',
          target_hours_per_day REAL DEFAULT 2.0,
          avatar_color_hex TEXT DEFAULT '#10B981',
          motivation_quote TEXT DEFAULT 'Small daily improvements over time lead to stunning results.',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_memory (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          user_input_context TEXT,
          confidence REAL DEFAULT 1.0,
          times_referenced INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_conversations (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_pinned INTEGER DEFAULT 0,
          model_used TEXT DEFAULT 'gemini-1.5-flash'
        )
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          has_action INTEGER DEFAULT 0,
          action_type TEXT,
          action_title TEXT,
          action_details TEXT,
          action_data_json TEXT,
          attachments_json TEXT,
          sources_json TEXT,
          image_url TEXT,
          generated_file_path TEXT,
          generated_file_name TEXT,
          thumbs_rating INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (conversation_id) REFERENCES ai_conversations (id) ON DELETE CASCADE
        )
      ''');
    } catch (_) {}

    return db;
  }

  // Allow tests to inject an in-memory database
  Future<void> initForTest({Database? testDb}) async {
    if (testDb != null) {
      _database = testDb;
    } else {
      _database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // App metadata table for migrations and seed flags
    batch.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Groups table
    batch.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        icon_name TEXT DEFAULT 'school',
        color_hex TEXT DEFAULT '#2196F3',
        category TEXT DEFAULT 'General',
        start_date TEXT,
        end_date TEXT,
        duration_text TEXT DEFAULT '6 Months',
        daily_target_minutes INTEGER DEFAULT 60,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    // Sections table
    batch.execute('''
      CREATE TABLE sections (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        name TEXT NOT NULL,
        month_number INTEGER DEFAULT 1,
        order_index INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Topics table
    batch.execute('''
      CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        order_index INTEGER DEFAULT 1,
        title TEXT NOT NULL,
        status TEXT DEFAULT 'incomplete',
        priority TEXT DEFAULT 'Normal',
        difficulty TEXT DEFAULT 'Beginner',
        start_date TEXT,
        due_date TEXT,
        completed_date TEXT,
        estimated_minutes INTEGER DEFAULT 60,
        actual_minutes INTEGER DEFAULT 0,
        notes TEXT DEFAULT '',
        subtasks_json TEXT DEFAULT '[]',
        resources_json TEXT DEFAULT '[]',
        attachments_json TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE
      )
    ''');

    // Alarms table
    batch.execute('''
      CREATE TABLE alarms (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        is_enabled INTEGER DEFAULT 1,
        repeat_days_json TEXT DEFAULT '[1,2,3,4,5,6,7]',
        group_id TEXT,
        topic_id TEXT,
        sound_name TEXT DEFAULT 'default',
        custom_audio_path TEXT,
        custom_audio_name TEXT,
        vibration_enabled INTEGER DEFAULT 1,
        snooze_duration_minutes INTEGER DEFAULT 10,
        created_at TEXT NOT NULL
      )
    ''');

    // Schedules table
    batch.execute('''
      CREATE TABLE schedules (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT DEFAULT '09:00',
        end_time TEXT DEFAULT '10:00',
        session_minutes INTEGER DEFAULT 60,
        break_minutes INTEGER DEFAULT 10,
        is_rest_day INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Daily progress table
    batch.execute('''
      CREATE TABLE daily_progress (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        date_string TEXT NOT NULL,
        target_minutes INTEGER DEFAULT 60,
        completed_minutes INTEGER DEFAULT 0,
        topics_completed_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'missed',
        notes TEXT DEFAULT '',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Notification logs table
    batch.execute('''
      CREATE TABLE notification_logs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT DEFAULT 'scheduled_reminder',
        group_id TEXT,
        topic_id TEXT,
        timestamp TEXT NOT NULL,
        is_read INTEGER DEFAULT 0
      )
    ''');

    // User profile table
    batch.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        bio TEXT DEFAULT '',
        target_hours_per_day REAL DEFAULT 2.0,
        avatar_color_hex TEXT DEFAULT '#10B981',
        motivation_quote TEXT DEFAULT 'Small daily improvements over time lead to stunning results.',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // AI Long-term memory & continuous self-learning table
    batch.execute('''
      CREATE TABLE ai_memory (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        user_input_context TEXT,
        confidence REAL DEFAULT 1.0,
        times_referenced INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // AI Multi-conversation chat history tables
    batch.execute('''
      CREATE TABLE ai_conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        model_used TEXT DEFAULT 'gemini-1.5-flash'
      )
    ''');

    batch.execute('''
      CREATE TABLE ai_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        has_action INTEGER DEFAULT 0,
        action_type TEXT,
        action_title TEXT,
        action_details TEXT,
        action_data_json TEXT,
        attachments_json TEXT,
        sources_json TEXT,
        image_url TEXT,
        generated_file_path TEXT,
        generated_file_name TEXT,
        thumbs_rating INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES ai_conversations (id) ON DELETE CASCADE
      )
    ''');

    // Indexes for fast lookup
    batch.execute('CREATE INDEX idx_topics_group_id ON topics (group_id)');
    batch.execute('CREATE INDEX idx_topics_section_id ON topics (section_id)');
    batch.execute('CREATE INDEX idx_topics_status ON topics (status)');
    batch.execute('CREATE INDEX idx_daily_progress_date ON daily_progress (date_string)');
    batch.execute('CREATE INDEX idx_daily_progress_group ON daily_progress (group_id, date_string)');
    batch.execute('CREATE INDEX idx_ai_memory_key ON ai_memory (key)');
    batch.execute('CREATE INDEX idx_ai_conversations_updated ON ai_conversations (updated_at DESC)');
    batch.execute('CREATE INDEX idx_ai_messages_conv ON ai_messages (conversation_id)');

    await batch.commit();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations handler for future versions
  }

  // -------------------------------------------------------------
  // CURRICULUM SEED & IMPORT ENGINE
  // -------------------------------------------------------------

  Future<bool> isCurriculumImported() async {
    final db = await database;
    final res = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: ['curriculum_imported_v1'],
    );
    return res.isNotEmpty && res.first['value'] == 'true';
  }

  Future<int> importPythonCurriculum({bool force = false}) async {
    final db = await database;
    if (!force && await isCurriculumImported()) {
      // Check if Python group topics actually exist
      final count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM topics WHERE group_id = 'python_ai_roadmap_default'"
      )) ?? 0;
      if (count == 405) {
        return count; // Already imported
      }
    }

    String jsonString = '';
    try {
      jsonString = await rootBundle.loadString('assets/curriculum/python_ai_roadmap.json');
    } catch (_) {
      // Fallback for file system execution (unit tests or direct file load)
      final f = File('assets/curriculum/python_ai_roadmap.json');
      if (f.existsSync()) {
        jsonString = f.readAsStringSync();
      }
    }

    if (jsonString.isEmpty) {
      throw Exception('Curriculum JSON file not found in assets/curriculum/python_ai_roadmap.json');
    }

    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final topicsList = data['topics'] as List<dynamic>;

    const groupId = 'python_ai_roadmap_default';
    final now = DateTime.now();

    await db.transaction((txn) async {
      // Delete existing default group if force re-importing
      await txn.delete('topics', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('sections', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('schedules', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('groups', where: 'id = ?', whereArgs: [groupId]);

      // 1. Insert default group
      await txn.insert('groups', {
        'id': groupId,
        'name': 'Python & AI Developer Roadmap',
        'description': 'Comprehensive 6-Month Mastery Roadmap from Python Core to Advanced AI, Machine Learning, Docker, AWS & Technical Interviews (405 Topics).',
        'icon_name': 'code',
        'color_hex': '#10B981',
        'category': 'Coding & AI',
        'start_date': now.toIso8601String(),
        'end_date': now.add(const Duration(days: 180)).toIso8601String(),
        'duration_text': '6 Months',
        'daily_target_minutes': 90,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_archived': 0,
      });

      // 2. Insert Default Schedules (Mon-Fri study, Sat-Sun review/rest)
      for (int day = 1; day <= 7; day++) {
        await txn.insert('schedules', {
          'id': _uuid.v4(),
          'group_id': groupId,
          'day_of_week': day,
          'start_time': '07:00',
          'end_time': '08:30',
          'session_minutes': 90,
          'break_minutes': 15,
          'is_rest_day': day == 7 ? 1 : 0,
          'created_at': now.toIso8601String(),
        });
      }

      // 3. Collect unique sections and insert them
      final Map<String, String> sectionNameToId = {};
      final sectionsBatch = txn.batch();

      int sectionOrder = 1;
      for (final t in topicsList) {
        final secName = t['section'] as String;
        final mNum = (t['month'] as int?) ?? 1;

        if (!sectionNameToId.containsKey(secName)) {
          final secId = 'sec_python_$sectionOrder';
          sectionNameToId[secName] = secId;

          sectionsBatch.insert('sections', {
            'id': secId,
            'group_id': groupId,
            'name': secName,
            'month_number': mNum,
            'order_index': sectionOrder,
            'created_at': now.toIso8601String(),
          });
          sectionOrder++;
        }
      }
      await sectionsBatch.commit(noResult: true);

      // 4. Batch insert all 405 topics
      final topicsBatch = txn.batch();
      for (final item in topicsList) {
        final t = item as Map<String, dynamic>;
        final secId = sectionNameToId[t['section'] as String]!;
        final orderIdx = (t['orderIndex'] as int?) ?? 1;

        topicsBatch.insert('topics', {
          'id': 'top_py_$orderIdx',
          'group_id': groupId,
          'section_id': secId,
          'order_index': orderIdx,
          'title': t['title'] as String,
          'status': t['status'] as String? ?? 'incomplete',
          'priority': t['priority'] as String? ?? 'Normal',
          'difficulty': t['difficulty'] as String? ?? 'Beginner',
          'start_date': null,
          'due_date': null,
          'completed_date': null,
          'estimated_minutes': (t['estimatedMinutes'] as int?) ?? 90,
          'actual_minutes': 0,
          'notes': t['notes'] as String? ?? '',
          'subtasks_json': jsonEncode(t['subtasks'] ?? []),
          'resources_json': jsonEncode(t['resources'] ?? []),
          'attachments_json': '[]',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      await topicsBatch.commit(noResult: true);

      // 5. Mark as imported
      await txn.insert('app_metadata', {
        'key': 'curriculum_imported_v1',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM topics WHERE group_id = '$groupId'"
    )) ?? 0;

    return totalCount;
  }

  // -------------------------------------------------------------
  // GROUPS CRUD
  // -------------------------------------------------------------

  Future<List<GroupModel>> getAllGroups({bool includeArchived = false}) async {
    final db = await database;
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await db.query('groups', where: where, orderBy: 'created_at ASC');

    List<GroupModel> results = [];
    for (final row in rows) {
      final gId = row['id'] as String;
      final counts = await getGroupTopicCounts(gId);
      results.add(GroupModel.fromMap(
        row,
        totalTopics: counts['total'] ?? 0,
        completedTopics: counts['completed'] ?? 0,
        inProgressTopics: counts['inProgress'] ?? 0,
      ));
    }
    return results;
  }

  Future<GroupModel?> getGroupById(String groupId) async {
    final db = await database;
    final rows = await db.query('groups', where: 'id = ?', whereArgs: [groupId]);
    if (rows.isEmpty) return null;

    final counts = await getGroupTopicCounts(groupId);
    return GroupModel.fromMap(
      rows.first,
      totalTopics: counts['total'] ?? 0,
      completedTopics: counts['completed'] ?? 0,
      inProgressTopics: counts['inProgress'] ?? 0,
    );
  }

  Future<Map<String, int>> getGroupTopicCounts(String groupId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress
      FROM topics
      WHERE group_id = ?
    ''', [groupId]);

    if (res.isEmpty) return {'total': 0, 'completed': 0, 'inProgress': 0};
    return {
      'total': (res.first['total'] as int?) ?? 0,
      'completed': (res.first['completed'] as int?) ?? 0,
      'inProgress': (res.first['in_progress'] as int?) ?? 0,
    };
  }

  Future<void> insertGroup(GroupModel group) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // Create default schedules for Mon-Sun
      final now = DateTime.now().toIso8601String();
      for (int day = 1; day <= 7; day++) {
        await txn.insert('schedules', {
          'id': _uuid.v4(),
          'group_id': group.id,
          'day_of_week': day,
          'start_time': '09:00',
          'end_time': '10:00',
          'session_minutes': group.dailyTargetMinutes,
          'break_minutes': 10,
          'is_rest_day': day == 7 ? 1 : 0,
          'created_at': now,
        });
      }

      // Create initial default section so topics can be added immediately
      await txn.insert('sections', {
        'id': 'sec_${_uuid.v4()}',
        'group_id': group.id,
        'name': 'Section 1: Foundations & Core Concepts',
        'month_number': 1,
        'order_index': 1,
        'created_at': now,
      });
    });
  }

  Future<void> updateGroup(GroupModel group) async {
    final db = await database;
    await db.update('groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('daily_progress', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('schedules', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('alarms', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('topics', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('sections', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }

  // -------------------------------------------------------------
  // SECTIONS CRUD
  // -------------------------------------------------------------

  Future<List<SectionModel>> getSectionsForGroup(String groupId) async {
    final db = await database;
    final rows = await db.query(
      'sections',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'order_index ASC',
    );
    return rows.map((e) => SectionModel.fromMap(e)).toList();
  }

  Future<void> insertSection(SectionModel section) async {
    final db = await database;
    await db.insert('sections', section.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSection(String sectionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('topics', where: 'section_id = ?', whereArgs: [sectionId]);
      await txn.delete('sections', where: 'id = ?', whereArgs: [sectionId]);
    });
  }

  // -------------------------------------------------------------
  // TOPICS CRUD & STATUS
  // -------------------------------------------------------------

  Future<List<TopicModel>> getTopicsForGroup(String groupId, {
    String? sectionId,
    TopicStatus? status,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<String> whereClauses = ['t.group_id = ?'];
    final List<dynamic> whereArgs = [groupId];

    if (sectionId != null) {
      whereClauses.add('t.section_id = ?');
      whereArgs.add(sectionId);
    }
    if (status != null) {
      whereClauses.add('t.status = ?');
      whereArgs.add(status.dbValue);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(t.title LIKE ? OR t.notes LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final sql = '''
      SELECT t.*, s.name as section_name, s.month_number
      FROM topics t
      LEFT JOIN sections s ON t.section_id = s.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY t.order_index ASC
      ${limit != null ? 'LIMIT $limit OFFSET ${offset ?? 0}' : ''}
    ''';

    final rows = await db.rawQuery(sql, whereArgs);
    return rows.map((e) => TopicModel.fromMap(e)).toList();
  }

  Future<TopicModel?> getTopicById(String topicId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*, s.name as section_name, s.month_number
      FROM topics t
      LEFT JOIN sections s ON t.section_id = s.id
      WHERE t.id = ?
    ''', [topicId]);

    if (rows.isEmpty) return null;
    return TopicModel.fromMap(rows.first);
  }

  Future<void> insertTopic(TopicModel topic) async {
    final db = await database;
    await db.insert('topics', topic.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTopic(TopicModel topic) async {
    final db = await database;
    await db.update('topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
  }

  Future<void> updateTopicStatus(String topicId, TopicStatus newStatus) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final completedDate = newStatus == TopicStatus.completed ? now : null;

    await db.update(
      'topics',
      {
        'status': newStatus.dbValue,
        'completed_date': completedDate,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> deleteTopic(String topicId) async {
    final db = await database;
    await db.delete('topics', where: 'id = ?', whereArgs: [topicId]);
  }

  // -------------------------------------------------------------
  // ALARMS CRUD
  // -------------------------------------------------------------

  Future<List<AlarmModel>> getAllAlarms() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*, g.name as group_name, t.title as topic_name
      FROM alarms a
      LEFT JOIN groups g ON a.group_id = g.id
      LEFT JOIN topics t ON a.topic_id = t.id
      ORDER BY a.hour ASC, a.minute ASC
    ''');
    return rows.map((e) => AlarmModel.fromMap(e)).toList();
  }

  Future<AlarmModel?> getAlarmById(int alarmId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*, g.name as group_name, t.title as topic_name
      FROM alarms a
      LEFT JOIN groups g ON a.group_id = g.id
      LEFT JOIN topics t ON a.topic_id = t.id
      WHERE a.id = ?
    ''', [alarmId]);
    if (rows.isEmpty) return null;
    return AlarmModel.fromMap(rows.first);
  }

  Future<List<AlarmModel>> getAlarmsForGroup(String groupId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.*, g.name as group_name, t.title as topic_name
      FROM alarms a
      LEFT JOIN groups g ON a.group_id = g.id
      LEFT JOIN topics t ON a.topic_id = t.id
      WHERE a.group_id = ?
      ORDER BY a.hour ASC, a.minute ASC
    ''', [groupId]);
    return rows.map((e) => AlarmModel.fromMap(e)).toList();
  }

  Future<void> insertAlarm(AlarmModel alarm) async {
    final db = await database;
    await db.insert('alarms', alarm.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    final db = await database;
    await db.update('alarms', alarm.toMap(), where: 'id = ?', whereArgs: [alarm.id]);
  }

  Future<void> deleteAlarm(int alarmId) async {
    final db = await database;
    await db.delete('alarms', where: 'id = ?', whereArgs: [alarmId]);
  }

  // -------------------------------------------------------------
  // SCHEDULES CRUD
  // -------------------------------------------------------------

  Future<List<ScheduleModel>> getSchedulesForGroup(String groupId) async {
    final db = await database;
    final rows = await db.query(
      'schedules',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'day_of_week ASC',
    );
    return rows.map((e) => ScheduleModel.fromMap(e)).toList();
  }

  Future<void> insertSchedule(ScheduleModel schedule) async {
    final db = await database;
    await db.insert('schedules', schedule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    final db = await database;
    await db.update('schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
  }

  // -------------------------------------------------------------
  // DAILY PROGRESS CRUD & STREAK LOGIC
  // -------------------------------------------------------------

  Future<DailyProgressModel?> getDailyProgress(String groupId, String dateString) async {
    final db = await database;
    final rows = await db.query(
      'daily_progress',
      where: 'group_id = ? AND date_string = ?',
      whereArgs: [groupId, dateString],
    );
    if (rows.isEmpty) return null;
    return DailyProgressModel.fromMap(rows.first);
  }

  Future<List<DailyProgressModel>> getDailyProgressRange(String? groupId, String startDate, String endDate) async {
    final db = await database;
    final List<String> whereClauses = ['date_string >= ? AND date_string <= ?'];
    final List<dynamic> whereArgs = [startDate, endDate];

    if (groupId != null) {
      whereClauses.add('group_id = ?');
      whereArgs.add(groupId);
    }

    final rows = await db.query(
      'daily_progress',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date_string ASC',
    );
    return rows.map((e) => DailyProgressModel.fromMap(e)).toList();
  }

  Future<void> setDailyProgress(DailyProgressModel progress) async {
    final db = await database;
    await db.insert(
      'daily_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -------------------------------------------------------------
  // NOTIFICATION LOGS CRUD
  // -------------------------------------------------------------

  Future<List<NotificationLogModel>> getNotificationLogs({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'notification_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((e) => NotificationLogModel.fromMap(e)).toList();
  }

  Future<void> insertNotificationLog(NotificationLogModel log) async {
    final db = await database;
    await db.insert('notification_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markNotificationAsRead(String id) async {
    final db = await database;
    await db.update('notification_logs', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllNotificationLogs() async {
    final db = await database;
    await db.delete('notification_logs');
  }

  // -------------------------------------------------------------
  // OVERALL DASHBOARD & ANALYTICS STATS
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> getOverallStats({String? groupId}) async {
    final db = await database;
    final groupClause = groupId != null ? "WHERE group_id = '$groupId'" : '';

    final totalGroupsRes = await db.rawQuery('SELECT COUNT(*) as c FROM groups WHERE is_archived = 0');
    final totalGroups = (totalGroupsRes.first['c'] as int?) ?? 0;

    final topicStatsRes = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress,
        SUM(CASE WHEN status = 'incomplete' THEN 1 ELSE 0 END) as incomplete,
        SUM(actual_minutes) as actual_minutes,
        SUM(estimated_minutes) as estimated_minutes
      FROM topics
      $groupClause
    ''');

    final tStats = topicStatsRes.first;
    final totalTopics = (tStats['total'] as int?) ?? 0;
    final completedTopics = (tStats['completed'] as int?) ?? 0;
    final inProgressTopics = (tStats['in_progress'] as int?) ?? 0;
    final incompleteTopics = (tStats['incomplete'] as int?) ?? 0;
    final totalActualMinutes = (tStats['actual_minutes'] as int?) ?? 0;

    // Calculate current streak & longest streak from daily_progress
    final streakStats = await calculateStreaks(groupId: groupId);

    return {
      'totalGroups': totalGroups,
      'totalTopics': totalTopics,
      'completedTopics': completedTopics,
      'inProgressTopics': inProgressTopics,
      'incompleteTopics': incompleteTopics,
      'overallPercentage': totalTopics > 0 ? (completedTopics / totalTopics) : 0.0,
      'totalStudyMinutes': totalActualMinutes,
      'currentStreak': streakStats['currentStreak'],
      'longestStreak': streakStats['longestStreak'],
      'missedDaysCount': streakStats['missedDaysCount'],
    };
  }

  Future<Map<String, int>> calculateStreaks({String? groupId}) async {
    final db = await database;
    final groupClause = groupId != null ? "WHERE group_id = '$groupId'" : '';

    final rows = await db.rawQuery('''
      SELECT date_string, status
      FROM daily_progress
      $groupClause
      ORDER BY date_string ASC
    ''');

    int currentStreak = 0;
    int longestStreak = 0;
    int missedDaysCount = 0;
    int tempStreak = 0;

    for (final row in rows) {
      final status = row['status'] as String;
      if (status == 'completed' || status == 'partially_completed') {
        tempStreak++;
        if (tempStreak > longestStreak) longestStreak = tempStreak;
      } else if (status == 'rest_day' || status == 'holiday' || status == 'skipped') {
        // Rest days do not break the streak nor increment it
      } else if (status == 'missed') {
        tempStreak = 0;
        missedDaysCount++;
      }
    }

    currentStreak = tempStreak;

    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'missedDaysCount': missedDaysCount,
    };
  }

  // -------------------------------------------------------------
  // CONVENIENCE SHORTCUTS FOR AI & CONTROLLERS
  // -------------------------------------------------------------

  Future<List<GroupModel>> getGroups({bool includeArchived = false}) =>
      getAllGroups(includeArchived: includeArchived);

  Future<List<AlarmModel>> getAlarms() => getAllAlarms();

  Future<int> getCurrentStreak({String? groupId}) async {
    final s = await calculateStreaks(groupId: groupId);
    return s['currentStreak'] ?? 0;
  }

  Future<Map<String, dynamic>> getGroupStats(String groupId) async {
    final counts = await getGroupTopicCounts(groupId);
    final total = counts['total'] ?? 0;
    final completed = counts['completed'] ?? 0;
    final inProgress = counts['inProgress'] ?? 0;
    final pct = total > 0 ? (completed / total) * 100 : 0.0;
    return {
      'total_topics': total,
      'completed_topics': completed,
      'in_progress_topics': inProgress,
      'incomplete_topics': total - completed - inProgress,
      'completion_percentage': pct,
    };
  }

  Future<List<DailyProgressModel>> getDailyProgressByDate(String dateString) {
    return getDailyProgressRange(null, dateString, dateString);
  }

  // -------------------------------------------------------------
  // BACKUP & RESTORE ENGINE (JSON EXPORT/IMPORT)
  // -------------------------------------------------------------

  Future<String> exportBackupJson() async {
    final db = await database;
    final groups = await db.query('groups');
    final sections = await db.query('sections');
    final topics = await db.query('topics');
    final alarms = await db.query('alarms');
    final schedules = await db.query('schedules');
    final progress = await db.query('daily_progress');

    final backup = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'app_name': 'ProgressHub',
      'groups': groups,
      'sections': sections,
      'topics': topics,
      'alarms': alarms,
      'schedules': schedules,
      'daily_progress': progress,
    };

    return jsonEncode(backup);
  }

  Future<bool> restoreFromBackupJson(String jsonString) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    if (decoded['app_name'] != 'ProgressHub') {
      throw Exception('Invalid backup file. Missing ProgressHub signature.');
    }

    final db = await database;
    await db.transaction((txn) async {
      // Clear current data
      await txn.delete('daily_progress');
      await txn.delete('schedules');
      await txn.delete('alarms');
      await txn.delete('topics');
      await txn.delete('sections');
      await txn.delete('groups');

      final groups = (decoded['groups'] as List<dynamic>?) ?? [];
      for (final g in groups) {
        await txn.insert('groups', Map<String, dynamic>.from(g as Map));
      }

      final sections = (decoded['sections'] as List<dynamic>?) ?? [];
      for (final s in sections) {
        await txn.insert('sections', Map<String, dynamic>.from(s as Map));
      }

      final topics = (decoded['topics'] as List<dynamic>?) ?? [];
      for (final t in topics) {
        await txn.insert('topics', Map<String, dynamic>.from(t as Map));
      }

      final alarms = (decoded['alarms'] as List<dynamic>?) ?? [];
      for (final a in alarms) {
        await txn.insert('alarms', Map<String, dynamic>.from(a as Map));
      }

      final schedules = (decoded['schedules'] as List<dynamic>?) ?? [];
      for (final sch in schedules) {
        await txn.insert('schedules', Map<String, dynamic>.from(sch as Map));
      }

      final progress = (decoded['daily_progress'] as List<dynamic>?) ?? [];
      for (final p in progress) {
        await txn.insert('daily_progress', Map<String, dynamic>.from(p as Map));
      }
    });

    return true;
  }

  // -------------------------------------------------------------
  // USER PROFILE CRUD
  // -------------------------------------------------------------

  Future<UserProfileModel> getUserProfile() async {
    final db = await database;
    final res = await db.query('user_profile', limit: 1);
    if (res.isNotEmpty) {
      return UserProfileModel.fromMap(res.first);
    }

    final defaultProfile = UserProfileModel(
      id: 'default_user_profile',
      name: 'Harsh Patel',
      email: 'harsh@progresshub.app',
      bio: 'Dedicated learner pursuing software engineering and personal mastery.',
      targetHoursPerDay: 2.0,
      avatarColorHex: '#10B981',
      motivationQuote: 'Small daily improvements over time lead to stunning results.',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('user_profile', defaultProfile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return defaultProfile;
  }

  Future<void> saveUserProfile(UserProfileModel profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.copyWith(updatedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -------------------------------------------------------------
  // AI LONG-TERM MEMORY & CONTINUOUS SELF-LEARNING CRUD
  // -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAiMemories() async {
    final db = await database;
    try {
      return await db.query('ai_memory', orderBy: 'updated_at DESC');
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAiMemory({
    required String category,
    required String key,
    required String value,
    String? context,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    try {
      final existing = await db.query(
        'ai_memory',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final times = ((existing.first['times_referenced'] as num?)?.toInt() ?? 1) + 1;
        await db.update(
          'ai_memory',
          {
            'value': value,
            'category': category,
            'user_input_context': context ?? existing.first['user_input_context'],
            'times_referenced': times,
            'updated_at': now,
          },
          where: 'key = ?',
          whereArgs: [key],
        );
      } else {
        await db.insert('ai_memory', {
          'id': 'mem_${DateTime.now().millisecondsSinceEpoch}_${key.hashCode.abs()}',
          'category': category,
          'key': key,
          'value': value,
          'user_input_context': context ?? '',
          'confidence': 1.0,
          'times_referenced': 1,
          'created_at': now,
          'updated_at': now,
        });
      }
    } catch (e) {
      debugPrint('Error saving AI memory: $e');
    }
  }

  Future<void> deleteAiMemory(String key) async {
    final db = await database;
    try {
      await db.delete('ai_memory', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  Future<void> clearAiMemories() async {
    final db = await database;
    try {
      await db.delete('ai_memory');
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // AI MULTI-CONVERSATION CHAT HISTORY CRUD
  // -------------------------------------------------------------

  Future<String> createAiConversation({String? title, String? modelUsed}) async {
    final db = await database;
    final convId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert('ai_conversations', {
      'id': convId,
      'title': title ?? 'New Conversation',
      'created_at': now,
      'updated_at': now,
      'is_pinned': 0,
      'model_used': modelUsed ?? 'gemini-1.5-flash',
    });
    return convId;
  }

  Future<List<Map<String, dynamic>>> getAiConversations({String? query}) async {
    final db = await database;
    try {
      if (query != null && query.trim().isNotEmpty) {
        return await db.query(
          'ai_conversations',
          where: 'title LIKE ?',
          whereArgs: ['%${query.trim()}%'],
          orderBy: 'is_pinned DESC, updated_at DESC',
        );
      }
      return await db.query(
        'ai_conversations',
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> updateAiConversationTitle(String convId, String newTitle) async {
    final db = await database;
    await db.update(
      'ai_conversations',
      {'title': newTitle, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  Future<void> togglePinAiConversation(String convId, bool isPinned) async {
    final db = await database;
    await db.update(
      'ai_conversations',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  Future<void> deleteAiConversation(String convId) async {
    final db = await database;
    await db.delete('ai_messages', where: 'conversation_id = ?', whereArgs: [convId]);
    await db.delete('ai_conversations', where: 'id = ?', whereArgs: [convId]);
  }

  Future<void> saveAiMessageRecord(Map<String, dynamic> msg) async {
    final db = await database;
    await db.insert('ai_messages', msg, conflictAlgorithm: ConflictAlgorithm.replace);
    final convId = msg['conversation_id'] as String?;
    if (convId != null) {
      await db.update(
        'ai_conversations',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [convId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAiMessagesForConversation(String convId) async {
    final db = await database;
    try {
      return await db.query(
        'ai_messages',
        where: 'conversation_id = ?',
        whereArgs: [convId],
        orderBy: 'created_at ASC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> updateAiMessageRating(String msgId, int rating) async {
    final db = await database;
    await db.update('ai_messages', {'thumbs_rating': rating}, where: 'id = ?', whereArgs: [msgId]);
  }

  Future<void> deleteAiMessage(String msgId) async {
    final db = await database;
    await db.delete('ai_messages', where: 'id = ?', whereArgs: [msgId]);
  }
}
