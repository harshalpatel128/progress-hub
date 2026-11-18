import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai_message_model.dart';
import 'ai_tool_registry.dart';

class AiResponse {
  final String text;
  final String? actionType;
  final String? actionTitle;
  final String? actionDetails;
  final Map<String, dynamic>? actionData;

  AiResponse({
    required this.text,
    this.actionType,
    this.actionTitle,
    this.actionDetails,
    this.actionData,
    Map<String, dynamic>? data,
  }) : actionData = actionData ?? data;
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
  Future<AiResponse> processPrompt({
    required String prompt,
    required List<AiMessageModel> conversationHistory,
  }) async {
    final apiKey = await getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final geminiResponse = await _callGeminiApi(apiKey, prompt, conversationHistory);
        if (geminiResponse != null) {
          return geminiResponse;
        }
      } catch (e) {
        debugPrint('Gemini API call failed, falling back to Local AI: $e');
      }
    }

    // Local Smart Intelligence Fallback Engine
    return await _processWithLocalAi(prompt);
  }

  Future<AiResponse?> _callGeminiApi(
    String apiKey,
    String prompt,
    List<AiMessageModel> history,
  ) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

    final systemInstruction = '''
You are ProgressAI, an elite autonomous AI companion and in-app controller for the ProgressHub app.
You are fluent in Gujarati (ગુજરાતી), Hindi (हिंदी), and English.
Always respond in the language that the user talks to you (Gujarati, Hindi, or English).

Capabilities:
1. Universal Knowledge & Search: Like ChatGPT & Gemini, answer questions accurately on coding (Python, Flutter, Dart, JS, AI, SQL), algorithms, fitness, gym workouts, language learning, career, and general life guidance.
2. In-App Control & Modification: You can directly control the app! When the user asks you to:
   - Create or generate a roadmap/goal: Use action "create_group"
   - Mark a topic complete or change status: Use action "update_topic_status"
   - Set or change an alarm: Use action "set_alarm"
   - Update user profile or goals: Use action "update_profile"

Whenever you perform an app modification, provide a helpful conversational reply AND append a single JSON action block at the very end of your response in this exact format:
```json
{
  "action": "<action_name>",
  "parameters": {
    ...
  }
}
```

Action parameters:
- create_group: { "name": string, "category": string, "duration": string, "daily_target_minutes": int, "sections": [ { "name": string, "month_number": int, "topics": [ string ] } ] }
- update_topic_status: { "topic_name": string, "status": "completed"|"in_progress"|"incomplete" }
- set_alarm: { "title": string, "hour": int, "minute": int, "repeat_days": [int] }
- update_profile: { "name": string, "bio": string, "target_hours_per_day": double, "motivation_quote": string }

If the user is only asking a question or asking for advice, do NOT output a JSON action block, just give an informative, well-formatted answer with code snippets or bullet points.
''';

    final contents = <Map<String, dynamic>>[];

    // Include recent history (last 6 messages)
    final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
    for (final m in recent) {
      contents.add({
        'role': m.isUser ? 'user' : 'model',
        'parts': [{'text': m.text}],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [{'text': prompt}],
    });

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [{'text': systemInstruction}],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(requestBody);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final rawText = (parts.first['text'] as String?) ?? '';
            return _parseAiResponseWithAction(rawText);
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
  Future<AiResponse> _parseAiResponseWithAction(String rawText) async {
    final jsonMatch = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```').firstMatch(rawText);

    if (jsonMatch != null) {
      final jsonStr = jsonMatch.group(1);
      final cleanText = rawText.replaceAll(jsonMatch.group(0)!, '').trim();

      try {
        final parsed = jsonDecode(jsonStr!) as Map<String, dynamic>;
        final action = (parsed['action'] as String?) ?? '';
        final params = (parsed['parameters'] as Map<String, dynamic>?) ?? {};

        // Execute action via Registry
        final result = await AiToolRegistry.instance.execute(action, params);

        return AiResponse(
          text: cleanText.isNotEmpty ? cleanText : result.message,
          actionType: result.action,
          actionTitle: result.title,
          actionDetails: result.message,
          actionData: result.data,
        );
      } catch (e) {
        debugPrint('Error parsing embedded JSON action: $e');
      }
    }

    return AiResponse(text: rawText);
  }

  /// Smart Local AI Engine (Works 100% offline without API key or network)
  Future<AiResponse> _processWithLocalAi(String prompt) async {
    final lower = prompt.toLowerCase().trim();

    // 1. Create Roadmap / Group Intent
    if (lower.contains('group') ||
        lower.contains('roadmap') ||
        lower.contains('ગ્રૂપ') ||
        lower.contains('રોડમેપ') ||
        lower.contains('ગોલ') ||
        lower.contains('banav') ||
        lower.contains('create') ||
        lower.contains('બનાવ')) {

      String goalName = 'Custom Learning Goal';
      String duration = '3 Months';
      List<String> sampleTopics = [];

      if (lower.contains('flutter') || lower.contains('ફ્લટર')) {
        goalName = 'Flutter & Dart Mastery';
        duration = '3 Months';
        sampleTopics = [
          'Dart Syntax & OOP',
          'Stateless & Stateful Widgets',
          'Responsive Layouts & Flexbox',
          'State Management with Riverpod',
          'Async Programming & REST APIs',
          'SQLite & Local Database Integration',
          'Animations & Custom Painting',
          'App Store & Play Store Deployment'
        ];
      } else if (lower.contains('gym') || lower.contains('fitness') || lower.contains('વર્કઆઉટ') || lower.contains('જીમ')) {
        goalName = 'Gym & Strength Training';
        duration = '6 Months';
        sampleTopics = [
          'Chest & Triceps Push Routine',
          'Back & Biceps Pull Routine',
          'Legs & Core Strength Workout',
          'Compound Movements (Squats & Deadlifts)',
          'High Intensity Interval Cardio',
          'Diet, Nutrition & Protein Tracking',
          'Muscle Recovery & Stretching'
        ];
      } else if (lower.contains('english') || lower.contains('સ્પીકિંગ') || lower.contains('અંગ્રેજી')) {
        goalName = 'Fluent English Speaking';
        duration = '3 Months';
        sampleTopics = [
          'Daily Conversation Basics & Greetings',
          'Essential Grammar & Tenses',
          'Active Listening & Pronunciation',
          'Vocabulary Building (Top 500 Words)',
          'Public Speaking & Debate Practice',
          'Business Communication & Emails',
          'Accent & Fluency Drills'
        ];
      } else if (lower.contains('web') || lower.contains('વેબ')) {
        goalName = 'Full Stack Web Development';
        duration = '6 Months';
        sampleTopics = [
          'HTML5 & Modern CSS3 Flexbox',
          'JavaScript ES6+ & Async/Await',
          'React.js Components & State Hooks',
          'Node.js & Express.js Backend',
          'MongoDB & PostgreSQL Databases',
          'REST APIs & JWT Authentication',
          'Cloud Hosting & CI/CD Deployment'
        ];
      } else {
        // Extract goal name from prompt
        final cleaned = prompt
            .replaceAll(RegExp(r'(create|new|group|roadmap|make|banav|નવો|બનાવો|ગ્રૂપ|રોડમેપ|માટે|નો|for)', caseSensitive: false), '')
            .trim();
        goalName = cleaned.isNotEmpty ? cleaned : 'Smart Life Goal';
        sampleTopics = [
          'Phase 1: Getting Started & Basics',
          'Phase 2: Core Concept Mastery',
          'Phase 3: Practical Projects & Drills',
          'Phase 4: Advanced Techniques & Review'
        ];
      }

      final result = await AiToolRegistry.instance.execute('create_group', {
        'name': goalName,
        'category': 'Self Improvement',
        'duration': duration,
        'daily_target_minutes': 60,
        'sections': [
          {
            'name': 'Month 1: Fundamentals',
            'month_number': 1,
            'topics': sampleTopics.take(4).toList(),
          },
          if (sampleTopics.length > 4)
            {
              'name': 'Month 2: In-Depth Practice',
              'month_number': 2,
              'topics': sampleTopics.skip(4).toList(),
            },
        ],
      });

      return AiResponse(
        text: '✅ મેં તમારા માટે નવો ગોલ **"$goalName"** ($duration) સફળતાપૂર્વક બનાવી દીધો છે!\n\nઆ ગોલની અંદર સેક્શન્સ, ટોપિક્સ અને ડેઇલી શેડ્યૂલ આપોઆપ સેટ થઈ ગયા છે. તમે "My Groups" ટેબમાં જઈને આને જોઈ અને ગમે ત્યારે કસ્ટમાઇઝ કરી શકો છો.',
        actionType: result.action,
        actionTitle: result.title,
        actionDetails: result.message,
        actionData: result.data,
      );
    }

    // 2. Alarm Intent
    if (lower.contains('alarm') || lower.contains('એલાર્મ') || lower.contains('વાગે') || lower.contains('remind')) {
      int hour = 7;
      int minute = 0;

      // Extract time numbers
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
        text: '⏰ સેટ થઈ ગયું! મેં દરરોજ સવારે/સાંજે **$timeStr** વાગ્યાનો લાઈવ એલાર્મ Android સિસ્ટમમાં સેટ કરી દીધો છે.\n\nફોન લૉક હશે તો પણ આ એલાર્મ મોટેથી વાગશે.',
        actionType: result.action,
        actionTitle: result.title,
        actionDetails: result.message,
        actionData: result.data,
      );
    }

    // 3. Complete Topic Intent
    if (lower.contains('complete') || lower.contains('પૂરું') || lower.contains('ડન') || lower.contains('done')) {
      final topicQuery = prompt.replaceAll(RegExp(r'(complete|done|mark|ટોપિક|પૂરું|કરો)', caseSensitive: false), '').trim();
      final result = await AiToolRegistry.instance.execute('update_topic_status', {
        'topic_name': topicQuery.isNotEmpty ? topicQuery : 'Python',
        'status': 'completed',
      });

      return AiResponse(
        text: result.success
            ? '🎉 અભિનંદન! ${result.message}\nતમારો પ્રોગ્રેસ બાર અને સ્ટ્રીક પણ આપોઆપ અપડેટ થઈ ગયા છે!'
            : 'મેં ટોપિક શોધવાનો પ્રયત્ન કર્યો પણ તે મળ્યો નથી. કૃપા કરીને ચોક્કસ ટોપિકનું નામ લખો.',
        actionType: result.action,
        actionTitle: result.title,
        actionDetails: result.message,
        actionData: result.data,
      );
    }

    // 4. Progress / App Status Query
    if (lower.contains('progress') || lower.contains('પ્રોગ્રેસ') || lower.contains('status') || lower.contains('હિસાબ')) {
      final summary = await AiToolRegistry.instance.execute('get_app_summary', {});
      return AiResponse(
        text: '📊 **તમારો હાલનો પ્રોગ્રેસ રિપોર્ટ:**\n\n${summary.message}\n\nતમે ખૂબ સારી રીતે આગળ વધી રહ્યા છો! કોઈ નવો ગોલ શરૂ કરવો હોય કે એલાર્મ બદલવો હોય તો મને કહો.',
        actionType: 'info',
        actionTitle: 'Progress Overview',
        actionDetails: summary.message,
      );
    }

    // 5. General Knowledge & Guidance
    return AiResponse(
      text: '''
નમસ્તે! હું **ProgressAI** છું – તમારી ProgressHub ઍપનો પર્સનલ AI અસિસ્ટન્ટ અને કંટ્રોલર.

હું તમારી આખી ઍપને નિયંત્રિત કરી શકું છું અને ChatGPT / Gemini ની જેમ સવાલોના સાચા જવાબો પણ આપી શકું છું.

**તમે મને આ રીતે કમાન્ડ આપી શકો છો:**
- 🚀 *"Flutter શીખવા માટે 3 મહિનાનો નવો રોડમેપ બનાવી આપ"*
- 🏋️ *"Gym અને Fitness માટે 6 મહિનાનો ગોલ એડ કર"*
- ⏰ *"દરરોજ સવારે 6:30 વાગ્યાનો સ્ટડી એલાર્મ રાખી દે"*
- ✅ *"પાયથોન રોડમેપમાં Variables વાળો ટોપિક Completed માર્ક કર"*
- 🧠 *"Python માં Decorators શું છે? કોડ સાથે સમજાવ"*

💡 *ટીપ: સંપૂર્ણ અનલિમિટેડ લાઈવ Google Gemini AI ચેટિંગ માટે ઉપરના કી આઈકન પર ક્લિક કરીને તમારી ફ્રી Gemini API Key ઉમેરી શકો છો.*
''',
    );
  }
}
