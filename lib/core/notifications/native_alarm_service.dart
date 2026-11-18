import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/alarm_model.dart';

class NativeAlarmService {
  static final NativeAlarmService instance = NativeAlarmService._internal();
  NativeAlarmService._internal();

  static const MethodChannel _channel = MethodChannel('com.progresshub/native_alarm');

  /// Schedule alarm natively via Android AlarmManager.setAlarmClock
  /// Wakes up CPU from deep sleep, displays alarm icon, and rings out loud
  Future<void> scheduleAlarm(AlarmModel alarm, DateTime scheduledTime) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'id': alarm.id,
        'timestampMillis': scheduledTime.millisecondsSinceEpoch,
        'title': alarm.title,
        'groupName': alarm.groupName,
        'customAudioPath': alarm.customAudioPath,
      });
      debugPrint('NativeAlarmService: scheduled alarm ${alarm.id} at $scheduledTime');
    } catch (e) {
      debugPrint('NativeAlarmService scheduleAlarm error: $e');
    }
  }

  /// Cancel native AlarmManager schedule
  Future<void> cancelAlarm(int alarmId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelAlarm', {'id': alarmId});
      debugPrint('NativeAlarmService: cancelled alarm $alarmId');
    } catch (e) {
      debugPrint('NativeAlarmService cancelAlarm error: $e');
    }
  }

  /// Trigger foreground alarm ringing immediately (for instant testing or manual triggers)
  Future<void> triggerAlarmNow(AlarmModel alarm) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('triggerAlarmNow', {
        'id': alarm.id,
        'title': alarm.title,
        'groupName': alarm.groupName,
        'customAudioPath': alarm.customAudioPath,
      });
      debugPrint('NativeAlarmService: triggered alarm ${alarm.id} now');
    } catch (e) {
      debugPrint('NativeAlarmService triggerAlarmNow error: $e');
    }
  }

  /// Stop current foreground ringing alarm
  Future<void> stopAlarm() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopAlarm');
      debugPrint('NativeAlarmService: stopped ringing alarm');
    } catch (e) {
      debugPrint('NativeAlarmService stopAlarm error: $e');
    }
  }

  /// Check if an alarm is currently ringing
  Future<bool> isAlarmRinging() async {
    if (!Platform.isAndroid) return false;
    try {
      final ringing = await _channel.invokeMethod<bool>('isAlarmRinging');
      return ringing ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get active alarm id if ringing
  Future<int?> getActiveAlarmId() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('getActiveAlarmId');
    } catch (e) {
      return null;
    }
  }

  /// Get active alarm title if ringing
  Future<String?> getActiveAlarmTitle() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getActiveAlarmTitle');
    } catch (e) {
      return null;
    }
  }
}
