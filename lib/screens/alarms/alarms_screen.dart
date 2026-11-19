import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/alarm_model.dart';
import '../../providers/alarms_provider.dart';
import '../../providers/groups_provider.dart';
import '../../core/notifications/notification_service.dart';

final testingAlarmIdProvider = StateProvider<int?>((ref) => null);

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmsProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms & Reminders'),
        actions: [
          IconButton(
            tooltip: 'Request Android Alarm Permissions',
            icon: const Icon(Icons.security_update_good_rounded),
            onPressed: () async {
              await NotificationService.instance.requestPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Android exact alarm and notification permissions requested.')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Add Alarm',
            icon: const Icon(Icons.add_alarm_rounded),
            onPressed: () => _showAddEditAlarmDialog(context, ref, groupsAsync.value ?? []),
          ),
        ],
      ),
      body: alarmsAsync.when(
        data: (alarms) {
          if (alarms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.alarm_off_rounded, size: 54, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No active alarms set', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      'Schedule recurring study alarms with custom music, full alarm stream volume and vibration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_alarm_rounded),
                      label: const Text('Add First Alarm'),
                      onPressed: () => _showAddEditAlarmDialog(context, ref, groupsAsync.value ?? []),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return _buildAlarmTile(context, ref, alarm, groupsAsync.value ?? []);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading alarms: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('New Alarm'),
        onPressed: () => _showAddEditAlarmDialog(context, ref, groupsAsync.value ?? []),
      ),
    );
  }

  Widget _buildAlarmTile(BuildContext context, WidgetRef ref, AlarmModel alarm, List groups) {
    final testingAlarmId = ref.watch(testingAlarmIdProvider);
    final isTesting = testingAlarmId == alarm.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alarm.timeFormatted,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: alarm.isEnabled ? null : Colors.grey,
                  ),
                ),
                Switch(
                  value: alarm.isEnabled,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    ref.read(alarmsProvider.notifier).toggleAlarm(alarm, val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              alarm.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: alarm.isEnabled ? null : Colors.grey,
              ),
            ),
            if (alarm.groupName != null) ...[
              const SizedBox(height: 2),
              Text(
                'Linked Goal: ${alarm.groupName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
              ),
            ],
            if (alarm.customAudioName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.music_note, size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Song: ${alarm.customAudioName}',
                      style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(alarm.repeatDaysSummary, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Alarm',
                      onPressed: () => _showAddEditAlarmDialog(context, ref, groups, existingAlarm: alarm),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Delete Alarm',
                      onPressed: () async {
                        if (isTesting) {
                          await ref.read(alarmsProvider.notifier).stopAlarm(alarm.id);
                          ref.read(testingAlarmIdProvider.notifier).state = null;
                        }
                        await ref.read(alarmsProvider.notifier).deleteAlarm(alarm.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 10),
            // Instant Test Ringing Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isTesting)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Stop Ringing', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await ref.read(alarmsProvider.notifier).stopAlarm(alarm.id);
                      ref.read(testingAlarmIdProvider.notifier).state = null;
                    },
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.volume_up_rounded, size: 16),
                    label: const Text('Test Ringing (Instant Sound)', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      ref.read(testingAlarmIdProvider.notifier).state = alarm.id;
                      await ref.read(alarmsProvider.notifier).testAlarm(alarm);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditAlarmDialog(
    BuildContext context,
    WidgetRef ref,
    List groups, {
    AlarmModel? existingAlarm,
  }) {
    final titleController = TextEditingController(text: existingAlarm?.title ?? 'Python Study Session');
    TimeOfDay selectedTime = TimeOfDay(
      hour: existingAlarm?.hour ?? 7,
      minute: existingAlarm?.minute ?? 0,
    );
    List<int> selectedDays = List<int>.from(existingAlarm?.repeatDays ?? [1, 2, 3, 4, 5, 6, 7]);
    String? selectedGroupId = existingAlarm?.groupId ?? (groups.isNotEmpty ? groups.first.id : null);
    bool vibration = existingAlarm?.vibrationEnabled ?? true;
    int snoozeMins = existingAlarm?.snoozeDurationMinutes ?? 10;

    String? customAudioPath = existingAlarm?.customAudioPath;
    String? customAudioName = existingAlarm?.customAudioName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final timeStr = selectedTime.format(ctx);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(existingAlarm != null ? 'Edit Alarm' : 'Set New Alarm'),
            content: Container(
              width: MediaQuery.of(ctx).size.width * 0.88,
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Alarm Label *', isDense: true),
                    ),
                    const SizedBox(height: 14),

                    // Time Picker Button
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded, color: Color(0xFF10B981)),
                      title: const Text('Alarm Time', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(timeStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      trailing: TextButton(
                        child: const Text('Change'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom Audio / Music Picker Card
                    Card(
                      color: Colors.grey.withOpacity(0.08),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.music_note_rounded, size: 18, color: Colors.teal),
                                SizedBox(width: 6),
                                Text('Alarm Song / Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customAudioName != null
                                  ? 'Song: $customAudioName'
                                  : 'Default Loud Alarm Ringtone',
                              style: TextStyle(
                                fontSize: 12,
                                color: customAudioName != null ? Colors.teal : Colors.grey,
                                fontWeight: customAudioName != null ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                                    label: Text(
                                      customAudioName != null ? 'Change Song' : 'Pick Song / Music',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () async {
                                      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
                                      if (res != null && res.files.single.path != null) {
                                        final originalPath = res.files.single.path!;
                                        final originalName = res.files.single.name;

                                        final appDir = await getApplicationDocumentsDirectory();
                                        final alarmsDir = Directory('${appDir.path}/custom_alarms');
                                        if (!alarmsDir.existsSync()) {
                                          alarmsDir.createSync(recursive: true);
                                        }
                                        final sanitizedName = originalName.replaceAll(RegExp(r'[^\w\.-]'), '_');
                                        final permanentFile = File('${alarmsDir.path}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName');
                                        await File(originalPath).copy(permanentFile.path);

                                        setDialogState(() {
                                          customAudioPath = permanentFile.path;
                                          customAudioName = originalName;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                if (customAudioPath != null) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      setDialogState(() {
                                        customAudioPath = null;
                                        customAudioName = null;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Repeat Days selector
                    const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDayToggle('M', 1, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('T', 2, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('W', 3, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('T', 4, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('F', 5, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('S', 6, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                        _buildDayToggle('S', 7, selectedDays, (d) => setDialogState(() => _toggleDay(selectedDays, d))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Associated Group
                    if (groups.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: selectedGroupId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Link to Roadmap Goal', isDense: true),
                        selectedItemBuilder: (context) => [
                          const Text('General (No Goal)', overflow: TextOverflow.ellipsis),
                          ...groups.map((g) => Text(
                            g.name as String,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )),
                        ],
                        items: [
                          const DropdownMenuItem(value: null, child: Text('General (No Goal)')),
                          ...groups.map((g) => DropdownMenuItem(
                            value: g.id as String,
                            child: Text(g.name as String, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (val) => setDialogState(() => selectedGroupId = val),
                      ),
                    const SizedBox(height: 10),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibration'),
                      value: vibration,
                      onChanged: (val) => setDialogState(() => vibration = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    final newAlarm = AlarmModel(
                      id: existingAlarm?.id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
                      title: titleController.text.trim(),
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      repeatDays: selectedDays,
                      groupId: selectedGroupId,
                      customAudioPath: customAudioPath,
                      customAudioName: customAudioName,
                      vibrationEnabled: vibration,
                      snoozeDurationMinutes: snoozeMins,
                      createdAt: DateTime.now(),
                    );
                    if (existingAlarm != null) {
                      await ref.read(alarmsProvider.notifier).updateAlarm(newAlarm);
                    } else {
                      await ref.read(alarmsProvider.notifier).addAlarm(newAlarm);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: Text(existingAlarm != null ? 'Update Alarm' : 'Save Alarm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayToggle(String label, int dayNum, List<int> selectedDays, Function(int) onToggle) {
    final isSelected = selectedDays.contains(dayNum);
    return GestureDetector(
      onTap: () => onToggle(dayNum),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.grey.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _toggleDay(List<int> list, int day) {
    if (list.contains(day)) {
      list.remove(day);
    } else {
      list.add(day);
      list.sort();
    }
  }
}
