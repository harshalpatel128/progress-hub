import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class ExtractedFileContent {
  final bool success;
  final String fileName;
  final String fileType;
  final String textContent;
  final String? base64Data;
  final String? mimeType;
  final int fileSizeBytes;
  final String? errorMessage;

  ExtractedFileContent({
    required this.success,
    required this.fileName,
    required this.fileType,
    required this.textContent,
    this.base64Data,
    this.mimeType,
    required this.fileSizeBytes,
    this.errorMessage,
  });
}

class AiFileReader {
  static final AiFileReader instance = AiFileReader._internal();
  AiFileReader._internal();

  /// Reads and extracts text or base64 data from an uploaded file
  Future<ExtractedFileContent> readFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ExtractedFileContent(
          success: false,
          fileName: filePath.split(Platform.pathSeparator).last,
          fileType: 'unknown',
          textContent: '',
          fileSizeBytes: 0,
          errorMessage: 'File not found on device',
        );
      }

      final fileName = file.path.split(Platform.pathSeparator).last;
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      final bytes = await file.readAsBytes();
      final size = bytes.length;

      // 1. Text & Code Files
      if (['txt', 'csv', 'json', 'md', 'dart', 'py', 'js', 'html', 'css', 'sql', 'yaml', 'xml'].contains(ext)) {
        final text = utf8.decode(bytes, allowMalformed: true);
        return ExtractedFileContent(
          success: true,
          fileName: fileName,
          fileType: ext,
          textContent: text,
          fileSizeBytes: size,
        );
      }

      // 2. Images (JPEG, PNG, WEBP)
      if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        final b64 = base64Encode(bytes);
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        return ExtractedFileContent(
          success: true,
          fileName: fileName,
          fileType: 'image',
          textContent: '[Image attached: $fileName]',
          base64Data: b64,
          mimeType: mime,
          fileSizeBytes: size,
        );
      }

      // 3. Word Document (.docx)
      if (ext == 'docx') {
        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          final docFile = archive.findFile('word/document.xml');
          if (docFile != null) {
            final xmlStr = utf8.decode(docFile.content as List<int>, allowMalformed: true);
            // Extract text inside <w:t> tags
            final matches = RegExp(r'<w:t[^>]*>([^<]*)</w:t>').allMatches(xmlStr);
            final buffer = StringBuffer();
            for (final m in matches) {
              buffer.write('${m.group(1)} ');
            }
            return ExtractedFileContent(
              success: true,
              fileName: fileName,
              fileType: 'docx',
              textContent: buffer.toString().trim(),
              fileSizeBytes: size,
            );
          }
        } catch (e) {
          debugPrint('Error parsing docx: $e');
        }
      }

      // 4. Fallback for PDF or other binary files
      if (ext == 'pdf') {
        // Attempt basic text string extraction from uncompressed streams
        final rawStr = String.fromCharCodes(bytes);
        final textMatches = RegExp(r'\(([^)]+)\)\s*Tj').allMatches(rawStr);
        final extracted = textMatches.map((m) => m.group(1)).whereType<String>().join(' ');

        return ExtractedFileContent(
          success: true,
          fileName: fileName,
          fileType: 'pdf',
          textContent: extracted.isNotEmpty ? extracted : '[PDF Document attached: $fileName - ${size ~/ 1024} KB]',
          fileSizeBytes: size,
        );
      }

      return ExtractedFileContent(
        success: true,
        fileName: fileName,
        fileType: ext,
        textContent: '[Binary file attached: $fileName - ${size ~/ 1024} KB]',
        fileSizeBytes: size,
      );
    } catch (e) {
      debugPrint('Error in AiFileReader: $e');
      return ExtractedFileContent(
        success: false,
        fileName: filePath.split(Platform.pathSeparator).last,
        fileType: 'error',
        textContent: '',
        fileSizeBytes: 0,
        errorMessage: e.toString(),
      );
    }
  }
}
