import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/group_model.dart';
import '../core/database/database_service.dart';

final groupsProvider = StateNotifierProvider<GroupsNotifier, AsyncValue<List<GroupModel>>>((ref) {
  return GroupsNotifier();
});

class GroupsNotifier extends StateNotifier<AsyncValue<List<GroupModel>>> {
  GroupsNotifier() : super(const AsyncValue.loading()) {
    loadGroups();
  }

  final _db = DatabaseService.instance;

  Future<void> loadGroups() async {
    try {
      state = const AsyncValue.loading();
      // Ensure seed import happens if first launch
      if (!await _db.isCurriculumImported()) {
        await _db.importPythonCurriculum();
      }
      final groups = await _db.getAllGroups();
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addGroup(GroupModel group) async {
    await _db.insertGroup(group);
    await loadGroups();
  }

  Future<void> updateGroup(GroupModel group) async {
    await _db.updateGroup(group);
    await loadGroups();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.deleteGroup(groupId);
    await loadGroups();
  }
}
