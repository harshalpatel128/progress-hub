import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../database/database_service.dart';

class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  final _db = DatabaseService.instance;

  Future<String> exportBackupToFile() async {
    final jsonStr = await _db.exportBackupJson();
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/progresshub_backup_$dateStr.json');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<void> shareBackupFile() async {
    final filePath = await exportBackupToFile();
    await Share.shareXFiles([XFile(filePath)], text: 'ProgressHub Backup Data');
  }

  Future<String> exportTopicsToCsv(String? groupId) async {
    final db = await _db.database;
    final where = groupId != null ? 'WHERE t.group_id = "$groupId"' : '';
    final rows = await db.rawQuery('''
      SELECT t.order_index, t.title, t.status, t.priority, t.difficulty, 
             t.estimated_minutes, t.actual_minutes, s.name as section_name, g.name as group_name
      FROM topics t
      LEFT JOIN sections s ON t.section_id = s.id
      LEFT JOIN groups g ON t.group_id = g.id
      $where
      ORDER BY t.order_index ASC
    ''');

    List<List<dynamic>> csvData = [
      ['Index', 'Group', 'Section', 'Topic Title', 'Status', 'Priority', 'Difficulty', 'Estimated (mins)', 'Actual (mins)']
    ];

    for (final r in rows) {
      csvData.add([
        r['order_index'],
        r['group_name'] ?? '',
        r['section_name'] ?? '',
        r['title'] ?? '',
        r['status'] ?? '',
        r['priority'] ?? '',
        r['difficulty'] ?? '',
        r['estimated_minutes'] ?? 0,
        r['actual_minutes'] ?? 0,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/progresshub_topics_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(csvString);
    return file.path;
  }

  Future<String> generatePdfReport({String? groupId}) async {
    final stats = await _db.getOverallStats(groupId: groupId);
    final groups = await _db.getAllGroups();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ProgressHub Performance Report',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Key Statistics Overview', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Metric', 'Value'],
                data: [
                  ['Total Active Groups', '${stats['totalGroups']}'],
                  ['Total Curriculum Topics', '${stats['totalTopics']}'],
                  ['Completed Topics', '${stats['completedTopics']}'],
                  ['In-Progress Topics', '${stats['inProgressTopics']}'],
                  ['Incomplete Topics', '${stats['incompleteTopics']}'],
                  ['Overall Completion Rate', '${((stats['overallPercentage'] as double) * 100).toStringAsFixed(1)}%'],
                  ['Total Study Hours', '${((stats['totalStudyMinutes'] as int) / 60).toStringAsFixed(1)} hrs'],
                  ['Current Day Streak', '${stats['currentStreak']} days'],
                  ['Longest Day Streak', '${stats['longestStreak']} days'],
                  ['Missed Target Days', '${stats['missedDaysCount']} days'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 25),
              pw.Text('Groups Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Group Name', 'Category', 'Total Topics', 'Completed', 'Progress %'],
                data: groups.map((g) {
                  return [
                    g.name,
                    g.category,
                    '${g.totalTopics}',
                    '${g.completedTopics}',
                    '${(g.progressPercentage * 100).toStringAsFixed(1)}%',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('Generated by ProgressHub - Smart Learning & Goal Tracker',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/progresshub_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
