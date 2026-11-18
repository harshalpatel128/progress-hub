import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/schedule_model.dart';
import '../core/database/database_service.dart';

final groupSchedulesProvider = FutureProvider.family<List<ScheduleModel>, String>((ref, groupId) async {
  return DatabaseService.instance.getSchedulesForGroup(groupId);
});

final scheduleActionProvider = Provider((ref) => ScheduleActionController(ref));

class ScheduleActionController {
  final Ref ref;
  ScheduleActionController(this.ref);

  final _db = DatabaseService.instance;

  Future<void> saveSchedule(ScheduleModel schedule) async {
    final existing = await _db.getSchedulesForGroup(schedule.groupId);
    final isPresent = existing.any((s) => s.id == schedule.id);
    if (isPresent) {
      await _db.updateSchedule(schedule);
    } else {
      await _db.insertSchedule(schedule);
    }
    ref.invalidate(groupSchedulesProvider(schedule.groupId));
  }
}
