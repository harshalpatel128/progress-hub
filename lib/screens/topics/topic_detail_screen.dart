import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/topic_model.dart';
import '../../providers/topics_provider.dart';
import '../../core/database/database_service.dart';
import 'create_edit_topic_dialog.dart';
import '../ai/ai_assistant_screen.dart';

class TopicDetailScreen extends ConsumerStatefulWidget {
  final String topicId;

  const TopicDetailScreen({super.key, required this.topicId});

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  final _noteController = TextEditingController();
  final _newSubtaskController = TextEditingController();
  final _newResourceTitleController = TextEditingController();
  final _newResourceUrlController = TextEditingController();

  bool _isEditingNotes = false;

  @override
  void dispose() {
    _noteController.dispose();
    _newSubtaskController.dispose();
    _newResourceTitleController.dispose();
    _newResourceUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(topicDetailProvider(widget.topicId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Topic Overview'),
        actions: [
          topicAsync.when(
            data: (topic) {
              if (topic == null) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Duplicate Topic',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await ref.read(topicsActionControllerProvider).duplicateTopic(topic);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Topic duplicated successfully!')),
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Explain Topic with AI',
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiAssistantScreen(
                            initialPrompt: 'મને આ ટોપિક વિગતવાર સમજાવો: "${topic.title}". સાથે કોડ એક્ઝામ્પલ અને ઇન્ટરવ્યુ પ્રશ્નો પણ આપો.',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Edit Topic',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () async {
                      final sections = await DatabaseService.instance.getSectionsForGroup(topic.groupId);
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (_) => CreateEditTopicDialog(
                            groupId: topic.groupId,
                            sections: sections,
                            existingTopic: topic,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete Topic',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Topic?'),
                          content: Text('Are you sure you want to delete "${topic.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(topicsActionControllerProvider).deleteTopic(topic.id, topic.groupId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: topicAsync.when(
        data: (topic) {
          if (topic == null) {
            return const Center(child: Text('Topic not found or deleted.'));
          }
          return _buildContent(context, topic);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TopicModel topic) {
    if (!_isEditingNotes) {
      _noteController.text = topic.notes;
    }

    final completedSubtasks = topic.subtasks.where((s) => s.isCompleted).length;
    final subtaskProgress = topic.subtasks.isNotEmpty ? completedSubtasks / topic.subtasks.length : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${topic.orderIndex}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (topic.sectionName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              topic.sectionName!,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Instant Status Radio / Button Group
                const Text('Current Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusSelector(
                        context,
                        topic,
                        TopicStatus.incomplete,
                        'Incomplete',
                        Icons.radio_button_unchecked,
                        Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusSelector(
                        context,
                        topic,
                        TopicStatus.inProgress,
                        'In Progress',
                        Icons.timelapse_rounded,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusSelector(
                        context,
                        topic,
                        TopicStatus.completed,
                        'Completed',
                        Icons.check_circle_rounded,
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Metadata grid
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Properties & Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetaTile('Priority', topic.priority, Icons.flag_rounded, Colors.orange)),
                    Expanded(child: _buildMetaTile('Difficulty', topic.difficulty, Icons.speed_rounded, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetaTile('Est. Duration', '${topic.estimatedMinutes} mins', Icons.timer_outlined, Colors.purple)),
                    Expanded(child: _buildMetaTile('Completed On', topic.completedDate != null ? DateFormat('dd MMM yyyy').format(topic.completedDate!) : 'Not yet', Icons.event_available_rounded, Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Subtasks & Action Items Checklist
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_rounded, size: 20, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text('Subtasks & Checkpoints (${topic.subtasks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    Text(
                      '$completedSubtasks / ${topic.subtasks.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                if (topic.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subtaskProgress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                ...topic.subtasks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sub = entry.value;
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      sub.title,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                        color: sub.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    value: sub.isCompleted,
                    onChanged: (val) async {
                      final updatedList = List<SubTask>.from(topic.subtasks);
                      updatedList[idx] = SubTask(
                        id: sub.id,
                        title: sub.title,
                        isCompleted: val ?? false,
                      );
                      final updated = topic.copyWith(subtasks: updatedList);
                      await ref.read(topicsActionControllerProvider).saveTopic(updated);
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () async {
                        final updatedList = List<SubTask>.from(topic.subtasks)..removeAt(idx);
                        final updated = topic.copyWith(subtasks: updatedList);
                        await ref.read(topicsActionControllerProvider).saveTopic(updated);
                      },
                    ),
                  );
                }),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubtaskController,
                        decoration: const InputDecoration(
                          hintText: 'Add new subtask...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                      onPressed: () async {
                        final text = _newSubtaskController.text.trim();
                        if (text.isNotEmpty) {
                          final updatedList = List<SubTask>.from(topic.subtasks)
                            ..add(SubTask(id: const Uuid().v4(), title: text, isCompleted: false));
                          _newSubtaskController.clear();
                          final updated = topic.copyWith(subtasks: updatedList);
                          await ref.read(topicsActionControllerProvider).saveTopic(updated);
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Personal Notes & Takeaways
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text('Personal Study Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save Notes'),
                      onPressed: () async {
                        final updated = topic.copyWith(notes: _noteController.text.trim());
                        await ref.read(topicsActionControllerProvider).saveTopic(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notes saved successfully!')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Add your summary, syntax snippets, tips, or questions here...',
                  ),
                  onChanged: (_) => _isEditingNotes = true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resources & Links Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.link_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Documentation & External Resources', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 10),
                if (topic.resources.isEmpty)
                  const Text('No external links attached.', style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ...topic.resources.map((r) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.blue),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r.url, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatusSelector(
    BuildContext context,
    TopicModel topic,
    TopicStatus status,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = topic.status == status;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await ref.read(topicsActionControllerProvider).updateTopicStatus(
              topic.id,
              topic.groupId,
              status,
            );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaTile(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
