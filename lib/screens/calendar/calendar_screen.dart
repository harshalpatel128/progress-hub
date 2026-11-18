import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/daily_progress_model.dart';
import '../../providers/groups_provider.dart';
import '../../providers/progress_provider.dart';
import '../../core/database/database_service.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Map<String, DailyProgressModel> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadMonthProgress(_focusedDay);
  }

  Future<void> _loadMonthProgress(DateTime month) async {
    final start = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month - 1, 1));
    final end = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month + 2, 0));

    final list = await DatabaseService.instance.getDailyProgressRange(null, start, end);
    if (mounted) {
      setState(() {
        _progressMap = {for (final item in list) item.dateString: item};
      });
    }
  }

  Color _getStatusColor(DateTime day) {
    final dateString = DateFormat('yyyy-MM-dd').format(day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(day.year, day.month, day.day);

    final progress = _progressMap[dateString];
    if (progress != null) {
      switch (progress.status) {
        case DailyProgressStatus.completed:
          return const Color(0xFF10B981); // Green
        case DailyProgressStatus.partiallyCompleted:
          return const Color(0xFFF59E0B); // Yellow
        case DailyProgressStatus.restDay:
        case DailyProgressStatus.holiday:
        case DailyProgressStatus.skipped:
          return Colors.grey; // Grey
        case DailyProgressStatus.missed:
          return const Color(0xFFEF4444); // Red
      }
    }

    if (current.isAfter(today)) {
      return const Color(0xFF3B82F6); // Blue: Upcoming
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final selectedProgress = _progressMap[selectedDateStr];
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Color indicator legend
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Completed', const Color(0xFF10B981)),
                  _buildLegendItem('Partial', const Color(0xFFF59E0B)),
                  _buildLegendItem('Missed', const Color(0xFFEF4444)),
                  _buildLegendItem('Rest Day', Colors.grey),
                  _buildLegendItem('Upcoming', const Color(0xFF3B82F6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Calendar Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: DateTime(2023, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _loadMonthProgress(focusedDay);
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Color(0x3310B981),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final color = _getStatusColor(date);
                    if (color == Colors.transparent) return null;
                    return Positioned(
                      bottom: 2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Day Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedProgress != null
                                  ? 'Status: ${selectedProgress.status.label}'
                                  : (_selectedDay.isAfter(DateTime.now()) ? 'Status: Upcoming Plan' : 'Status: No record logged'),
                              style: TextStyle(
                                color: _getStatusColor(_selectedDay) == Colors.transparent
                                    ? Colors.grey
                                    : _getStatusColor(_selectedDay),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Mark Day Status',
                        onSelected: (val) async {
                          final groups = groupsAsync.value ?? [];
                          if (groups.isEmpty) return;
                          final gId = groups.first.id;

                          if (val == 'rest') {
                            await ref.read(progressActionProvider).markRestDay(gId, _selectedDay);
                          } else if (val == 'holiday') {
                            await ref.read(progressActionProvider).markHoliday(gId, _selectedDay);
                          }
                          await _loadMonthProgress(_focusedDay);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'rest', child: Text('Mark as Rest Day')),
                          const PopupMenuItem(value: 'holiday', child: Text('Mark as Holiday')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 16),
                              SizedBox(width: 4),
                              Text('Set Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Metrics for the day
                  Row(
                    children: [
                      Expanded(
                        child: _buildDayMetric(
                          'Study Duration',
                          '${selectedProgress?.completedMinutes ?? 0} mins',
                          Icons.timer_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildDayMetric(
                          'Topics Completed',
                          '${selectedProgress?.topicsCompletedCount ?? 0} done',
                          Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),

                  if (selectedProgress != null && selectedProgress.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Notes: ${selectedProgress.notes}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDayMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
