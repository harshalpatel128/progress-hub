import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/alarm_model.dart';
import '../../models/group_model.dart';
import '../../providers/alarms_provider.dart';
import '../../core/notifications/alarm_audio_service.dart';

class GroupAlarmSheet extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupAlarmSheet({super.key, required this.group});

  static Future<void> show(BuildContext context, GroupModel group) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupAlarmSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupAlarmSheet> createState() => _GroupAlarmSheetState();
}

class _GroupAlarmSheetState extends ConsumerState<GroupAlarmSheet> {
  bool _isCreatingNew = false;
  String _alarmType = 'study'; // 'study' or 'warning'
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  late TextEditingController _titleController;
  final List<int> _selectedDays = [1, 2, 3, 4, 5]; // Mon - Fri default
  bool _vibration = true;

  String? _customAudioPath;
  String? _customAudioName;
  bool _isPreviewing = false;
  int? _activeTestingAlarmId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: '${widget.group.name} Study Session',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    AlarmAudioService.instance.stopRinging();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _alarmType = type;
      if (type == 'study') {
        _selectedTime = const TimeOfDay(hour: 7, minute: 0);
        _titleController.text = '${widget.group.name} Study Session';
      } else {
        _selectedTime = const TimeOfDay(hour: 20, minute: 30); // 8:30 PM warning
        _titleController.text = '⚠️ ${widget.group.name} Target Incomplete Warning';
      }
    });
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final originalPath = result.files.single.path!;
        final originalName = result.files.single.name;

        // Copy audio file to app's persistent documents directory so Android native service can always access it
        final appDir = await getApplicationDocumentsDirectory();
        final alarmsDir = Directory('${appDir.path}/custom_alarms');
        if (!alarmsDir.existsSync()) {
          alarmsDir.createSync(recursive: true);
        }
        final sanitizedName = originalName.replaceAll(RegExp(r'[^\w\.-]'), '_');
        final permanentFile = File('${alarmsDir.path}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName');
        await File(originalPath).copy(permanentFile.path);

        setState(() {
          _customAudioPath = permanentFile.path;
          _customAudioName = originalName;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Song selected: $originalName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio: $e')),
        );
      }
    }
  }

  Future<void> _togglePreview() async {
    if (_isPreviewing) {
      await AlarmAudioService.instance.stopRinging();
      setState(() => _isPreviewing = false);
    } else {
      if (_customAudioPath != null) {
        setState(() => _isPreviewing = true);
        await AlarmAudioService.instance.previewAudio(_customAudioPath!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAlarms = ref.watch(groupAlarmsProvider(widget.group.id));

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
        left: 20,
        right: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.alarm_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarms & Warnings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.group.name,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  AlarmAudioService.instance.stopRinging();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),

          // Content
          Flexible(
            child: SingleChildScrollView(
              child: _isCreatingNew
                  ? _buildCreateForm(context)
                  : _buildAlarmsList(context, groupAlarms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmsList(BuildContext context, List<AlarmModel> alarms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alarms.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                Icon(Icons.alarm_off_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text(
                  'No alarms set for this roadmap yet.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set study alarms or daily incomplete warnings to ring out loud even if your phone is locked!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ] else ...[
          ...alarms.map((alarm) {
            final isWarning = alarm.title.toLowerCase().contains('warning') ||
                alarm.title.contains('⚠️');
            final isThisAlarmTesting = _activeTestingAlarmId == alarm.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isWarning
                                ? Colors.amber.withOpacity(0.15)
                                : Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isWarning ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                            color: isWarning ? Colors.amber : Colors.teal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    alarm.timeFormatted,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isWarning ? Colors.amber.withOpacity(0.2) : Colors.teal.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isWarning ? 'Target Warning' : 'Study Alarm',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isWarning ? Colors.amber[800] : Colors.teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alarm.title,
                                style: const TextStyle(fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alarm.repeatDaysSummary,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: alarm.isEnabled,
                          onChanged: (val) {
                            ref.read(alarmsProvider.notifier).toggleAlarm(alarm, val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () {
                            if (_activeTestingAlarmId == alarm.id) {
                              ref.read(alarmsProvider.notifier).stopAlarm(alarm.id);
                            }
                            ref.read(alarmsProvider.notifier).deleteAlarm(alarm.id);
                          },
                        ),
                      ],
                    ),
                    if (alarm.customAudioName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.music_note, size: 14, color: Colors.teal),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Song: ${alarm.customAudioName}',
                              style: const TextStyle(fontSize: 11, color: Colors.teal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 12),
                    // Test Ringing Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isThisAlarmTesting)
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
                              setState(() => _activeTestingAlarmId = null);
                            },
                          )
                        else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.volume_up_rounded, size: 16),
                            label: const Text('Test Ringing (Instant Sound)', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              setState(() => _activeTestingAlarmId = alarm.id);
                              await ref.read(alarmsProvider.notifier).testAlarm(alarm);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_alarm_rounded),
          label: const Text('Add Alarm / Daily Warning', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            setState(() {
              _isCreatingNew = true;
              _customAudioPath = null;
              _customAudioName = null;
              _onTypeChanged('study');
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCreateForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Alarm Type Picker
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Study Alarm'),
                avatar: const Icon(Icons.alarm, size: 16),
                selected: _alarmType == 'study',
                onSelected: (_) => _onTypeChanged('study'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Target Warning'),
                avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                selected: _alarmType == 'warning',
                onSelected: (_) => _onTypeChanged('warning'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Time Picker Card
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );
            if (t != null) {
              setState(() => _selectedTime = t);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const Text('Change Time', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Title text field
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: _alarmType == 'study' ? 'Alarm Label / Message' : 'Warning Message',
            hintText: _alarmType == 'study'
                ? 'Time to study!'
                : 'Target incomplete warning!',
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Custom Song / Music Picker from Phone
        Card(
          elevation: 0,
          color: Colors.grey.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 18, color: Colors.teal),
                    const SizedBox(width: 6),
                    const Text('Alarm Song / Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _customAudioName != null
                      ? 'Song: $_customAudioName'
                      : 'Default Alarm Ringtone (Louder Alarm Stream)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _customAudioName != null ? Colors.teal : Colors.grey,
                    fontWeight: _customAudioName != null ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(
                          _customAudioName != null ? 'Change Song' : 'Pick Song / Music',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: _pickAudioFile,
                      ),
                    ),
                    if (_customAudioPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _isPreviewing ? 'Stop Preview' : 'Preview Song',
                        icon: Icon(_isPreviewing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: Colors.teal),
                        onPressed: _togglePreview,
                      ),
                      IconButton(
                        tooltip: 'Reset to default sound',
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () {
                          AlarmAudioService.instance.stopRinging();
                          setState(() {
                            _customAudioPath = null;
                            _customAudioName = null;
                            _isPreviewing = false;
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
        const SizedBox(height: 14),

        // Repeat Days
        const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            _buildDayChip(1, 'Mon'),
            _buildDayChip(2, 'Tue'),
            _buildDayChip(3, 'Wed'),
            _buildDayChip(4, 'Thu'),
            _buildDayChip(5, 'Fri'),
            _buildDayChip(6, 'Sat'),
            _buildDayChip(7, 'Sun'),
          ],
        ),
        const SizedBox(height: 14),

        // Vibration Switch
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibration'),
          subtitle: const Text('Vibrate phone when alarm fires', style: TextStyle(fontSize: 11)),
          value: _vibration,
          onChanged: (val) => setState(() => _vibration = val),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  AlarmAudioService.instance.stopRinging();
                  setState(() => _isCreatingNew = false);
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveAlarm,
                child: const Text('Save Alarm'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayChip(int dayNumber, String label) {
    final isSelected = _selectedDays.contains(dayNumber);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedDays.add(dayNumber);
            _selectedDays.sort();
          } else {
            if (_selectedDays.length > 1) {
              _selectedDays.remove(dayNumber);
            }
          }
        });
      },
    );
  }

  Future<void> _saveAlarm() async {
    AlarmAudioService.instance.stopRinging();

    final newId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final alarm = AlarmModel(
      id: newId,
      title: _titleController.text.trim().isEmpty
          ? (_alarmType == 'study' ? '${widget.group.name} Study' : '⚠️ Target Incomplete')
          : _titleController.text.trim(),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      isEnabled: true,
      repeatDays: _selectedDays,
      groupId: widget.group.id,
      groupName: widget.group.name,
      customAudioPath: _customAudioPath,
      customAudioName: _customAudioName,
      vibrationEnabled: _vibration,
      createdAt: DateTime.now(),
    );

    await ref.read(alarmsProvider.notifier).addAlarm(alarm);
    if (mounted) {
      setState(() => _isCreatingNew = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_alarmType == 'study' ? 'Study alarm' : 'Target warning'} set for ${_selectedTime.format(context)} (${alarm.customAudioName ?? "Default Sound"})',
          ),
        ),
      );
    }
  }
}
