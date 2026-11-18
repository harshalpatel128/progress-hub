import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_service.dart';
import '../../models/section_model.dart';
import '../../models/topic_model.dart';
import '../../providers/topics_provider.dart';

class CreateEditTopicDialog extends ConsumerStatefulWidget {
  final String groupId;
  final List<SectionModel> sections;
  final TopicModel? existingTopic;

  const CreateEditTopicDialog({
    super.key,
    required this.groupId,
    required this.sections,
    this.existingTopic,
  });

  @override
  ConsumerState<CreateEditTopicDialog> createState() => _CreateEditTopicDialogState();
}

class _CreateEditTopicDialogState extends ConsumerState<CreateEditTopicDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _minsController;

  String? _selectedSectionId;
  String _priority = 'Normal';
  String _difficulty = 'Beginner';
  TopicStatus _status = TopicStatus.incomplete;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTopic;
    _titleController = TextEditingController(text: t?.title ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _minsController = TextEditingController(text: (t?.estimatedMinutes ?? 60).toString());

    _selectedSectionId = t?.sectionId ?? (widget.sections.isNotEmpty ? widget.sections.first.id : null);
    _priority = t?.priority ?? 'Normal';
    _difficulty = t?.difficulty ?? 'Beginner';
    _status = t?.status ?? TopicStatus.incomplete;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _minsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTopic != null;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(isEditing ? 'Edit Topic' : 'Add New Topic'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Topic Title *',
                    hintText: 'e.g. Asynchronous I/O with asyncio',
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 12),
                if (widget.sections.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedSectionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Section / Chapter *',
                      isDense: true,
                    ),
                    items: widget.sections.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} (Month ${s.monthNumber})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedSectionId = val),
                    validator: (val) => val == null ? 'Please select a section' : null,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          isDense: true,
                        ),
                        items: ['Normal', 'Medium', 'High'].map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setState(() => _priority = val ?? 'Normal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _difficulty,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          isDense: true,
                        ),
                        items: ['Beginner', 'Intermediate', 'Advanced'].map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setState(() => _difficulty = val ?? 'Beginner'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Est. Mins',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<TopicStatus>(
                        value: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                        ),
                        items: TopicStatus.values.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setState(() => _status = val ?? TopicStatus.incomplete),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Personal Notes & Takeaways',
                    hintText: 'Concepts to remember, key syntax or reminders',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final mins = int.tryParse(_minsController.text.trim()) ?? 60;
              final now = DateTime.now();

              if (isEditing) {
                final updated = widget.existingTopic!.copyWith(
                  title: _titleController.text.trim(),
                  sectionId: _selectedSectionId ?? widget.existingTopic!.sectionId,
                  priority: _priority,
                  difficulty: _difficulty,
                  estimatedMinutes: mins,
                  status: _status,
                  notes: _notesController.text.trim(),
                  updatedAt: now,
                );
                await ref.read(topicsActionControllerProvider).saveTopic(updated);
              } else {
                String secId = _selectedSectionId ?? '';
                if (secId.isEmpty) {
                  if (widget.sections.isNotEmpty) {
                    secId = widget.sections.first.id;
                  } else {
                    final defaultSec = SectionModel(
                      id: 'sec_${const Uuid().v4()}',
                      groupId: widget.groupId,
                      name: 'Section 1: General / Foundations',
                      monthNumber: 1,
                      orderIndex: 1,
                      createdAt: now,
                    );
                    await DatabaseService.instance.insertSection(defaultSec);
                    secId = defaultSec.id;
                  }
                }

                final newTopic = TopicModel(
                  id: const Uuid().v4(),
                  groupId: widget.groupId,
                  sectionId: secId,
                  orderIndex: 999,
                  title: _titleController.text.trim(),
                  priority: _priority,
                  difficulty: _difficulty,
                  estimatedMinutes: mins,
                  status: _status,
                  notes: _notesController.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(topicsActionControllerProvider).saveTopic(newTopic);
              }

              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Text(isEditing ? 'Save' : 'Add Topic'),
        ),
      ],
    );
  }
}
