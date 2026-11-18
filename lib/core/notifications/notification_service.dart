import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/alarm_model.dart';
import '../../models/notification_log_model.dart';
import '../database/database_service.dart';
import 'alarm_audio_service.dart';
import 'native_alarm_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelIdAlarms = 'progresshub_alarms_channel';
  static const String channelNameAlarms = 'ProgressHub Alarms';
  static const String channelDescAlarms = 'High priority wake-up and study alarms with sound & vibration';

  static const String channelIdReminders = 'progresshub_reminders_channel';
  static const String channelNameReminders = 'ProgressHub Reminders';
  static const String channelDescReminders = 'Reminders for upcoming topics, sessions and deadlines';

  static const String channelIdProgress = 'progresshub_progress_channel';
  static const String channelNameProgress = 'ProgressHub Daily Progress';
  static const String channelDescProgress = 'Daily target completion warnings and streak notifications';

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    // Configure local timezone matching the device's actual offset
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      tz.Location? matchedLoc;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offsetMs) {
          matchedLoc = location;
          break;
        }
      }
      if (matchedLoc != null) {
        tz.setLocalLocation(matchedLoc);
      } else {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open ProgressHub');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      await _createNotificationChannels();
      await requestPermissions();
    }

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final alarmChannel = AndroidNotificationChannel(
      channelIdAlarms,
      channelNameAlarms,
      description: channelDescAlarms,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    );

    final reminderChannel = const AndroidNotificationChannel(
      channelIdReminders,
      channelNameReminders,
      description: channelDescReminders,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final progressChannel = const AndroidNotificationChannel(
      channelIdProgress,
      channelNameProgress,
      description: channelDescProgress,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(alarmChannel);
    await androidPlugin.createNotificationChannel(reminderChannel);
    await androidPlugin.createNotificationChannel(progressChannel);
  }

  void _onNotificationTapped(NotificationResponse response) async {
    debugPrint('Notification clicked with payload: ${response.payload}, actionId: ${response.actionId}');
    if (response.actionId != null && response.actionId!.startsWith('dismiss_')) {
      final idStr = response.actionId!.replaceFirst('dismiss_', '');
      final id = int.tryParse(idStr) ?? 0;
      await stopAlarm(id);
    } else if (response.actionId != null && response.actionId!.startsWith('snooze_')) {
      await NativeAlarmService.instance.stopAlarm();
      await AlarmAudioService.instance.stopRinging();
    } else if (response.payload != null && response.payload!.startsWith('alarm_')) {
      final idStr = response.payload!.replaceFirst('alarm_', '');
      final id = int.tryParse(idStr) ?? 0;
      await stopAlarm(id);
    }
  }

  // -------------------------------------------------------------
  // ALARM SCHEDULING
  // -------------------------------------------------------------

  Future<void> scheduleAlarm(AlarmModel alarm) async {
    if (!_isInitialized) await initialize();
    if (!alarm.isEnabled) {
      await cancelAlarm(alarm.id);
      return;
    }

    // Cancel any existing schedule for this alarm id first (prevent duplicates)
    await cancelAlarm(alarm.id);

    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );

    if (alarm.repeatDays.isNotEmpty) {
      // Find the next upcoming repeat day (1 = Monday, 7 = Sunday)
      while (!alarm.repeatDays.contains(scheduledDate.weekday) || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    } else {
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }

    // 1. Primary: Schedule natively via Android AlarmManager.setAlarmClock
    // Wakes up device in doze mode, shows clock icon, rings out loud even when phone is locked
    await NativeAlarmService.instance.scheduleAlarm(alarm, scheduledDate);

    // 2. Secondary: System notification channel
    final androidDetails = AndroidNotificationDetails(
      channelIdAlarms,
      channelNameAlarms,
      channelDescription: channelDescAlarms,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      enableVibration: alarm.vibrationEnabled,
      vibrationPattern: alarm.vibrationEnabled
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 2000])
          : null,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss_${alarm.id}',
          'Dismiss Alarm',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze_${alarm.id}',
          'Snooze (${alarm.snoozeDurationMinutes}m)',
          showsUserInterface: false,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      // Use Android alarmClock mode: highest OS priority, wakes device from doze
      await _plugin.zonedSchedule(
        alarm.id,
        '⏰ ${alarm.title}',
        alarm.groupName != null ? 'Goal: ${alarm.groupName}' : 'Time for your scheduled learning session!',
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: alarm.repeatDays.isNotEmpty
            ? DateTimeComponents.time
            : null,
        payload: 'alarm_${alarm.id}',
      );
      debugPrint('Alarm scheduled with alarmClock mode at: $tzDateTime');
    } catch (e) {
      debugPrint('alarmClock failed, trying exactAllowWhileIdle: $e');
      try {
        await _plugin.zonedSchedule(
          alarm.id,
          '⏰ ${alarm.title}',
          alarm.groupName != null ? 'Goal: ${alarm.groupName}' : 'Time for your scheduled learning session!',
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: alarm.repeatDays.isNotEmpty
              ? DateTimeComponents.time
              : null,
          payload: 'alarm_${alarm.id}',
        );
      } catch (e2) {
        debugPrint('Fallback due to error: $e2');
      }
    }
  }

  Future<void> triggerAlarmNow(AlarmModel alarm) async {
    if (!_isInitialized) await initialize();

    // 1. Trigger native AlarmForegroundService with full alarm volume and wakeLock
    await NativeAlarmService.instance.triggerAlarmNow(alarm);

    // 2. Also start Flutter audio player service for in-app management
    await AlarmAudioService.instance.startRinging(alarm);

    final androidDetails = AndroidNotificationDetails(
      channelIdAlarms,
      channelNameAlarms,
      channelDescription: channelDescAlarms,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      enableVibration: alarm.vibrationEnabled,
      vibrationPattern: alarm.vibrationEnabled
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 2000])
          : null,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'dismiss_${alarm.id}',
          'Dismiss Alarm',
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      alarm.id,
      '⏰ ${alarm.title}',
      alarm.groupName != null ? 'Goal: ${alarm.groupName}' : 'Time for your session!',
      details,
      payload: 'alarm_${alarm.id}',
    );
  }

  Future<void> stopAlarm(int alarmId) async {
    await NativeAlarmService.instance.stopAlarm();
    await AlarmAudioService.instance.stopRinging();
    await _plugin.cancel(alarmId);
  }

  Future<void> cancelAlarm(int alarmId) async {
    await NativeAlarmService.instance.cancelAlarm(alarmId);
    await NativeAlarmService.instance.stopAlarm();
    await AlarmAudioService.instance.stopRinging();
    await _plugin.cancel(alarmId);
  }

  Future<void> rescheduleAllAlarms(List<AlarmModel> alarms) async {
    for (final alarm in alarms) {
      if (alarm.isEnabled) {
        await scheduleAlarm(alarm);
      }
    }
  }

  // -------------------------------------------------------------
  // INSTANT & SCHEDULED IN-APP / SYSTEM NOTIFICATIONS
  // -------------------------------------------------------------

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String category = 'scheduled_reminder',
    String? groupId,
    String? topicId,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelIdReminders,
      channelNameReminders,
      channelDescription: channelDescReminders,
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details, payload: '$category:$groupId');

    // Also persist in in-app notification center database!
    try {
      await DatabaseService.instance.insertNotificationLog(NotificationLogModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        category: category,
        groupId: groupId,
        topicId: topicId,
        timestamp: DateTime.now(),
      ));
    } catch (_) {}
  }

  Future<void> snoozeAlarm(AlarmModel alarm) async {
    final snoozeMinutes = alarm.snoozeDurationMinutes > 0 ? alarm.snoozeDurationMinutes : 10;
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));

    final androidDetails = AndroidNotificationDetails(
      channelIdAlarms,
      channelNameAlarms,
      channelDescription: channelDescAlarms,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    final tzSnooze = tz.TZDateTime.from(snoozeTime, tz.local);
    await _plugin.zonedSchedule(
      alarm.id + 100000,
      '⏰ [Snoozed] ${alarm.title}',
      'Snoozed alarm ringing now',
      tzSnooze,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
