import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_progress_model.dart';
import '../core/database/database_service.dart';
import '../core/scheduler/daily_progress_engine.dart';
import 'groups_provider.dart';

final selectedCalendarDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dailyProgressRangeProvider = FutureProvider.family<List<DailyProgressModel>, ({String? groupId, String start, String end})>((ref, arg) async {
  return DatabaseService.instance.getDailyProgressRange(arg.groupId, arg.start, arg.end);
});

final progressActionProvider = Provider((ref) => ProgressActionController(ref));

class ProgressActionController {
  final Ref ref;
  ProgressActionController(this.ref);

  final _engine = DailyProgressEngine.instance;

  Future<void> runDailyCheck() async {
    await _engine.runEndOfDayCheckAllGroups();
    ref.read(groupsProvider.notifier).loadGroups();
  }

  Future<void> markRestDay(String groupId, DateTime date) async {
    await _engine.markDayStatus(
      groupId: groupId,
      date: date,
      status: DailyProgressStatus.restDay,
      notes: 'User scheduled rest day',
    );
  }

  Future<void> markHoliday(String groupId, DateTime date) async {
    await _engine.markDayStatus(
      groupId: groupId,
      date: date,
      status: DailyProgressStatus.holiday,
      notes: 'Holiday / Break',
    );
  }
}
