import 'package:intl/intl.dart';
import '../../models/daily_progress_model.dart';
import '../../models/group_model.dart';
import '../database/database_service.dart';
import '../notifications/notification_service.dart';

class DailyProgressEngine {
  static final DailyProgressEngine instance = DailyProgressEngine._internal();
  DailyProgressEngine._internal();

  final _db = DatabaseService.instance;
  final _notifications = NotificationService.instance;

  /// Inspects and updates daily progress for a specific group on a specific date (defaults to today)
  Future<DailyProgressModel> evaluateGroupDailyProgress({
    required GroupModel group,
    DateTime? date,
    bool notify = true,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateString = DateFormat('yyyy-MM-dd').format(targetDate);
    final dayOfWeek = targetDate.weekday; // 1 = Mon ... 7 = Sun

    // Check if user has an explicit record for this date (e.g. marked as rest day, holiday, or skipped)
    final existingProgress = await _db.getDailyProgress(group.id, dateString);
    if (existingProgress != null &&
        (existingProgress.status == DailyProgressStatus.restDay ||
         existingProgress.status == DailyProgressStatus.holiday ||
         existingProgress.status == DailyProgressStatus.skipped)) {
      return existingProgress; // Never override manually excused / rest days
    }

    // Check if today is a scheduled rest day in group schedules
    final schedules = await _db.getSchedulesForGroup(group.id);
    final todaySchedule = schedules.where((s) => s.dayOfWeek == dayOfWeek).firstOrNull;
    if (todaySchedule != null && todaySchedule.isRestDay) {
      final restDayModel = DailyProgressModel(
        id: '${group.id}_$dateString',
        groupId: group.id,
        dateString: dateString,
        targetMinutes: 0,
        completedMinutes: 0,
        topicsCompletedCount: 0,
        status: DailyProgressStatus.restDay,
        notes: 'Scheduled rest day',
        updatedAt: DateTime.now(),
      );
      await _db.setDailyProgress(restDayModel);
      return restDayModel;
    }

    // Query topics completed on this date
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dbInstance = await _db.database;
    final completedRows = await dbInstance.rawQuery('''
      SELECT COUNT(*) as count, SUM(actual_minutes) as actual_mins
      FROM topics
      WHERE group_id = ? 
        AND status = 'completed'
        AND completed_date >= ? AND completed_date < ?
    ''', [
      group.id,
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
    ]);

    final topicsCompleted = (completedRows.first['count'] as int?) ?? 0;
    final actualMinutes = (completedRows.first['actual_mins'] as int?) ?? (topicsCompleted * 30);
    final targetMinutes = group.dailyTargetMinutes > 0 ? group.dailyTargetMinutes : 60;

    DailyProgressStatus status;
    String notificationTitle = '';
    String notificationBody = '';

    if (topicsCompleted >= 1 || actualMinutes >= targetMinutes) {
      status = DailyProgressStatus.completed;
      notificationTitle = '🎉 Daily Goal Completed!';
      notificationBody = 'Your daily target for "${group.name}" is completed. Outstanding work!';
    } else if (actualMinutes > 0 || (existingProgress != null && existingProgress.completedMinutes > 0)) {
      status = DailyProgressStatus.partiallyCompleted;
      notificationTitle = '⏳ Target Partially Completed';
      notificationBody = 'You made progress on "${group.name}", but the full target is incomplete.';
    } else {
      status = DailyProgressStatus.missed;
      notificationTitle = '⚠️ Session Missed';
      notificationBody = 'Your target for "${group.name}" was missed today. Plan a catch-up session!';
    }

    final evaluatedProgress = DailyProgressModel(
      id: '${group.id}_$dateString',
      groupId: group.id,
      dateString: dateString,
      targetMinutes: targetMinutes,
      completedMinutes: actualMinutes,
      topicsCompletedCount: topicsCompleted,
      status: status,
      notes: existingProgress?.notes ?? '',
      updatedAt: DateTime.now(),
    );

    await _db.setDailyProgress(evaluatedProgress);

    if (notify && (status == DailyProgressStatus.missed || status == DailyProgressStatus.partiallyCompleted || status == DailyProgressStatus.completed)) {
      await _notifications.showNotification(
        id: group.id.hashCode + dateString.hashCode,
        title: notificationTitle,
        body: notificationBody,
        category: status == DailyProgressStatus.completed ? 'daily_summary' : 'missed_session',
        groupId: group.id,
      );
    }

    return evaluatedProgress;
  }

  /// Run daily progress check across all active groups
  Future<void> runEndOfDayCheckAllGroups() async {
    final groups = await _db.getAllGroups();
    for (final group in groups) {
      await evaluateGroupDailyProgress(group: group, notify: true);
    }
  }

  /// Mark a specific day as rest day or holiday for a group
  Future<void> markDayStatus({
    required String groupId,
    required DateTime date,
    required DailyProgressStatus status,
    String notes = '',
  }) async {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final model = DailyProgressModel(
      id: '${groupId}_$dateString',
      groupId: groupId,
      dateString: dateString,
      targetMinutes: 0,
      completedMinutes: 0,
      topicsCompletedCount: 0,
      status: status,
      notes: notes,
      updatedAt: DateTime.now(),
    );
    await _db.setDailyProgress(model);
  }
}
