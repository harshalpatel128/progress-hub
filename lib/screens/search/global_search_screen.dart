import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/topic_model.dart';
import '../../core/database/database_service.dart';
import '../topics/topic_detail_screen.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  List<TopicModel> _searchResults = [];
  bool _isLoading = false;

  String? _statusFilter;
  String? _priorityFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);

    final db = await DatabaseService.instance.database;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      whereClauses.add('(t.title LIKE ? OR t.notes LIKE ? OR s.name LIKE ?)');
      final pattern = '%${query.trim()}%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    if (_statusFilter != null) {
      whereClauses.add('t.status = ?');
      whereArgs.add(_statusFilter);
    }

    if (_priorityFilter != null) {
      whereClauses.add('t.priority = ?');
      whereArgs.add(_priorityFilter);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final rows = await db.rawQuery('''
      SELECT t.*, s.name as section_name, s.month_number, g.name as group_name
      FROM topics t
      LEFT JOIN sections s ON t.section_id = s.id
      LEFT JOIN groups g ON t.group_id = g.id
      $whereSql
      ORDER BY t.order_index ASC
      LIMIT 100
    ''', whereArgs);

    if (mounted) {
      setState(() {
        _searchResults = rows.map((e) => TopicModel.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search across 405+ topics, notes...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: (val) => _performSearch(val),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Status'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _performSearch(_searchController.text);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _statusFilter == 'completed',
                  onSelected: (_) {
                    setState(() => _statusFilter = _statusFilter == 'completed' ? null : 'completed');
                    _performSearch(_searchController.text);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('In Progress'),
                  selected: _statusFilter == 'in_progress',
                  onSelected: (_) {
                    setState(() => _statusFilter = _statusFilter == 'in_progress' ? null : 'in_progress');
                    _performSearch(_searchController.text);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('High Priority'),
                  selected: _priorityFilter == 'High',
                  onSelected: (_) {
                    setState(() => _priorityFilter = _priorityFilter == 'High' ? null : 'High');
                    _performSearch(_searchController.text);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty ? 'Type above to search all roadmaps' : 'No topics found matching search criteria',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final topic = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Text('#${topic.orderIndex}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text('${topic.sectionName ?? ""} • ${topic.status.label}'),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => TopicDetailScreen(topicId: topic.id)),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
