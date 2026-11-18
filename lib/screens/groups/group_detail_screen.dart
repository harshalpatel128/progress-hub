import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/alarm_model.dart';
import '../../models/group_model.dart';
import '../../models/section_model.dart';
import '../../models/topic_model.dart';
import '../../providers/groups_provider.dart';
import '../../providers/topics_provider.dart';
import '../../providers/alarms_provider.dart';
import '../../core/database/database_service.dart';
import '../../core/utils/icon_utils.dart';
import '../topics/topic_detail_screen.dart';
import '../topics/create_edit_topic_dialog.dart';
import 'group_alarm_sheet.dart';
import '../ai/ai_assistant_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _searchController = TextEditingController();
  List<SectionModel> _sections = [];
  int? _selectedMonth; // null = All Months
  final Set<String> _expandedSectionIds = {};
  bool _expandAll = false;

  // Authoritative curriculum month titles
  static const Map<int, String> pythonMonthSubtitles = {
    1: 'Complete Python (95 Topics)',
    2: 'Advanced Python + DSA (60 Topics)',
    3: 'DSA + SQL + Backend (70 Topics)',
    4: 'Backend + Django + FastAPI + Git (60 Topics)',
    5: 'AI + ML + GenAI + Docker + AWS (65 Topics)',
    6: 'Real Projects & Interview Prep (55 Topics)',
  };

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    final sections = await DatabaseService.instance.getSectionsForGroup(widget.groupId);
    if (mounted) {
      setState(() {
        _sections = sections;
        // Expand the first 2 sections by default for easy viewing
        if (_sections.isNotEmpty && _expandedSectionIds.isEmpty) {
          _expandedSectionIds.add(_sections.first.id);
          if (_sections.length > 1) {
            _expandedSectionIds.add(_sections[1].id);
          }
        }
      });
    }
  }

  void _toggleExpandAll(List<SectionModel> currentSections) {
    setState(() {
      if (_expandAll) {
        _expandedSectionIds.clear();
        _expandAll = false;
      } else {
        _expandedSectionIds.addAll(currentSections.map((s) => s.id));
        _expandAll = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final group = groupsAsync.value?.where((g) => g.id == widget.groupId).firstOrNull;

    final selectedStatus = ref.watch(topicsFilterProvider);
    final searchQuery = ref.watch(topicsSearchQueryProvider);
    final topicsAsync = ref.watch(groupTopicsProvider(widget.groupId));
    final groupAlarms = ref.watch(groupAlarmsProvider(widget.groupId));

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final color = IconUtils.parseColor(group.colorHex);

    // Collect available months from sections
    final distinctMonths = _sections.map((s) => s.monthNumber).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Ask AI about this Goal',
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiAssistantScreen(
                    initialPrompt: 'હું "${group.name}" ગોલ શીખી રહ્યો છું. આ રોડમેપમાં ઝડપથી આગળ વધવા માટે શું કરવું જોઈએ?',
                  ),
                ),
              );
            },
          ),
          // Alarm & Warning action button
          IconButton(
            tooltip: 'Roadmap Alarms & Warnings',
            icon: Stack(
              children: [
                const Icon(Icons.alarm_rounded),
                if (groupAlarms.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${groupAlarms.length}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => GroupAlarmSheet.show(context, group),
          ),
          IconButton(
            tooltip: 'Add Section / Chapter',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showAddSectionDialog(context),
          ),
          IconButton(
            tooltip: 'Add Topic',
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => CreateEditTopicDialog(
                  groupId: widget.groupId,
                  sections: _sections,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Header summary banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: color.withOpacity(0.08),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${group.completedTopics} of ${group.totalTopics} Topics Completed',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      '${(group.progressPercentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: group.progressPercentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // 2. Group Alarms & Daily Warning Banner
          _buildAlarmQuickBar(context, group, groupAlarms),

          // 3. Search and Status Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search topics or notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(topicsSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (val) => ref.read(topicsSearchQueryProvider.notifier).state = val,
            ),
          ),

          // 4. Month Division Selector Tabs (Requirements 1 & 2)
          if (distinctMonths.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All Months (${group.totalTopics})'),
                    selected: _selectedMonth == null,
                    onSelected: (_) => setState(() => _selectedMonth = null),
                  ),
                  const SizedBox(width: 8),
                  ...distinctMonths.map((m) {
                    final subtitle = pythonMonthSubtitles[m] ?? 'Month $m';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('Month $m: $subtitle'),
                        selected: _selectedMonth == m,
                        onSelected: (_) => setState(() => _selectedMonth = m),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // 5. Status Filter Chips + Expand All button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: selectedStatus == null,
                          onSelected: (_) => ref.read(topicsFilterProvider.notifier).state = null,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Incomplete'),
                          selected: selectedStatus == TopicStatus.incomplete,
                          onSelected: (_) => ref.read(topicsFilterProvider.notifier).state = TopicStatus.incomplete,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('In Progress'),
                          selected: selectedStatus == TopicStatus.inProgress,
                          onSelected: (_) => ref.read(topicsFilterProvider.notifier).state = TopicStatus.inProgress,
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Completed'),
                          selected: selectedStatus == TopicStatus.completed,
                          onSelected: (_) => ref.read(topicsFilterProvider.notifier).state = TopicStatus.completed,
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: Icon(_expandAll ? Icons.unfold_less : Icons.unfold_more, size: 18),
                  label: Text(_expandAll ? 'Collapse' : 'Expand All', style: const TextStyle(fontSize: 12)),
                  onPressed: () => _toggleExpandAll(_sections),
                ),
              ],
            ),
          ),

          const Divider(height: 8),

          // 6. Hierarchical Sections / Parts & Topics List
          Expanded(
            child: topicsAsync.when(
              data: (topics) {
                if (topics.isEmpty) {
                  return _buildEmptyState(context);
                }

                return _buildHierarchicalCurriculum(context, ref, topics);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading topics: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Topic'),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => CreateEditTopicDialog(
              groupId: widget.groupId,
              sections: _sections,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlarmQuickBar(BuildContext context, GroupModel group, List<AlarmModel> alarms) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(
            alarms.isEmpty ? Icons.alarm_add_rounded : Icons.alarm_on_rounded,
            color: alarms.isEmpty ? Colors.grey : Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: alarms.isEmpty
                ? const Text(
                    'No alarms set for this roadmap',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : Text(
                    '${alarms.length} active alarm(s) / daily warnings',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => GroupAlarmSheet.show(context, group),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alarms.isEmpty ? '+ Set Alarm' : 'Manage',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchicalCurriculum(
    BuildContext context,
    WidgetRef ref,
    List<TopicModel> allTopics,
  ) {
    // 1. Group topics by sectionId
    final Map<String, List<TopicModel>> topicsBySection = {};
    for (final topic in allTopics) {
      topicsBySection.putIfAbsent(topic.sectionId, () => []).add(topic);
    }

    // 2. Filter sections by selected month if any
    List<SectionModel> relevantSections = _sections;
    if (_selectedMonth != null) {
      relevantSections = _sections.where((s) => s.monthNumber == _selectedMonth).toList();
    }

    if (relevantSections.isEmpty) {
      // If sections not found or custom group without sections, group by monthNumber
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: allTopics.length,
        itemBuilder: (context, index) => _buildTopicListItem(context, ref, allTopics[index]),
      );
    }

    // Sort relevant sections by month then orderIndex
    relevantSections.sort((a, b) {
      if (a.monthNumber != b.monthNumber) return a.monthNumber.compareTo(b.monthNumber);
      return a.orderIndex.compareTo(b.orderIndex);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: relevantSections.length,
      itemBuilder: (context, index) {
        final section = relevantSections[index];
        final sectionTopics = topicsBySection[section.id] ?? [];
        final completedCount = sectionTopics.where((t) => t.status == TopicStatus.completed).length;
        final totalCount = sectionTopics.length;
        final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
        final isExpanded = _expandedSectionIds.contains(section.id) || _expandAll;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Section / Part Header Tile
              InkWell(
                onTap: () {
                  setState(() {
                    if (_expandedSectionIds.contains(section.id)) {
                      _expandedSectionIds.remove(section.id);
                    } else {
                      _expandedSectionIds.add(section.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Month ${section.monthNumber}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              section.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: progress == 1.0 ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$completedCount / $totalCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: progress == 1.0 ? Colors.green : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          color: progress == 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded list of topics inside this Part
              if (isExpanded) ...[
                const Divider(height: 1),
                if (sectionTopics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No topics match the filter in this section.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sectionTopics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, tIdx) {
                      final topic = sectionTopics[tIdx];
                      return _buildTopicListItem(context, ref, topic);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopicListItem(BuildContext context, WidgetRef ref, TopicModel topic) {
    Color statusColor;
    IconData statusIcon;

    switch (topic.status) {
      case TopicStatus.completed:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case TopicStatus.inProgress:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.timelapse_rounded;
        break;
      case TopicStatus.incomplete:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: IconButton(
        icon: Icon(statusIcon, color: statusColor, size: 24),
        tooltip: 'Toggle status',
        onPressed: () async {
          final nextStatus = topic.status == TopicStatus.incomplete
              ? TopicStatus.inProgress
              : (topic.status == TopicStatus.inProgress ? TopicStatus.completed : TopicStatus.incomplete);
          await ref.read(topicsActionControllerProvider).updateTopicStatus(
                topic.id,
                topic.groupId,
                nextStatus,
              );
        },
      ),
      title: Text(
        '${topic.orderIndex}. ${topic.title}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          decoration: topic.status == TopicStatus.completed ? TextDecoration.lineThrough : null,
          color: topic.status == TopicStatus.completed ? Colors.grey : null,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                topic.status.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                topic.difficulty,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${topic.estimatedMinutes}m',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            if (topic.notes.trim().isNotEmpty)
              const Icon(Icons.note_alt_outlined, size: 14, color: Colors.grey),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TopicDetailScreen(topicId: topic.id)),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No topics match your current filter.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Topic'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CreateEditTopicDialog(
                    groupId: widget.groupId,
                    sections: _sections,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context) {
    final nameController = TextEditingController();
    int monthNum = _selectedMonth ?? 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Section / Chapter'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Section Name *',
                    hintText: 'e.g. Part 1: Foundations or Week 1: Core',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: monthNum,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Month Division', isDense: true),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text('Month $m')))
                      .toList(),
                  onChanged: (val) => setDialogState(() => monthNum = val ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final newSec = SectionModel(
                    id: 'sec_${const Uuid().v4()}',
                    groupId: widget.groupId,
                    name: nameController.text.trim(),
                    monthNumber: monthNum,
                    orderIndex: _sections.length + 1,
                    createdAt: DateTime.now(),
                  );
                  await DatabaseService.instance.insertSection(newSec);
                  await _loadSections();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Add Section'),
            ),
          ],
        ),
      ),
    );
  }
}
