import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_log_model.dart';
import '../core/database/database_service.dart';

final notificationsCenterProvider = StateNotifierProvider<NotificationsCenterNotifier, AsyncValue<List<NotificationLogModel>>>((ref) {
  return NotificationsCenterNotifier();
});

class NotificationsCenterNotifier extends StateNotifier<AsyncValue<List<NotificationLogModel>>> {
  NotificationsCenterNotifier() : super(const AsyncValue.loading()) {
    loadLogs();
  }

  final _db = DatabaseService.instance;

  Future<void> loadLogs() async {
    try {
      state = const AsyncValue.loading();
      final logs = await _db.getNotificationLogs();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    await _db.markNotificationAsRead(id);
    await loadLogs();
  }

  Future<void> clearAll() async {
    await _db.clearAllNotificationLogs();
    await loadLogs();
  }
}
