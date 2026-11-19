import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GeneratedDocumentResult {
  final bool success;
  final String filePath;
  final String fileName;
  final String fileType; // 'pdf', 'docx', 'xlsx', 'pptx', 'csv', 'txt'
  final int fileSizeBytes;
  final String? errorMessage;

  GeneratedDocumentResult({
    required this.success,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    this.errorMessage,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AiDocumentGenerator {
  static final AiDocumentGenerator instance = AiDocumentGenerator._internal();
  AiDocumentGenerator._internal();

  Future<Directory> _getOutputDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(docsDir.path, 'ai_documents'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  // -------------------------------------------------------------
  // 1. PROFESSIONAL PDF GENERATION
  // -------------------------------------------------------------
  Future<GeneratedDocumentResult> generatePdf({
    required String title,
    required String content,
    List<List<String>>? tableData,
    List<String>? bulletPoints,
  }) async {
    try {
      final pdf = pw.Document();
      final sanitizedTitle = title.trim().isNotEmpty ? title.trim() : 'ProgressHub Report';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ProgressHub AI Assistant', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text(DateTime.now().toString().substring(0, 10), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#10B981'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      sanitizedTitle,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Main Body Paragraphs
            ...content.split('\n\n').map(
              (paragraph) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  paragraph.trim(),
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                ),
              ),
            ),

            // Bullet points
            if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Key Takeaways:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              ...bulletPoints.map(
                (bp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4, left: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Expanded(child: pw.Text(bp, style: const pw.TextStyle(fontSize: 10.5))),
                    ],
                  ),
                ),
              ),
            ],

            // Table Data
            if (tableData != null && tableData.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: tableData.first,
                data: tableData.skip(1).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
                cellStyle: const pw.TextStyle(fontSize: 9.5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              ),
            ],
          ],
        ),
      );

      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(sanitizedTitle)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(await pdf.save());

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'pdf',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'pdf',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------
  // 2. MICROSOFT WORD (DOCX) GENERATION
  // -------------------------------------------------------------
  Future<GeneratedDocumentResult> generateDocx({
    required String title,
    required String content,
    List<String>? bulletPoints,
  }) async {
    try {
      final archive = Archive();
      final sanitizedTitle = title.trim().isNotEmpty ? title.trim() : 'Document';

      // 1. [Content_Types].xml
      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
      archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

      // 2. _rels/.rels
      const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

      // 3. word/document.xml
      final docXmlBuffer = StringBuffer();
      docXmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      docXmlBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
      docXmlBuffer.writeln('<w:body>');

      // Title Heading
      docXmlBuffer.writeln('<w:p><w:pPr><w:jc w:val="center"/><w:pBdr><w:bottom w:val="single" w:sz="12" w:space="8" w:color="10B981"/></w:pBdr></w:pPr>');
      docXmlBuffer.writeln('<w:r><w:rPr><w:b/><w:sz w:val="48"/><w:color w:val="10B981"/></w:rPr><w:t>${_escapeXml(sanitizedTitle)}</w:t></w:r></w:p>');
      docXmlBuffer.writeln('<w:p/>');

      // Paragraphs
      for (final p in content.split('\n\n')) {
        if (p.trim().isNotEmpty) {
          docXmlBuffer.writeln('<w:p><w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>${_escapeXml(p.trim())}</w:t></w:r></w:p>');
        }
      }

      // Bullet Points
      if (bulletPoints != null) {
        for (final bp in bulletPoints) {
          docXmlBuffer.writeln('<w:p><w:pPr><w:ind w:left="720"/></w:pPr>');
          docXmlBuffer.writeln('<w:r><w:rPr><w:b/><w:color w:val="10B981"/></w:rPr><w:t>• </w:t></w:r>');
          docXmlBuffer.writeln('<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>${_escapeXml(bp)}</w:t></w:r></w:p>');
        }
      }

      docXmlBuffer.writeln('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>');
      docXmlBuffer.writeln('</w:body></w:document>');

      final docXmlStr = docXmlBuffer.toString();
      archive.addFile(ArchiveFile('word/document.xml', docXmlStr.length, utf8.encode(docXmlStr)));

      final zipData = ZipEncoder().encode(archive);
      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(sanitizedTitle)}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(zipData!);

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'docx',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('Error generating DOCX: $e');
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'docx',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------
  // 3. MICROSOFT EXCEL (XLSX) SPREADSHEET GENERATION
  // -------------------------------------------------------------
  Future<GeneratedDocumentResult> generateXlsx({
    required String title,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final archive = Archive();
      final sanitizedTitle = title.trim().isNotEmpty ? title.trim() : 'Spreadsheet';

      // 1. [Content_Types].xml
      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
      archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

      // 2. _rels/.rels
      const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

      // 3. xl/_rels/workbook.xml.rels
      const wbRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRels.length, utf8.encode(wbRels)));

      // 4. xl/workbook.xml
      const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
      archive.addFile(ArchiveFile('xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)));

      // 5. xl/worksheets/sheet1.xml
      final sheetBuffer = StringBuffer();
      sheetBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      sheetBuffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
      sheetBuffer.writeln('<sheetData>');

      int rIndex = 1;
      for (final row in rows) {
        sheetBuffer.writeln('<row r="$rIndex">');
        int cIndex = 0;
        for (final cell in row) {
          final colLetter = String.fromCharCode(65 + (cIndex % 26));
          final cellRef = '$colLetter$rIndex';
          final val = cell.toString();
          final numVal = num.tryParse(val);

          if (numVal != null) {
            sheetBuffer.writeln('<c r="$cellRef"><v>$numVal</v></c>');
          } else {
            sheetBuffer.writeln('<c r="$cellRef" t="inlineStr"><is><t>${_escapeXml(val)}</t></is></c>');
          }
          cIndex++;
        }
        sheetBuffer.writeln('</row>');
        rIndex++;
      }

      sheetBuffer.writeln('</sheetData></worksheet>');
      final sheetStr = sheetBuffer.toString();
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetStr.length, utf8.encode(sheetStr)));

      final zipData = ZipEncoder().encode(archive);
      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(sanitizedTitle)}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(zipData!);

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'xlsx',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('Error generating XLSX: $e');
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'xlsx',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------
  // 4. MICROSOFT POWERPOINT (PPTX) PRESENTATION GENERATION
  // -------------------------------------------------------------
  Future<GeneratedDocumentResult> generatePptx({
    required String title,
    required List<Map<String, dynamic>> slides, // [{'title': 'Slide 1', 'points': ['Point 1']}]
  }) async {
    try {
      final archive = Archive();
      final sanitizedTitle = title.trim().isNotEmpty ? title.trim() : 'Presentation';

      // 1. [Content_Types].xml
      final ctBuffer = StringBuffer();
      ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      ctBuffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
      ctBuffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
      ctBuffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
      ctBuffer.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
      for (int i = 1; i <= slides.length; i++) {
        ctBuffer.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
      }
      ctBuffer.writeln('</Types>');
      archive.addFile(ArchiveFile('[Content_Types].xml', ctBuffer.length, utf8.encode(ctBuffer.toString())));

      // 2. _rels/.rels
      const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

      // 3. ppt/presentation.xml
      final presBuffer = StringBuffer();
      presBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      presBuffer.writeln('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
      presBuffer.writeln('  <p:sldIdLst>');
      for (int i = 1; i <= slides.length; i++) {
        presBuffer.writeln('    <p:sldId id="${255 + i}" r:id="rId$i"/>');
      }
      presBuffer.writeln('  </p:sldIdLst>');
      presBuffer.writeln('  <p:sldSz cx="9144000" cy="5143500"/>');
      presBuffer.writeln('</p:presentation>');
      archive.addFile(ArchiveFile('ppt/presentation.xml', presBuffer.length, utf8.encode(presBuffer.toString())));

      // 4. ppt/_rels/presentation.xml.rels
      final pRelsBuffer = StringBuffer();
      pRelsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      pRelsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
      for (int i = 1; i <= slides.length; i++) {
        pRelsBuffer.writeln('  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
      }
      pRelsBuffer.writeln('</Relationships>');
      archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', pRelsBuffer.length, utf8.encode(pRelsBuffer.toString())));

      // 5. Slides XML files
      int sIndex = 1;
      for (final s in slides) {
        final sTitle = (s['title'] as String?) ?? 'Slide $sIndex';
        final points = (s['points'] as List<dynamic>?) ?? [];

        final slideBuffer = StringBuffer();
        slideBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
        slideBuffer.writeln('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
        slideBuffer.writeln('<p:cSld><p:spTree>');
        slideBuffer.writeln('<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>');

        // Slide Title Box
        slideBuffer.writeln('<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>');
        slideBuffer.writeln('<p:spPr><a:xfrm><a:off x="800000" y="500000"/><a:ext cx="7544000" cy="800000"/></a:xfrm></p:spPr>');
        slideBuffer.writeln('<p:txBody><a:bodyPr/><a:p><a:r><a:rPr lang="en-US" b="1" sz="3600"><a:solidFill><a:srgbClr val="10B981"/></a:solidFill></a:rPr><a:t>${_escapeXml(sTitle)}</a:t></a:r></a:p></p:txBody></p:sp>');

        // Points Box
        slideBuffer.writeln('<p:sp><p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>');
        slideBuffer.writeln('<p:spPr><a:xfrm><a:off x="800000" y="1500000"/><a:ext cx="7544000" cy="3000000"/></a:xfrm></p:spPr>');
        slideBuffer.writeln('<p:txBody><a:bodyPr/>');
        for (final pt in points) {
          slideBuffer.writeln('<a:p><a:r><a:rPr lang="en-US" sz="2000"/><a:t>• ${_escapeXml(pt.toString())}</a:t></a:r></a:p>');
        }
        slideBuffer.writeln('</p:txBody></p:sp>');

        slideBuffer.writeln('</p:spTree></p:cSld></p:sld>');
        final sStr = slideBuffer.toString();
        archive.addFile(ArchiveFile('ppt/slides/slide$sIndex.xml', sStr.length, utf8.encode(sStr)));
        sIndex++;
      }

      final zipData = ZipEncoder().encode(archive);
      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(sanitizedTitle)}_${DateTime.now().millisecondsSinceEpoch}.pptx';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsBytes(zipData!);

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'pptx',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      debugPrint('Error generating PPTX: $e');
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'pptx',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------
  // 5. CSV & TXT GENERATION
  // -------------------------------------------------------------
  Future<GeneratedDocumentResult> generateCsv({
    required String title,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final buffer = StringBuffer();
      for (final row in rows) {
        final line = row.map((cell) {
          final s = cell.toString().replaceAll('"', '""');
          return '"$s"';
        }).join(',');
        buffer.writeln(line);
      }

      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(title)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsString(buffer.toString(), encoding: utf8);

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'csv',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'csv',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<GeneratedDocumentResult> generateTxt({
    required String title,
    required String content,
  }) async {
    try {
      final outDir = await _getOutputDirectory();
      final fileName = '${_cleanFileName(title)}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(p.join(outDir.path, fileName));
      await file.writeAsString(content, encoding: utf8);

      return GeneratedDocumentResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        fileType: 'txt',
        fileSizeBytes: await file.length(),
      );
    } catch (e) {
      return GeneratedDocumentResult(
        success: false,
        filePath: '',
        fileName: '',
        fileType: 'txt',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }

  String _cleanFileName(String input) {
    return input.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_').take(30);
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
