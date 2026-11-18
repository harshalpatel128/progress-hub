import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_service.dart';

final selectedAnalyticsGroupProvider = StateProvider<String?>((ref) => null);

final overallStatsProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, groupId) async {
  return DatabaseService.instance.getOverallStats(groupId: groupId);
});

final statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return DatabaseService.instance.getOverallStats(groupId: null);
});
