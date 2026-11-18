import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alarm_model.dart';
import '../core/database/database_service.dart';
import '../core/notifications/notification_service.dart';

final alarmsProvider = StateNotifierProvider<AlarmsNotifier, AsyncValue<List<AlarmModel>>>((ref) {
  return AlarmsNotifier();
});

final groupAlarmsProvider = Provider.family<List<AlarmModel>, String>((ref, groupId) {
  final alarmsAsync = ref.watch(alarmsProvider);
  return alarmsAsync.value?.where((a) => a.groupId == groupId).toList() ?? [];
});

class AlarmsNotifier extends StateNotifier<AsyncValue<List<AlarmModel>>> {
  AlarmsNotifier() : super(const AsyncValue.loading()) {
    loadAlarms();
  }

  final _db = DatabaseService.instance;
  final _notifications = NotificationService.instance;

  Future<void> loadAlarms() async {
    try {
      state = const AsyncValue.loading();
      final alarms = await _db.getAllAlarms();
      state = AsyncValue.data(alarms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    await _db.insertAlarm(alarm);
    if (alarm.isEnabled) {
      await _notifications.scheduleAlarm(alarm);
    }
    await loadAlarms();
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    await _db.updateAlarm(alarm);
    if (alarm.isEnabled) {
      await _notifications.scheduleAlarm(alarm);
    } else {
      await _notifications.cancelAlarm(alarm.id);
    }
    await loadAlarms();
  }

  Future<void> toggleAlarm(AlarmModel alarm, bool isEnabled) async {
    final updated = alarm.copyWith(isEnabled: isEnabled);
    await updateAlarm(updated);
  }

  Future<void> deleteAlarm(int alarmId) async {
    await _notifications.cancelAlarm(alarmId);
    await _db.deleteAlarm(alarmId);
    await loadAlarms();
  }

  Future<void> snooze(AlarmModel alarm) async {
    await _notifications.snoozeAlarm(alarm);
  }

  Future<void> testAlarm(AlarmModel alarm) async {
    await _notifications.triggerAlarmNow(alarm);
  }

  Future<void> stopAlarm(int alarmId) async {
    await _notifications.stopAlarm(alarmId);
  }
}
