import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/notification_log_model.dart';
import '../../providers/notification_center_provider.dart';

final selectedNotificationCategoryFilter = StateProvider.autoDispose<String?>((ref) => null);

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsCenterProvider);
    final selectedCategory = ref.watch(selectedNotificationCategoryFilter);

    const categories = [
      'scheduled_reminder',
      'upcoming_task',
      'missed_session',
      'daily_target_incomplete',
      'topic_completion',
      'deadline_approaching',
      'overdue_topic',
      'streak_reminder',
      'group_progress',
      'daily_summary',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          IconButton(
            tooltip: 'Clear All Notifications',
            icon: const Icon(Icons.clear_all_rounded),
            onPressed: () async {
              await ref.read(notificationsCenterProvider.notifier).clearAll();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selectedCategory == null,
                  onSelected: (_) => ref.read(selectedNotificationCategoryFilter.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final label = cat.replaceAll('_', ' ').toUpperCase();
                  final isSelected = selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) => ref.read(selectedNotificationCategoryFilter.notifier).state = isSelected ? null : cat,
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notifications List
          Expanded(
            child: notificationsAsync.when(
              data: (logs) {
                final filtered = selectedCategory != null
                    ? logs.where((l) => l.category == selectedCategory).toList()
                    : logs;

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No notifications recorded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Daily target warnings, reminders, and streaks will show here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return _buildLogCard(context, ref, log);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, WidgetRef ref, NotificationLogModel log) {
    Color iconColor;
    IconData iconData;

    switch (log.category) {
      case 'missed_session':
      case 'daily_target_incomplete':
        iconColor = Colors.red;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'topic_completion':
      case 'daily_summary':
        iconColor = const Color(0xFF10B981);
        iconData = Icons.check_circle_rounded;
        break;
      case 'streak_reminder':
        iconColor = Colors.orange;
        iconData = Icons.local_fire_department_rounded;
        break;
      default:
        iconColor = Colors.blue;
        iconData = Icons.notifications_active_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(log.body, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM • hh:mm a').format(log.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: log.isRead
            ? null
            : IconButton(
                icon: const Icon(Icons.circle, size: 10, color: Color(0xFF10B981)),
                tooltip: 'Mark as read',
                onPressed: () {
                  ref.read(notificationsCenterProvider.notifier).markAsRead(log.id);
                },
              ),
      ),
    );
  }
}
