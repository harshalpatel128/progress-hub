import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/group_model.dart';
import '../../providers/groups_provider.dart';
import '../../core/utils/icon_utils.dart';

class CreateEditGroupDialog extends ConsumerStatefulWidget {
  final GroupModel? existingGroup;

  const CreateEditGroupDialog({super.key, this.existingGroup});

  @override
  ConsumerState<CreateEditGroupDialog> createState() => _CreateEditGroupDialogState();
}

class _CreateEditGroupDialogState extends ConsumerState<CreateEditGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _durationController;
  late TextEditingController _targetMinutesController;
  late TextEditingController _categoryController;

  late String _selectedIcon;
  late String _selectedColor;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGroup;
    _nameController = TextEditingController(text: g?.name ?? '');
    _descController = TextEditingController(text: g?.description ?? '');
    _durationController = TextEditingController(text: g?.durationText ?? '6 Months');
    _targetMinutesController = TextEditingController(text: (g?.dailyTargetMinutes ?? 60).toString());
    _categoryController = TextEditingController(text: g?.category ?? 'General');

    _selectedIcon = g?.iconName ?? 'code';
    _selectedColor = g?.colorHex ?? '#10B981';
    _startDate = g?.startDate ?? DateTime.now();
    _endDate = g?.endDate ?? DateTime.now().add(const Duration(days: 180));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _targetMinutesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingGroup != null;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(isEditing ? 'Edit Goal Group' : 'Create New Group'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group / Goal Name *',
                    hintText: 'e.g. Gym & Fitness, English Speaking',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a group name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Fitness, Language, Career',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Target goals, milestones, or rules',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(labelText: 'Duration Text', hintText: 'e.g. 1 Year'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _targetMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Daily Goal (Mins)', hintText: '60'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IconUtils.groupIcons.entries.map((entry) {
                    final isSelected = _selectedIcon == entry.key;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedIcon = entry.key),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(entry.value, size: 22, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Choose Theme Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: IconUtils.availableColors.map((hex) {
                    final color = IconUtils.parseColor(hex);
                    final isSelected = _selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)]
                              : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final now = DateTime.now();
              final targetMins = int.tryParse(_targetMinutesController.text.trim()) ?? 60;

              if (isEditing) {
                final updated = widget.existingGroup!.copyWith(
                  name: _nameController.text.trim(),
                  description: _descController.text.trim(),
                  category: _categoryController.text.trim(),
                  durationText: _durationController.text.trim(),
                  dailyTargetMinutes: targetMins,
                  iconName: _selectedIcon,
                  colorHex: _selectedColor,
                  updatedAt: now,
                );
                await ref.read(groupsProvider.notifier).updateGroup(updated);
              } else {
                final newGroup = GroupModel(
                  id: const Uuid().v4(),
                  name: _nameController.text.trim(),
                  description: _descController.text.trim(),
                  category: _categoryController.text.trim(),
                  durationText: _durationController.text.trim(),
                  dailyTargetMinutes: targetMins,
                  iconName: _selectedIcon,
                  colorHex: _selectedColor,
                  startDate: _startDate,
                  endDate: _endDate,
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(groupsProvider.notifier).addGroup(newGroup);
              }

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Text(isEditing ? 'Save Changes' : 'Create Group'),
        ),
      ],
    );
  }
}
