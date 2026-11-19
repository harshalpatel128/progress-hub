import 'package:flutter/foundation.dart';
import '../database/database_service.dart';

class AiLearningEngine {
  static final AiLearningEngine instance = AiLearningEngine._internal();
  AiLearningEngine._internal();

  final _db = DatabaseService.instance;

  /// Builds a live, comprehensive analytical snapshot of the user's progress and habits
  Future<String> buildLiveAppContext() async {
    final buffer = StringBuffer();

    try {
      // 1. User Profile
      final profile = await _db.getUserProfile();
      buffer.writeln('USER PROFILE:');
      buffer.writeln('- Name: ${profile.name}');
      buffer.writeln('- Target Study: ${profile.targetHoursPerDay} hrs/day');
      if (profile.bio.isNotEmpty) buffer.writeln('- Bio: ${profile.bio}');
      if (profile.motivationQuote.isNotEmpty) buffer.writeln('- Motto: "${profile.motivationQuote}"');

      // 2. Active Groups & In-Depth Analytics
      final groups = await _db.getGroups();
      buffer.writeln('\nACTIVE ROADMAPS & GOALS (${groups.length} Total):');
      if (groups.isEmpty) {
        buffer.writeln('- No roadmaps created yet.');
      } else {
        for (final g in groups) {
          final stats = await _db.getGroupStats(g.id);
          final total = stats['total_topics'] as int? ?? 0;
          final completed = stats['completed_topics'] as int? ?? 0;
          final inProgress = stats['in_progress_topics'] as int? ?? 0;
          final pct = (stats['completion_percentage'] as num?)?.toStringAsFixed(1) ?? '0.0';

          buffer.writeln('- Goal: "${g.name}" (${g.category}, Duration: ${g.durationText})');
          buffer.writeln('  Progress: $completed/$total topics completed ($pct%), $inProgress in progress.');
        }
      }

      // 3. Alarms
      final alarms = await _db.getAlarms();
      final activeAlarms = alarms.where((a) => a.isEnabled).toList();
      buffer.writeln('\nACTIVE ALARMS (${activeAlarms.length} Scheduled):');
      if (activeAlarms.isEmpty) {
        buffer.writeln('- No active alarms set.');
      } else {
        for (final a in activeAlarms) {
          final timeStr = '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';
          buffer.writeln('- Alarm: "$timeStr" - "${a.title}" (Days: ${a.repeatDaysSummary})');
        }
      }

      // 4. Today's Consistency & Streak
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final todayProg = await _db.getDailyProgressByDate(todayStr);
      final streak = await _db.getCurrentStreak();
      int todayMins = 0;
      int todayTopics = 0;
      for (final p in todayProg) {
        todayMins += p.completedMinutes;
        todayTopics += p.topicsCompletedCount;
      }
      buffer.writeln('\nDAILY CONSISTENCY & STREAK:');
      buffer.writeln('- Current Streak: $streak days in a row');
      buffer.writeln('- Today\'s Activity: $todayMins minutes studied, $todayTopics topics completed today');

      // 5. Long-term Learned Memories & Preferences
      final memories = await _db.getAiMemories();
      if (memories.isNotEmpty) {
        buffer.writeln('\nLEARNED USER PREFERENCES & MEMORY (Auto-Trained from previous conversations):');
        for (final m in memories.take(15)) {
          final key = m['key'];
          final val = m['value'];
          buffer.writeln('- $key: $val');
        }
      }
    } catch (e) {
      debugPrint('Error building live AI context: $e');
    }

    return buffer.toString();
  }

