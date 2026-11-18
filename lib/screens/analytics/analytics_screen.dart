import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/groups_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../core/backup/export_service.dart';
import '../../core/utils/icon_utils.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(selectedAnalyticsGroupProvider);
    final statsAsync = ref.watch(overallStatsProvider(selectedGroupId));
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Filter by group selector
          groupsAsync.when(
            data: (groups) => Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: selectedGroupId,
                    isDense: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: 'Select Group / Roadmap',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Roadmaps Combined')),
                      ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                    ],
                    onChanged: (val) => ref.read(selectedAnalyticsGroupProvider.notifier).state = val,
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Export & Share Action Buttons Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Export PDF'),
                      onPressed: () async {
                        try {
                          final path = await ExportService.instance.generatePdfReport(groupId: selectedGroupId);
                          await Share.shareXFiles([XFile(path)], text: 'ProgressHub Performance Report');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.table_chart_rounded, size: 18),
                      label: const Text('Export CSV'),
                      onPressed: () async {
                        try {
                          final path = await ExportService.instance.exportTopicsToCsv(selectedGroupId);
                          await Share.shareXFiles([XFile(path)], text: 'ProgressHub CSV Export');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Overview Stats
          statsAsync.when(
            data: (stats) => _buildAnalyticsDashboard(context, stats),
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )),
            error: (err, _) => Text('Error loading analytics: $err'),
          ),
          const SizedBox(height: 16),

          // Group-wise Performance Chart
          groupsAsync.when(
            data: (groups) => _buildGroupBreakdown(context, groups),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDashboard(BuildContext context, Map<String, dynamic> stats) {
    final completed = (stats['completedTopics'] as int?) ?? 0;
    final inProgress = (stats['inProgressTopics'] as int?) ?? 0;
    final incomplete = (stats['incompleteTopics'] as int?) ?? 0;
    final total = (stats['totalTopics'] as int?) ?? 0;
    final studyMinutes = (stats['totalStudyMinutes'] as int?) ?? 0;
    final hours = (studyMinutes / 60).toStringAsFixed(1);

    // Projected completion days calculation
    final daysToComplete = completed > 0
        ? ((incomplete / (completed / 30)).clamp(1, 365)).toStringAsFixed(0)
        : 'Calculating...';

    return Column(
      children: [
        // Pie Chart Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Curriculum Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: total > 0
                      ? PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                value: completed.toDouble(),
                                color: const Color(0xFF10B981),
                                title: '$completed',
                                radius: 45,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              PieChartSectionData(
                                value: inProgress.toDouble(),
                                color: const Color(0xFFF59E0B),
                                title: '$inProgress',
                                radius: 45,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              PieChartSectionData(
                                value: incomplete.toDouble(),
                                color: Colors.grey.shade400,
                                title: '$incomplete',
                                radius: 45,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : const Center(child: Text('No topic data yet.')),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildChartIndicator(const Color(0xFF10B981), 'Completed ($completed)'),
                      _buildChartIndicator(const Color(0xFFF59E0B), 'In Progress ($inProgress)'),
                      _buildChartIndicator(Colors.grey.shade400, 'Incomplete ($incomplete)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Prediction & Hours Card
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.blue, size: 24),
                      const SizedBox(height: 8),
                      Text('$hours Hours', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Total Focus Time', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_graph_rounded, color: Colors.purple, size: 24),
                      const SizedBox(height: 8),
                      Text(daysToComplete == 'Calculating...' ? daysToComplete : '~ $daysToComplete Days', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Projected Completion', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartIndicator(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildGroupBreakdown(BuildContext context, List groups) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Roadmap Progress Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...groups.map((g) {
              final color = IconUtils.parseColor(g.colorHex);
              final pct = (g.progressPercentage * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            g.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: g.progressPercentage,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
