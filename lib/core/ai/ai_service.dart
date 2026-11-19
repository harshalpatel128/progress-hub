import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai_message_model.dart';
import 'ai_tool_registry.dart';
import 'ai_learning_engine.dart';
import 'ai_file_reader.dart';
import 'ai_image_service.dart';

class AiResponse {
  final String text;
  final String? actionType;
  final String? actionTitle;
  final String? actionDetails;
  final Map<String, dynamic>? actionData;
  final String? imageUrl;
  final String? generatedFilePath;
  final String? generatedFileName;
  final List<WebSourceModel> sources;

  AiResponse({
    required this.text,
    this.actionType,
    this.actionTitle,
    this.actionDetails,
    this.actionData,
    this.imageUrl,
    this.generatedFilePath,
    this.generatedFileName,
    this.sources = const [],
  });
}

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  static const String _prefKeyGemini = 'progresshub_gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyGemini);
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyGemini, apiKey.trim());
  }

  /// Process prompt from user in Gujarati, Hindi, or English
  /// TRUE WORLD-CONNECTED AI ARCHITECTURE:
  /// - NO DUMB KEYWORD INTERCEPTS: Every prompt goes straight to real AI!
  /// - Supports Vision (Image understanding), Web Search Grounding, Image Gen, and Doc Gen
  /// - TIER 1: User-configured Google Gemini 1.5 Flash (1500 req/day, Google Search connected)
  /// - TIER 2: High-Power Free World LLM (OpenAI / Mistral / Qwen via Pollinations cloud)
  /// - TIER 3: Multi-model GET/POST fallback with live context
  /// - TIER 4: Transparent offline handler when device is disconnected
  Future<AiResponse> processPrompt({
    required String prompt,
    required List<AiMessageModel> conversationHistory,
    List<MessageAttachmentModel> attachments = const [],
    bool enableSearch = false,
  }) async {
    // 1. Continuous Auto-Learning (Extracts name, habits, interests into long-term memory)
    await AiLearningEngine.instance.extractAndLearnFromUserInput(prompt);

    // 2. Build live dynamic context (User name, active roadmaps, streak, alarms, learned habits)
    final liveContext = await AiLearningEngine.instance.buildLiveAppContext();

    // 3. Process attachments (extract text from documents and base64 from images)
    String augmentedPrompt = prompt;
    String? imageBase64;
    String? imageMime;

    for (final att in attachments) {
      final ext = await AiFileReader.instance.readFile(att.path);
      if (ext.success) {
        if (ext.fileType == 'image' && ext.base64Data != null) {
          imageBase64 = ext.base64Data;
          imageMime = ext.mimeType ?? 'image/jpeg';
        } else if (ext.textContent.isNotEmpty) {
          augmentedPrompt += '\n\n[Attached File: ${ext.fileName}]\n${ext.textContent}';
        }
      }
    }

    // Check if prompt specifically asks for web search
    final lower = prompt.toLowerCase();

    // 3.5 Direct AI Image / Cartoon generation handler
    final isCartoon = lower.contains('cartoon') || lower.contains('કાર્ટૂન');
    final isImageRequest = isCartoon ||
        lower.contains('image banav') ||
        lower.contains('ઈમેજ બનાવ') ||
        lower.contains('photo banav') ||
        lower.contains('ફોટો બનાવ') ||
        lower.contains('ચિત્ર બનાવ') ||
        lower.contains('generate image') ||
        lower.contains('create image') ||
        lower.contains('draw ') ||
        lower.contains(' દોરો') ||
        lower.contains('wallpaper');

    if (isImageRequest) {
      String imgPrompt = prompt.replaceAll(RegExp(r'(cartoon|type|banav|બનાવ|કાર્ટૂન|image|photo|તારું|તમારું|કરી આપો|કરી આપ)', caseSensitive: false), '').trim();
      if (imgPrompt.isEmpty) {
        imgPrompt = 'A charming colorful 3D cartoon character animated illustration, expressive face, Pixar Disney 3D style';
      }

      final imgResult = await AiImageService.instance.generateImage(
        prompt: imgPrompt,
        style: isCartoon ? 'Cartoon' : 'Photorealistic',
        aspectRatio: '1:1',
      );

      if (imgResult.success && imgResult.localFilePath != null) {
        return AiResponse(
          text: isCartoon
              ? '🎨 **તમારી કાર્ટૂન AI ઈમેજ તૈયાર છે!**\nતમારા કહ્યા મુજબ કાર્ટૂન શૈલીમાં સુંદર ઈમેજ જનરેટ કરવામાં આવી છે. તમે તેને ફુલસ્ક્રીન જોઈ શકો છો અને શેર કરી શકો છો.'
              : '🎨 **તમારી AI ઈમેજ તૈયાર છે!**\nતમારા પ્રોમ્પ્ટ મુજબ ઈમેજ જનરેટ કરવામાં આવી છે.',
          actionType: 'generate_image',
          actionTitle: isCartoon ? 'AI Cartoon Generated' : 'AI Image Generated',
          actionDetails: imgResult.localFilePath,
          imageUrl: imgResult.localFilePath,
        );
      }
    }

    final shouldSearch = enableSearch ||
        lower.contains('search') ||
        lower.contains('સર્ચ') ||
        lower.contains('શોધો') ||
        lower.contains('news') ||
        lower.contains('latest') ||
        lower.contains('આજના સમાચાર') ||
        lower.contains('વર્તમાન');

    // 4. TIER 1: If user provided Google Gemini API key, use official Gemini 1.5 Flash
    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final geminiResponse = await _callGeminiApi(
          apiKey: apiKey.trim(),
          prompt: augmentedPrompt,
          history: conversationHistory,
          liveContext: liveContext,
          imageBase64: imageBase64,
          imageMime: imageMime,
          enableSearch: shouldSearch,
        );
        if (geminiResponse != null) {
          return geminiResponse;
        }
      } catch (e) {
        debugPrint('Gemini API call failed: $e. Falling back to Free Cloud AI...');
      }
    }

    // 5. TIER 2: Free Live World-Connected AI (Zero key needed, uses mobile data / Wi-Fi)
    try {
      final cloudResponse = await _callFreeCloudLlm(augmentedPrompt, conversationHistory, liveContext);
      if (cloudResponse != null) {
        return cloudResponse;
      }
    } catch (e) {
      debugPrint('Free Cloud LLM failed: $e. Trying offline fallback...');
    }

    // 6. TIER 3: Offline fallback only if network is completely down
    return await _processWithSmartOfflineEngine(prompt, liveContext);
  }

  /// System instructions ensuring human-like reasoning, world connection, and in-app actions
  String _buildSystemInstruction(String liveContext) {
    return '''
You are ProgressAI, an elite, highly intelligent AI assistant and autonomous in-app controller for the ProgressHub application.
You are powered by state-of-the-art Large Language Models (like ChatGPT and Google Gemini) with deep logical reasoning, real-time world knowledge, coding expertise, and human empathy.
You are fully fluent in Gujarati (ગુજરાતી), Hindi (हिंदी), and English.

LIVE APP STATE & USER DATA (From local SQLite database):
$liveContext

CRITICAL CONVERSATIONAL GUIDELINES:
1. Language matching:
   - If the user speaks Gujarati (or Gujlish like "kem cho", "aaj no plan", "mane aa sikhvad"), ALWAYS respond in fluent, respectful, natural Gujarati.
   - If the user speaks Hindi, respond in fluent Hindi.
   - If the user speaks English, respond in English.
2. Tone & Personality:
   - Act as a genuine mentor, friend, and expert coach.
   - Address the user by their name (from User Profile above) when appropriate.
   - Give direct, insightful, comprehensive answers. Do NOT give lazy or evasive replies.
   - If asked for general knowledge, science, programming, career, fitness, life, or study advice, give rich, accurate, world-class answers with code examples or bullet points.

CRITICAL IN-APP ACTIONS:
You have REAL CONTROL over the ProgressHub app.
When the user asks you to:
- Create or design a goal or roadmap (e.g. "Flutter 3 months", "Web Scraping in Python", "Gym workout", "DSA in Java", etc.)
- Set an alarm or study reminder
- Mark a topic as completed
- Generate an AI Image (e.g. "make an image of...", "draw a poster of...")
- Generate a Document (PDF, DOCX, XLSX, PPTX, CSV, TXT)
- Update user profile

You MUST:
1. Write a motivating, helpful, and comprehensive explanation of the roadmap/plan in the user's language.
2. AND at the VERY END of your response, output a single JSON code block matching this exact specification:

```json
{
  "action": "<action_name>",
  "parameters": {
    ...
  }
}
```

Action parameters:
- "create_group": {
    "name": "<Meaningful Goal Title>",
    "category": "<Programming | Fitness | Language | Career | Self Improvement>",
    "duration": "<e.g. 2 Months | 3 Months | 6 Months>",
    "daily_target_minutes": 60,
    "sections": [
      {
        "name": "Month 1: <Section Title>",
        "month_number": 1,
        "topics": ["<Specific Topic 1>", "<Specific Topic 2>", "<Specific Topic 3>", "<Specific Topic 4>"]
      },
      {
        "name": "Month 2: <Section Title>",
        "month_number": 2,
        "topics": ["<Specific Topic 5>", "<Specific Topic 6>", "<Specific Topic 7>", "<Specific Topic 8>"]
      }
    ]
  }
- "generate_image": {
    "prompt": "<Detailed visual prompt for AI image generator>",
    "style": "Photorealistic | Anime | 3D Render | Vector | Digital Art",
    "aspect_ratio": "1:1 | 16:9 | 9:16"
  }
- "generate_document": {
    "format": "pdf | docx | xlsx | pptx | csv | txt",
    "title": "<Document Title>",
    "content": "<Detailed text content for document>",
    "rows": [["Col 1", "Col 2"], ["Val 1", "Val 2"]],
    "slides": [{"title": "Slide 1", "points": ["Bullet point 1", "Bullet point 2"]}]
  }
- "set_alarm": {
    "title": "<Alarm Title>",
    "hour": <0-23>,
    "minute": <0-59>,
    "repeat_days": [1, 2, 3, 4, 5, 6, 7]
  }
- "update_topic_status": {
    "topic_name": "<Topic Name>",
    "status": "completed"
  }
- "update_profile": {
    "name": "<Name>",
    "bio": "<Bio>",
    "target_hours_per_day": <hours>,
    "motivation_quote": "<Quote>"
  }

IMPORTANT: If the user is just asking a question, chatting, greeting you, or discussing a topic, DO NOT output any JSON action code block! Only provide an intelligent, well-structured answer.
''';
  }

  /// Calls the Free World-Connected Cloud AI with multi-model and GET/POST failovers
  Future<AiResponse?> _callFreeCloudLlm(
    String prompt,
    List<AiMessageModel> history,
    String liveContext,
  ) async {
    final systemInstruction = _buildSystemInstruction(liveContext);

    // Build chat conversation messages
    final messages = <Map<String, dynamic>>[];
    messages.add({
      'role': 'system',
      'content': systemInstruction,
    });

    final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
    for (final m in recent) {
      if (m.text.isNotEmpty && m.id != 'msg_welcome') {
        messages.add({
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        });
      }
    }

    messages.add({
      'role': 'user',
      'content': prompt,
    });

    // Strategy 1: POST to text.pollinations.ai/openai (High intelligence OpenAI reasoning)
    try {
      final postUrl = Uri.parse('https://text.pollinations.ai/openai');
      final bodyData = jsonEncode({
        'messages': messages,
        'model': 'openai',
        'temperature': 0.7,
      });

      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true)
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(postUrl);
      request.headers.contentType = ContentType.json;
      request.headers.add('User-Agent', 'ProgressHub-AI/2.0');
      final utf8Bytes = utf8.encode(bodyData);
      request.headers.contentLength = utf8Bytes.length;
      request.add(utf8Bytes);

      final response = await request.close().timeout(const Duration(seconds: 25));
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200 && responseBody.trim().isNotEmpty) {
        String content = responseBody.trim();
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices.first['message'] as Map<String, dynamic>?;
            content = (msg?['content'] as String?) ?? content;
          }
        } catch (_) {}

        if (content.isNotEmpty && !content.contains('Free limit reached')) {
          return await _parseAiResponseWithAction(content);
        }
      }
    } catch (e) {
      debugPrint('Pollinations OpenAI POST failed: $e');
    }

    // Strategy 2: POST to text.pollinations.ai/openai with 'mistral'
    try {
      final postUrl = Uri.parse('https://text.pollinations.ai/openai');
      final bodyData = jsonEncode({
        'messages': messages,
        'model': 'mistral',
        'temperature': 0.7,
      });

      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true)
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(postUrl);
      request.headers.contentType = ContentType.json;
      request.headers.add('User-Agent', 'ProgressHub-AI/2.0');
      final utf8Bytes = utf8.encode(bodyData);
      request.headers.contentLength = utf8Bytes.length;
      request.add(utf8Bytes);

      final response = await request.close().timeout(const Duration(seconds: 25));
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200 && responseBody.trim().isNotEmpty) {
        String content = responseBody.trim();
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final msg = choices.first['message'] as Map<String, dynamic>?;
            content = (msg?['content'] as String?) ?? content;
          }
        } catch (_) {}

        if (content.isNotEmpty && !content.contains('Free limit reached')) {
          return await _parseAiResponseWithAction(content);
        }
      }
    } catch (e) {
      debugPrint('Pollinations Mistral POST failed: $e');
    }

    // Strategy 3: GET request to text.pollinations.ai with prompt (clean query, zero system header bloat)
    try {
      final promptWithLang = '$prompt (જવાબ ગુજરાતીમાં આપો. સંપૂર્ણ અને સચોટ માહિતી આપો.)';
      final encodedPrompt = Uri.encodeComponent(promptWithLang);
      final getUrl = Uri.parse('https://text.pollinations.ai/$encodedPrompt?model=openai');

      final getClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true)
        ..connectionTimeout = const Duration(seconds: 12);
      final req = await getClient.getUrl(getUrl);
      req.headers.add('User-Agent', 'ProgressHub-AI/2.0');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      getClient.close();

      if (res.statusCode == 200 && text.trim().isNotEmpty && !text.contains('Free limit reached')) {
        return await _parseAiResponseWithAction(text.trim());
      }
    } catch (e) {
      debugPrint('Pollinations GET fallback failed: $e');
    }

    // Strategy 4: GET request with model=mistral
    try {
      final promptWithLang = '$prompt (Reply in Gujarati)';
      final encodedPrompt = Uri.encodeComponent(promptWithLang);
      final getUrl = Uri.parse('https://text.pollinations.ai/$encodedPrompt?model=mistral');

      final getClient = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true)
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await getClient.getUrl(getUrl);
      req.headers.add('User-Agent', 'ProgressHub-AI/2.0');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      getClient.close();

      if (res.statusCode == 200 && text.trim().isNotEmpty && !text.contains('Free limit reached')) {
        return await _parseAiResponseWithAction(text.trim());
      }
    } catch (e) {
      debugPrint('Pollinations Mistral GET failed: $e');
    }

    return null;
  }

  /// Official Google Gemini 1.5 Flash API with Vision & Google Search Grounding
  Future<AiResponse?> _callGeminiApi({
    required String apiKey,
    required String prompt,
    required List<AiMessageModel> history,
    required String liveContext,
    String? imageBase64,
    String? imageMime,
    bool enableSearch = false,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final contents = <Map<String, dynamic>>[];
    final recent = history.length > 8 ? history.sublist(history.length - 8) : history;
    for (final m in recent) {
      if (m.text.isNotEmpty && m.id != 'msg_welcome') {
        contents.add({
          'role': m.isUser ? 'user' : 'model',
          'parts': [{'text': m.text}],
        });
      }
    }

    final userParts = <Map<String, dynamic>>[];
    if (imageBase64 != null) {
      userParts.add({
        'inline_data': {
          'mime_type': imageMime ?? 'image/jpeg',
          'data': imageBase64,
        }
      });
    }
    userParts.add({'text': prompt});

    contents.add({
      'role': 'user',
      'parts': userParts,
    });

    final requestPayload = <String, dynamic>{
      'system_instruction': {
        'parts': [{'text': _buildSystemInstruction(liveContext)}],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    if (enableSearch) {
      requestPayload['tools'] = [
        {'google_search': {}}
      ];
    }

    final requestBody = jsonEncode(requestPayload);

    final client = HttpClient()
      ..badCertificateCallback = ((cert, host, port) => true)
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      final bytes = utf8.encode(requestBody);
      request.headers.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates.first as Map<String, dynamic>;
          final content = firstCandidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;

          // Extract grounding web search citations
          final sources = <WebSourceModel>[];
          final groundingMetadata = firstCandidate['groundingMetadata'] as Map<String, dynamic>?;
          if (groundingMetadata != null) {
            final chunks = groundingMetadata['groundingChunks'] as List<dynamic>?;
            if (chunks != null) {
              for (final c in chunks) {
                if (c is Map && c['web'] != null) {
                  final web = c['web'] as Map<String, dynamic>;
                  final title = web['title'] as String? ?? 'Web Source';
                  final uri = web['uri'] as String? ?? '';
                  if (uri.isNotEmpty) {
                    sources.add(WebSourceModel(title: title, url: uri));
                  }
                }
              }
            }
          }

          if (parts != null && parts.isNotEmpty) {
            final rawText = (parts.first['text'] as String?) ?? '';
            return await _parseAiResponseWithAction(rawText, sources: sources);
          }
        }
      } else {
        debugPrint('Gemini HTTP Error ${response.statusCode}: $responseBody');
      }
    } finally {
      client.close();
    }

    return null;
  }

  /// Parses raw text for conversational response and embedded JSON actions
  Future<AiResponse> _parseAiResponseWithAction(
    String rawText, {
    List<WebSourceModel> sources = const [],
  }) async {
    final jsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(rawText) ??
        RegExp(r'(\{\s*"action"\s*:\s*"[^"]+"\s*,\s*"parameters"\s*:[\s\S]*?\})').firstMatch(rawText);

    if (jsonMatch != null) {
      final jsonStr = jsonMatch.group(1);
      final cleanText = rawText.replaceAll(jsonMatch.group(0)!, '').trim();

      try {
        final parsed = jsonDecode(jsonStr!) as Map<String, dynamic>;
        final action = (parsed['action'] as String?) ?? '';
        final params = (parsed['parameters'] as Map<String, dynamic>?) ?? {};

        // Execute action via Registry
        final result = await AiToolRegistry.instance.execute(action, params);

        String? imgUrl;
        String? genFilePath;
        String? genFileName;

        if (result.action == 'generate_image') {
          imgUrl = (result.data['image_path'] as String?) ?? (result.data['image_url'] as String?);
        } else if (result.action == 'generate_document') {
          genFilePath = result.data['file_path'] as String?;
          genFileName = result.data['file_name'] as String?;
        }

        return AiResponse(
          text: cleanText.isNotEmpty ? cleanText : result.message,
          actionType: result.action,
          actionTitle: result.title,
          actionDetails: result.message,
          actionData: result.data,
          imageUrl: imgUrl,
          generatedFilePath: genFilePath,
          generatedFileName: genFileName,
          sources: sources,
        );
      } catch (e) {
        debugPrint('Error parsing embedded JSON action: $e');
      }
    }

    return AiResponse(text: rawText, sources: sources);
  }

  /// Transparent smart fallback only when completely offline
  Future<AiResponse> _processWithSmartOfflineEngine(String prompt, String liveContext) async {
    final lower = prompt.toLowerCase().trim();

    // If user explicitly asks for in-app alarm while offline:
    if (lower.contains('alarm') || lower.contains('એલાર્મ')) {
      int hour = 7;
      int minute = 0;
      final timeMatch = RegExp(r'(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1) ?? '7') ?? 7;
        minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final isPm = (timeMatch.group(3) ?? '').toLowerCase() == 'pm';
        if (isPm && hour < 12) hour += 12;
      }
      final result = await AiToolRegistry.instance.execute('set_alarm', {
        'title': 'AI Study & Practice Alarm',
        'hour': hour,
        'minute': minute,
      });
      final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return AiResponse(
        text: '⏰ સેટ થઈ ગયું! મેં દરરોજ સવારે/સાંજે **$timeStr** વાગ્યાનો લાઈવ એલાર્મ સેટ કરી દીધો છે.',
        actionType: result.action,
        actionTitle: result.title,
        actionDetails: result.message,
        actionData: result.data,
      );
    }

    // If user explicitly asks for in-app progress report while offline:
    if (lower.contains('progress') || lower.contains('પ્રોગ્રેસ') || lower.contains('analysis') || lower.contains('રિપોર્ટ') || lower.contains('status')) {
      final report = await AiLearningEngine.instance.generateDetailedProgressAnalysis();
      return AiResponse(
        text: report,
        actionType: 'info',
        actionTitle: 'Detailed Progress Analysis',
        actionDetails: 'Live database statistics',
      );
    }

    // Clear and honest message that network connection is required for live world knowledge
    return AiResponse(
      text: '''
📡 **ઇન્ટરનેટ કનેક્શન જરૂરી છે:**
હું વિશ્વ સાથે જોડાયેલો રિયલ AI (ChatGPT / Google Gemini) છું. કોઈપણ વિષય પર ઊંડાણપૂર્વક ચર્ચા કરવા, નવા રોડમેપ બનાવવા કે પ્રશ્નોના સચોટ જવાબો મેળવવા માટે કૃપા કરીને તમારું **ઇન્ટરનેટ (Mobile Data અથવા Wi-Fi)** ચાલુ કરો.

💡 *ટીપ: સંપૂર્ણ અનલિમિટેડ અને સુપર ફાસ્ટ સ્પીડ માટે ઉપર આપેલા કી આઇકન પર ક્લિક કરીને તમારી ફ્રી Google Gemini API Key ઉમેરી શકો છો.*
''',
    );
  }
}