  /// Automatically inspects user input and continuously learns new facts, preferences, and habits
  Future<void> extractAndLearnFromUserInput(String input) async {
    final lower = input.toLowerCase().trim();

    try {
      // 1. Learn User Name
      final nameMatch = RegExp(
        r'(?:maru\s+naam|મારું\s+નામ|my\s+name\s+is|i\s+am|hu\s+chu|હું\s+છું)\s+([A-Za-z\u0A80-\u0AFF]+)',
        caseSensitive: false,
      ).firstMatch(input);
      if (nameMatch != null) {
        final extractedName = nameMatch.group(1)!.trim();
        if (extractedName.length > 1 && !extractedName.toLowerCase().contains('progress')) {
          await _db.saveAiMemory(
            category: 'user_profile',
            key: 'user_name',
            value: extractedName,
            context: input,
          );
          // Also sync with user profile
          final profile = await _db.getUserProfile();
          if (profile.name != extractedName) {
            await _db.saveUserProfile(profile.copyWith(name: extractedName));
          }
        }
      }

      // 2. Learn Career & Technology Interests
      if (lower.contains('flutter') || lower.contains('ફ્લટર')) {
        await _db.saveAiMemory(category: 'interest', key: 'primary_tech_interest', value: 'Flutter & Dart', context: input);
      }
      if (lower.contains('python') || lower.contains('પાયથોન')) {
        await _db.saveAiMemory(category: 'interest', key: 'primary_tech_interest', value: 'Python & AI', context: input);
      }
      if (lower.contains('gym') || lower.contains('fitness') || lower.contains('વર્કઆઉટ') || lower.contains('જીમ')) {
        await _db.saveAiMemory(category: 'lifestyle', key: 'health_goal', value: 'Gym Workout & Muscle Building', context: input);
      }
      if (lower.contains('english') || lower.contains('સ્પીકિંગ') || lower.contains('અંગ્રેજી')) {
        await _db.saveAiMemory(category: 'skill', key: 'language_goal', value: 'Fluent English Speaking', context: input);
      }

      // 3. Learn Study Habit & Routine
      final timeWakeMatch = RegExp(r'(\d{1,2})[:.]?(\d{2})?\s*(?:vage|વાગે|am|pm|baje)', caseSensitive: false).firstMatch(lower);
      if (timeWakeMatch != null && (lower.contains('uthu') || lower.contains('ઉઠું') || lower.contains('study') || lower.contains('વાંચું') || lower.contains('vachu'))) {
        final timeStr = timeWakeMatch.group(0) ?? '';
        await _db.saveAiMemory(
          category: 'habit',
          key: 'daily_routine_timing',
          value: 'Preferred active time around $timeStr',
          context: input,
        );
      }

      // 4. Learn Communication Preferences
      if (lower.contains('short ma') || lower.contains('ટૂંકમાં') || lower.contains('concise') || lower.contains('bov lambo nai')) {
        await _db.saveAiMemory(
          category: 'preference',
          key: 'response_length',
          value: 'Prefers concise, direct bullet points instead of long paragraphs',
          context: input,
        );
      }
      if (lower.contains('gujarati ma j') || lower.contains('ગુજરાતીમાં જ') || lower.contains('gujarati only')) {
        await _db.saveAiMemory(
          category: 'preference',
          key: 'language_preference',
          value: 'Strictly Gujarati language responses with warm cultural tone',
          context: input,
        );
      }

      // 5. Learn Target Study Duration
      final hoursMatch = RegExp(r'(\d+)\s*(?:kalak|કલાક|hours|hr)', caseSensitive: false).firstMatch(lower);
      if (hoursMatch != null) {
        final hrs = double.tryParse(hoursMatch.group(1) ?? '2.0') ?? 2.0;
        await _db.saveAiMemory(
          category: 'target',
          key: 'daily_study_target',
          value: '$hrs hours per day',
          context: input,
        );
      }
    } catch (e) {
      debugPrint('Error auto-learning from input: $e');
    }
  }

