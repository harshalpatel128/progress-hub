import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/topic_model.dart';
import '../core/database/database_service.dart';
import 'groups_provider.dart';

final topicsFilterProvider = StateProvider.autoDispose<TopicStatus?>((ref) => null);
final topicsSectionFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final topicsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final groupTopicsProvider = FutureProvider.family<List<TopicModel>, String>((ref, groupId) async {
  final status = ref.watch(topicsFilterProvider);
  final sectionId = ref.watch(topicsSectionFilterProvider);
  final query = ref.watch(topicsSearchQueryProvider);

  return DatabaseService.instance.getTopicsForGroup(
    groupId,
    status: status,
    sectionId: sectionId,
    searchQuery: query,
  );
});

final topicDetailProvider = FutureProvider.family<TopicModel?, String>((ref, topicId) async {
  return DatabaseService.instance.getTopicById(topicId);
});

final topicsActionControllerProvider = Provider((ref) => TopicsActionController(ref));

class TopicsActionController {
  final Ref ref;
  TopicsActionController(this.ref);

  final _db = DatabaseService.instance;

  Future<void> updateTopicStatus(String topicId, String groupId, TopicStatus status) async {
    await _db.updateTopicStatus(topicId, status);
    ref.invalidate(groupTopicsProvider(groupId));
    ref.invalidate(topicDetailProvider(topicId));
    ref.read(groupsProvider.notifier).loadGroups();
  }

  Future<void> saveTopic(TopicModel topic) async {
    final existing = await _db.getTopicById(topic.id);
    if (existing == null) {
      await _db.insertTopic(topic);
    } else {
      await _db.updateTopic(topic);
    }
    ref.invalidate(groupTopicsProvider(topic.groupId));
    ref.invalidate(topicDetailProvider(topic.id));
    ref.read(groupsProvider.notifier).loadGroups();
  }

  Future<void> deleteTopic(String topicId, String groupId) async {
    await _db.deleteTopic(topicId);
    ref.invalidate(groupTopicsProvider(groupId));
    ref.read(groupsProvider.notifier).loadGroups();
  }

  Future<void> duplicateTopic(TopicModel original) async {
    final newId = 'top_${DateTime.now().millisecondsSinceEpoch}';
    final duplicated = original.copyWith(
      id: newId,
      title: '${original.title} (Copy)',
      status: TopicStatus.incomplete,
      orderIndex: original.orderIndex + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      completedDate: null,
    );
    await _db.insertTopic(duplicated);
    ref.invalidate(groupTopicsProvider(original.groupId));
    ref.read(groupsProvider.notifier).loadGroups();
  }
}
