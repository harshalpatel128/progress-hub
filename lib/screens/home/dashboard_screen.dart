import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../providers/groups_provider.dart';
import '../../providers/alarms_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../core/utils/icon_utils.dart';
import '../groups/group_detail_screen.dart';
import '../groups/create_edit_group_dialog.dart';

final dashboardSelectedGroupFilter = StateProvider<String?>((ref) => null);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(dashboardSelectedGroupFilter);
    final statsAsync = ref.watch(overallStatsProvider(selectedGroupId));
    final alarmsAsync = ref.watch(alarmsProvider);

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(groupsProvider.notifier).loadGroups();
        ref.invalidate(overallStatsProvider);
        ref.read(alarmsProvider.notifier).loadAlarms();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Greeting & Quick Action Banner
          _buildHeroBanner(context, ref),
          const SizedBox(height: 16),

          // Group Filter Dropdown
          groupsAsync.when(
            data: (groups) => _buildGroupFilterBar(context, ref, groups, selectedGroupId),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Main Stats Grid
          statsAsync.when(
            data: (stats) => _buildStatsOverview(context, stats),
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )),
            error: (err, _) => Text('Error loading stats: $err'),
          ),
          const SizedBox(height: 20),

          // Today's Target & Daily Progress Card
          _buildTodayTargetCard(context, ref),
          const SizedBox(height: 20),

          // Upcoming Alarms Card
          alarmsAsync.when(
            data: (alarms) => _buildAlarmsSection(context, alarms),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Active Goals / Groups Quick List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Active Roadmaps', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Group'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const CreateEditGroupDialog(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return _buildEmptyGroupsState(context);
              }
              return Column(
                children: groups.map((g) => _buildGroupCard(context, g)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = ref.watch(userProfileProvider).value;
    final displayName = profile?.name.trim().isNotEmpty == true ? profile!.name.trim() : 'ProgressHub';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF10B981), const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome, $displayName',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Run Daily Target Check Now',
                icon: const Icon(Icons.fact_check_rounded),
                onPressed: () async {
                  await ref.read(progressActionProvider).runDailyCheck();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily progress evaluated for all active groups!')),
                    );
                  }
                },
              )
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Master skills step-by-step. All data stored securely & offline.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilterBar(
    BuildContext context,
    WidgetRef ref,
    List<GroupModel> groups,
    String? selectedGroupId,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Goals'),
            selected: selectedGroupId == null,
            onSelected: (_) => ref.read(dashboardSelectedGroupFilter.notifier).state = null,
          ),
          const SizedBox(width: 8),
          ...groups.map((g) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                avatar: Icon(IconUtils.getIcon(g.iconName), size: 16),
                label: Text(g.name),
                selected: selectedGroupId == g.id,
                onSelected: (_) => ref.read(dashboardSelectedGroupFilter.notifier).state = g.id,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context, Map<String, dynamic> stats) {
    final totalTopics = stats['totalTopics'] ?? 0;
    final completed = stats['completedTopics'] ?? 0;
    final inProgress = stats['inProgressTopics'] ?? 0;
    final incomplete = stats['incompleteTopics'] ?? 0;
    final percentage = ((stats['overallPercentage'] ?? 0.0) * 100).toStringAsFixed(1);
    final currentStreak = stats['currentStreak'] ?? 0;
    final longestStreak = stats['longestStreak'] ?? 0;
    final missedDays = stats['missedDaysCount'] ?? 0;

    return Column(
      children: [
        // Progress Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Curriculum Mastery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$percentage%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (stats['overallPercentage'] as double?) ?? 0.0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat('Total', '$totalTopics', Colors.blue),
                    _buildMiniStat('Completed', '$completed', Colors.green),
                    _buildMiniStat('In Progress', '$inProgress', Colors.amber),
                    _buildMiniStat('Incomplete', '$incomplete', Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Streaks & Consistency Row
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
                value: '$currentStreak d',
                label: 'Streak',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStreakCard(
                icon: Icons.emoji_events_rounded,
                color: Colors.purple,
                value: '$longestStreak d',
                label: 'Best',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStreakCard(
                icon: Icons.cancel_outlined,
                color: Colors.red,
                value: '$missedDays d',
                label: 'Missed',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStreakCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTargetCard(BuildContext context, WidgetRef ref) {
    return Card(
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
                    Icon(Icons.today_rounded, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Text("Today's Schedule & Target", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Active', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Complete at least 1 topic or 60 minutes of focused session today to maintain your learning streak.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmsSection(BuildContext context, List alarms) {
    if (alarms.isEmpty) return const SizedBox.shrink();
    final activeAlarms = alarms.where((a) => a.isEnabled).toList();

    return Card(
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
                    const Icon(Icons.alarm_on_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Active Alarms (${activeAlarms.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const Text('Exact Scheduled', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ...activeAlarms.take(2).map((a) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.alarm, color: Colors.orange, size: 18),
                ),
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${a.timeFormatted} • ${a.repeatDaysSummary}'),
                trailing: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupModel group) {
    final color = IconUtils.parseColor(group.colorHex);
    final icon = IconUtils.getIcon(group.iconName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.category} • ${group.durationText}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${group.completedTopics} of ${group.totalTopics} Topics Completed',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${(group.progressPercentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: group.progressPercentage,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.15),
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGroupsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No roadmaps found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Create your first roadmap or import the Python curriculum.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                showDialog(context: context, builder: (_) => const CreateEditGroupDialog());
              },
              child: const Text('Create New Group'),
            ),
          ],
        ),
      ),
    );
  }
}