  /// Generates deep instantaneous in-app analysis of user data in Gujarati
  Future<String> generateDetailedProgressAnalysis() async {
    final profile = await _db.getUserProfile();
    final groups = await _db.getGroups();
    final alarms = await _db.getAlarms();
    final streak = await _db.getCurrentStreak();
    final todayProg = await _db.getDailyProgressByDate(DateTime.now().toIso8601String().substring(0, 10));

    int todayMins = 0;
    int todayTopics = 0;
    for (final p in todayProg) {
      todayMins += p.completedMinutes;
      todayTopics += p.topicsCompletedCount;
    }

    final buffer = StringBuffer();
    buffer.writeln('📊 **${profile.name} નો લાઈવ પ્રોગ્રેસ એનાલિસિસ રિપોર્ટ**\n');

    if (groups.isEmpty) {
      buffer.writeln('હજી સુધી તમે કોઈ ગોલ કે રોડમેપ બનાવ્યો નથી. તમે મને કહી શકો છો: *"મને 3 મહિનાનો Flutter રોડમેપ બનાવી આપ"* અને હું તરત બનાવી દઈશ!');
      return buffer.toString();
    }

    int overallTotal = 0;
    int overallCompleted = 0;

    for (final g in groups) {
      final stats = await _db.getGroupStats(g.id);
      final total = stats['total_topics'] as int? ?? 0;
      final completed = stats['completed_topics'] as int? ?? 0;
      final inProg = stats['in_progress_topics'] as int? ?? 0;
      final remaining = stats['incomplete_topics'] as int? ?? (total - completed);
      final pct = (stats['completion_percentage'] as num?)?.toStringAsFixed(1) ?? '0.0';

      overallTotal += total;
      overallCompleted += completed;

      buffer.writeln('🎯 **${g.name}** (${g.durationText})');
      buffer.writeln('• પ્રગતિ: **$completed / $total ટોપિક્સ ($pct%)**');
      buffer.writeln('• ચાલુ: $inProg | બાકી: $remaining ટોપિક્સ\n');
    }

    final overallPct = overallTotal > 0 ? ((overallCompleted / overallTotal) * 100).toStringAsFixed(1) : '0.0';
    buffer.writeln('📈 **કુલ સારાંશ:**');
    buffer.writeln('• કુલ પૂરા થયેલા ટોપિક્સ: **$overallCompleted / $overallTotal ($overallPct%)**');
    buffer.writeln('• સ્ટ્રીક: **🔥 $streak દિવસોની સતત કન્સિસ્ટન્સી**');
    buffer.writeln('• આજનો અભ્યાસ: **$todayMins મિનિટ, $todayTopics ટોપિક્સ**');

    final activeAlarms = alarms.where((a) => a.isEnabled).toList();
    if (activeAlarms.isNotEmpty) {
      final firstAlarm = activeAlarms.first;
      final timeStr = '${firstAlarm.hour.toString().padLeft(2, '0')}:${firstAlarm.minute.toString().padLeft(2, '0')}';
      buffer.writeln('• એલાર્મ: **દરરોજ સવારે/સાંજે $timeStr વાગ્યે લાઈવ સેટ છે**');
    }

    buffer.writeln('\n💡 **AI વિશ્લેષણ અને સલાહ:**');
    if (overallCompleted == 0) {
      buffer.writeln('તમે રોડમેપ સેટ કરી લીધો છે! આજે માત્ર ૧ કે ૨ ટોપિક પૂરા કરીને શરૂઆત કરો જેથી મોમેન્ટમ બને.');
    } else if (todayTopics == 0) {
      buffer.writeln('તમારી $streak દિવસની સ્ટ્રીક ચાલુ છે! આજનો ૧ ટોપિક પતાવીને આ સ્ટ્રીક તૂટવા ન દેશો.');
    } else {
      buffer.writeln('ખૂબ સરસ! આજે તમે $todayTopics ટોપિક પૂરા કર્યા છે. આ જ ગતિથી તમે સમયસર તમારો ગોલ સિદ્ધ કરી લેશો!');
    }

    return buffer.toString();
  }
}
