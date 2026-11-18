import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ai_message_model.dart';
import '../../core/ai/ai_service.dart';
import '../providers/groups_provider.dart';
import '../providers/alarms_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/analytics_provider.dart';

class AiChatState {
  final List<AiMessageModel> messages;
  final bool isLoading;
  final String? apiKey;

  const AiChatState({
    required this.messages,
    this.isLoading = false,
    this.apiKey,
  });

  AiChatState copyWith({
    List<AiMessageModel>? messages,
    bool? isLoading,
    String? apiKey,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

final aiAssistantProvider = StateNotifierProvider<AiAssistantNotifier, AiChatState>((ref) {
  return AiAssistantNotifier(ref);
});

class AiAssistantNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;
  final _aiService = AiService.instance;

  AiAssistantNotifier(this._ref) : super(const AiChatState(messages: [])) {
    _init();
  }

  Future<void> _init() async {
    final key = await _aiService.getApiKey();
    final initialGreeting = AiMessageModel(
      id: 'msg_welcome',
      sender: 'ai',
      text: '''
નમસ્તે! હું **ProgressAI** છું 🤖
હું તમારી આખી ProgressHub ઍપને કંટ્રોલ કરી શકું છું અને ChatGPT / Gemini ની જેમ સાચા જવાબો પણ આપી શકું છું.

તમે મને **ગુજરાતી, હિન્દી કે અંગ્રેજી** માં કોઈ પણ આદેશ આપી શકો છો:
• 🚀 *"નવો ગોલ બનાવ: Flutter 3 Months"*
• 🏋️ *"નવો ગોલ બનાવ: Gym & Fitness"*
• ⏰ *"સવારે 6 વાગ્યાનો એલાર્મ રાખ"*
• ✅ *"પહેલા 3 ટોપિક પૂરા થઈ ગયા છે"*
• 🧠 *"Python માં Generators શું છે?"*
''',
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [initialGreeting],
      apiKey: key,
    );
  }

  Future<void> saveApiKey(String key) async {
    await _aiService.saveApiKey(key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AiMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final aiResponse = await _aiService.processPrompt(
        prompt: text.trim(),
        conversationHistory: state.messages,
      );

      final aiMsg = AiMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        text: aiResponse.text,
        actionType: aiResponse.actionType,
        actionTitle: aiResponse.actionTitle,
        actionDetails: aiResponse.actionDetails,
        actionData: aiResponse.actionData,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );

      // Refresh corresponding app providers if an action was executed!
      if (aiResponse.actionType != null) {
        if (aiResponse.actionType!.contains('group')) {
          _ref.read(groupsProvider.notifier).loadGroups();
        } else if (aiResponse.actionType!.contains('alarm')) {
          _ref.read(alarmsProvider.notifier).loadAlarms();
        } else if (aiResponse.actionType!.contains('profile')) {
          _ref.read(userProfileProvider.notifier).loadProfile();
        }
        _ref.invalidate(statsProvider);
      }
    } catch (e) {
      final errorMsg = AiMessageModel(
        id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'ai',
        text: 'માફ કરશો, પ્રોસેસિંગમાં કોઈ સમસ્યા આવી: $e',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  void clearHistory() {
    state = state.copyWith(messages: []);
    _init();
  }
}
