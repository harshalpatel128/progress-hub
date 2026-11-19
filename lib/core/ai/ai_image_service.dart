import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AiImageResult {
  final bool success;
  final String? localFilePath;
  final String? webUrl;
  final String prompt;
  final String? errorMessage;

  AiImageResult({
    required this.success,
    this.localFilePath,
    this.webUrl,
    required this.prompt,
    this.errorMessage,
  });
}

class AiImageService {
  static final AiImageService instance = AiImageService._internal();
  AiImageService._internal();

  /// Generates a real AI image, downloads and persists it locally
  Future<AiImageResult> generateImage({
    required String prompt,
    String style = 'Photorealistic',
    String aspectRatio = '1:1',
  }) async {
    try {
      int width = 768;
      int height = 768;

      if (aspectRatio == '16:9') {
        width = 1024;
        height = 576;
      } else if (aspectRatio == '9:16') {
        width = 576;
        height = 1024;
      } else if (aspectRatio == '4:3') {
        width = 800;
        height = 600;
      }

      String stylePrompt = prompt.trim();
      if (style == 'Cartoon') {
        stylePrompt += ', cute 3D cartoon character, Pixar Disney animation aesthetic, expressive details, colorful vibrant lighting, studio quality 4k illustration';
      } else if (style == 'Photorealistic') {
        stylePrompt += ', 8k resolution, highly detailed photorealistic photography, natural daylight';
      } else if (style == 'Anime') {
        stylePrompt += ', vibrant anime artwork, crisp outlines, studio quality masterpiece';
      } else if (style == '3D Render') {
        stylePrompt += ', 3D isometric render, octane engine, smooth textures, modern minimalist design';
      } else if (style == 'Vector') {
        stylePrompt += ', clean vector art, flat modern illustration, Behance aesthetic';
      } else if (style == 'Digital Art') {
        stylePrompt += ', concept digital art, dramatic lighting, rich color palette';
      }

      final seed = Random().nextInt(1000000);
      final encodedPrompt = Uri.encodeComponent(stylePrompt);
      final imageUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt?width=$width&height=$height&seed=$seed&nologo=true';

      debugPrint('Generating AI Image from URL: $imageUrl');

      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close().timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final docsDir = await getApplicationDocumentsDirectory();
        final imgDir = Directory(p.join(docsDir.path, 'ai_images'));
        if (!await imgDir.exists()) {
          await imgDir.create(recursive: true);
        }

        final fileName = 'ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final localPath = p.join(imgDir.path, fileName);
        final file = File(localPath);

        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
        client.close();

        return AiImageResult(
          success: true,
          localFilePath: localPath,
          webUrl: imageUrl,
          prompt: prompt,
        );
      } else {
        client.close();
        return AiImageResult(
          success: false,
          prompt: prompt,
          errorMessage: 'Server returned HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error generating AI image: $e');
      return AiImageResult(
        success: false,
        prompt: prompt,
        errorMessage: e.toString(),
      );
    }
  }
}
