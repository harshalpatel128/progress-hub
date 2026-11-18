import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile_model.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../core/utils/icon_utils.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final statsAsync = ref.watch(overallStatsProvider(null));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'App Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          final avatarColor = IconUtils.parseColor(profile.avatarColorHex);
          final stats = statsAsync.value ?? {};
          final totalCompleted = stats['completedTopics'] ?? 0;
          final totalTopics = stats['totalTopics'] ?? 0;
          final currentStreak = stats['currentStreak'] ?? 0;
          final studyMinutes = stats['totalStudyMinutes'] ?? 0;
          final studyHours = (studyMinutes / 60).toStringAsFixed(1);
          final groups = groupsAsync.value ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: avatarColor.withOpacity(0.2),
                              child: Text(
                                profile.name.isNotEmpty ? profile.name.trim()[0].toUpperCase() : 'P',
                                style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: avatarColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: avatarColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                              child: const Icon(Icons.verified, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: avatarColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Joined ${DateFormat('MMMM yyyy').format(profile.createdAt)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: avatarColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Profile'),
                          onPressed: () => _showEditProfileDialog(context, ref, profile),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bio & Daily Motivation Quote
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text('About & Bio', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.bio,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text('Daily Motivation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${profile.motivationQuote}"',
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lifetime Achievement Stats
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('MY LEARNING JOURNEY', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.0, color: Colors.grey)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        value: '$currentStreak d',
                        label: 'Active Streak',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.check_circle_rounded,
                        color: Colors.green,
                        value: '$totalCompleted / $totalTopics',
                        label: 'Topics Done',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.timer_rounded,
                        color: Colors.blue,
                        value: '$studyHours h',
                        label: 'Focus Time',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.folder_special_rounded,
                        color: Colors.purple,
                        value: '${groups.length}',
                        label: 'Roadmaps',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Daily Learning Commitment
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Daily Study Target', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            Text('${profile.targetHoursPerDay.toStringAsFixed(1)} Hours / day', style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (double.tryParse(studyHours) ?? 0.0) / (profile.targetHoursPerDay > 0 ? profile.targetHoursPerDay : 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.withOpacity(0.15),
                            color: avatarColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Target set to maintain steady progress across your active roadmaps.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Achievement Badges
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('EARNED BADGES & ACHIEVEMENTS', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.0, color: Colors.grey)),
                ),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildBadge(Icons.code_rounded, 'Python Pioneer', 'Enrolled in 405 Topics', Colors.blue),
                        _buildBadge(Icons.alarm_on_rounded, 'Discipline Master', 'Set Study Alarms', Colors.teal),
                        _buildBadge(Icons.calendar_month_rounded, 'Consistent Mind', 'Calendar Tracking', Colors.purple),
                        _buildBadge(Icons.rocket_launch_rounded, 'Goal Architect', 'Multi-Roadmap Explorer', Colors.orange),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String title, String subtitle, Color color) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserProfileModel profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final emailCtrl = TextEditingController(text: profile.email);
    final bioCtrl = TextEditingController(text: profile.bio);
    final quoteCtrl = TextEditingController(text: profile.motivationQuote);
    double targetHours = profile.targetHoursPerDay;
    String selectedColor = profile.avatarColorHex;

    final colorOptions = [
      '#10B981', // Emerald
      '#3B82F6', // Blue
      '#8B5CF6', // Purple
      '#F59E0B', // Amber
      '#EF4444', // Red
      '#06B6D4', // Cyan
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Edit Profile'),
          content: Container(
            width: MediaQuery.of(ctx).size.width * 0.88,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email Address *', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Bio / About Me', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quoteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Daily Motivation Quote', isDense: true),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Goal Target:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${targetHours.toStringAsFixed(1)} Hours', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                  Slider(
                    value: targetHours,
                    min: 0.5,
                    max: 8.0,
                    divisions: 15,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) => setDialogState(() => targetHours = val),
                  ),
                  const SizedBox(height: 10),
                  const Text('Avatar Color Accent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorOptions.map((hex) {
                      final c = IconUtils.parseColor(hex);
                      final isSelected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final updated = profile.copyWith(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    bio: bioCtrl.text.trim(),
                    motivationQuote: quoteCtrl.text.trim(),
                    targetHoursPerDay: targetHours,
                    avatarColorHex: selectedColor,
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(userProfileProvider.notifier).updateProfile(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
