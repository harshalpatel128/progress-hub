import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../core/database/database_service.dart';
import '../../core/backup/export_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/icon_utils.dart';
import '../profile/profile_screen.dart';
import '../ai/ai_assistant_screen.dart';
import '../../core/ai/ai_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // User Profile Quick Card
          _buildSectionHeader('User Profile'),
          _buildProfileCard(context, ref),
          const SizedBox(height: 16),

          // ProgressAI Assistant Settings
          _buildSectionHeader('ProgressAI Assistant (ChatGPT & Gemini)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  title: const Text('Open ProgressAI Assistant', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('ChatGPT-grade assistant, web search, doc & image generator'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_rounded, color: Color(0xFF10B981)),
                  title: const Text('Google Gemini API Key', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Direct high-speed Gemini 1.5 Flash access (1500 free req/day)'),
                  trailing: TextButton(
                    onPressed: () => _showApiKeyDialog(context),
                    child: const Text('Configure'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Theme Settings Card
          _buildSectionHeader('Appearance & Theme'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_medium_rounded, color: Color(0xFF10B981)),
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(settings.themeMode.name.toUpperCase()),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(settingsProvider.notifier).setThemeMode(mode);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Alarms & Notification Preferences
          _buildSectionHeader('Alarms & Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_rounded, color: Colors.blue),
                  title: const Text('Alarm & Reminder Sound'),
                  subtitle: const Text('Play sound during alarms & sessions'),
                  value: settings.enableSound,
                  onChanged: (val) => ref.read(settingsProvider.notifier).setSound(val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded, color: Colors.orange),
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate phone on study alarms'),
                  value: settings.enableVibration,
                  onChanged: (val) => ref.read(settingsProvider.notifier).setVibration(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.snooze_rounded, color: Colors.purple),
                  title: const Text('Snooze Duration'),
                  subtitle: Text('${settings.snoozeDurationMinutes} Minutes'),
                  trailing: DropdownButton<int>(
                    value: settings.snoozeDurationMinutes,
                    underline: const SizedBox.shrink(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(settingsProvider.notifier).setSnoozeDuration(val);
                      }
                    },
                    items: const [5, 10, 15, 20].map((m) => DropdownMenuItem(value: m, child: Text('$m mins'))).toList(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notification_important_rounded, color: Colors.red),
                  title: const Text('Request Permissions'),
                  subtitle: const Text('Enable exact alarms & background notifications'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: () async {
                      await NotificationService.instance.requestPermissions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification & Exact Alarm permissions requested')),
                        );
                      }
                    },
                    child: const Text('Grant'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Backup, Restore & Data Safety
          _buildSectionHeader('Backup & Data Safety (Offline-First)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF10B981)),
                  title: const Text('Export Local Backup (JSON)'),
                  subtitle: const Text('Save all groups, topics, schedules, alarms and progress'),
                  trailing: IconButton(
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () async {
                      try {
                        await ExportService.instance.shareBackupFile();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup error: $e')));
                        }
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download_rounded, color: Colors.blue),
                  title: const Text('Restore from Backup'),
                  subtitle: const Text('Import previously exported JSON file safely'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result != null && result.files.single.path != null) {
                          final file = File(result.files.single.path!);
                          final jsonContent = await file.readAsString();

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restore Backup?'),
                              content: const Text('This will safely replace current data with the contents of the backup file. Proceed?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await DatabaseService.instance.restoreFromBackupJson(jsonContent);
                            ref.read(groupsProvider.notifier).loadGroups();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Backup restored successfully!')),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore error: $e')));
                        }
                      }
                    },
                    child: const Text('Restore'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Curriculum Re-seed & Reset
          _buildSectionHeader('Curriculum Seed & Reset'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: Colors.amber),
                  title: const Text('Re-import Python & AI Roadmap'),
                  subtitle: const Text('Re-seed all 405 topics across 6 months'),
                  trailing: TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Re-import Curriculum?'),
                          content: const Text('This will reset and re-import all 405 topics for the "Python & AI Developer Roadmap" group. Proceed?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-import')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final count = await DatabaseService.instance.importPythonCurriculum(force: true);
                        ref.read(groupsProvider.notifier).loadGroups();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully imported all $count topics!')),
                          );
                        }
                      }
                    },
                    child: const Text('Re-import'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About ProgressHub
          _buildSectionHeader('About App'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                      SizedBox(width: 8),
                      Text('ProgressHub v1.0.0+1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Smart Life, Learning & Universal Goal Management Application. Built with offline-first SQLite, exact alarm scheduling, dynamic multi-group roadmaps, calendar progress tracking, and automated daily consistency checks.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Database Architecture', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'SQLite (Local & Offline)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Android Alarms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Exact Alarm & Boot Enabled',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        final avatarColor = IconUtils.parseColor(profile.avatarColorHex);
        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: avatarColor.withOpacity(0.2),
                  child: Text(
                    profile.name.isNotEmpty ? profile.name.trim()[0].toUpperCase() : 'P',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: avatarColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.targetHoursPerDay.toStringAsFixed(1)} hrs/day goal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: avatarColor),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: const Text('View Profile', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showApiKeyDialog(BuildContext context) async {
    final currentKey = await AiService.instance.getApiKey();
    if (!context.mounted) return;
    final keyCtrl = TextEditingController(text: currentKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Google Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ગૂગલના રિયલ Gemini 1.5 Flash AI સાથે સીધા જોડાવા માટે તમારી ફ્રી API Key નાખો:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await AiService.instance.saveApiKey(keyCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key સાચવવામાં આવી!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
