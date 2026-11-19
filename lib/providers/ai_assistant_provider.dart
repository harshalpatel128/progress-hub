import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ai_message_model.dart';
import '../../models/ai_conversation_model.dart';
import '../../core/ai/ai_service.dart';
import '../../core/database/database_service.dart';
import '../providers/groups_provider.dart';
import '../providers/alarms_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/analytics_provider.dart';

class AiChatState {
  final List<AiConversationModel> conversations;
  final String? activeConversationId;
  final List<AiMessageModel> messages;
  final bool isLoading;
  final bool isGenerating;
  final String? apiKey;
  final String searchQuery;
  final bool isWebSearchEnabled;
  final String selectedModel;
  final List<MessageAttachmentModel> pendingAttachments;

  const AiChatState({
    this.conversations = const [],
    this.activeConversationId,
    required this.messages,
    this.isLoading = false,
    this.isGenerating = false,
    this.apiKey,
    this.searchQuery = '',
    this.isWebSearchEnabled = true,
    this.selectedModel = 'gemini-1.5-flash',
    this.pendingAttachments = const [],
  });

  AiConversationModel? get activeConversation {
    if (activeConversationId == null) return null;
    try {
      return conversations.firstWhere((c) => c.id == activeConversationId);
    } catch (_) {
      return null;
    }
  }

  List<AiConversationModel> get filteredConversations {
    if (searchQuery.trim().isEmpty) return conversations;
    final q = searchQuery.toLowerCase().trim();
    return conversations.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  AiChatState copyWith({
    List<AiConversationModel>? conversations,
    String? activeConversationId,
    List<AiMessageModel>? messages,
    bool? isLoading,
    bool? isGenerating,
    String? apiKey,
    String? searchQuery,
    bool? isWebSearchEnabled,
    String? selectedModel,
    List<MessageAttachmentModel>? pendingAttachments,
  }) {
    return AiChatState(
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      apiKey: apiKey ?? this.apiKey,
      searchQuery: searchQuery ?? this.searchQuery,
      isWebSearchEnabled: isWebSearchEnabled ?? this.isWebSearchEnabled,
      selectedModel: selectedModel ?? this.selectedModel,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }
}

final aiAssistantProvider = StateNotifierProvider<AiAssistantNotifier, AiChatState>((ref) {
  return AiAssistantNotifier(ref);
});

class AiAssistantNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;
  final _aiService = AiService.instance;
  final _db = DatabaseService.instance;
  bool _cancelled = false;

  AiAssistantNotifier(this._ref) : super(const AiChatState(messages: [])) {
    _init();
  }

  Future<void> _init() async {
    final key = await _aiService.getApiKey();
    await loadConversations();
    state = state.copyWith(apiKey: key);
  }

  Future<void> loadConversations() async {
    try {
      final rawConvs = await _db.getAiConversations();
      final convs = rawConvs.map((m) => AiConversationModel.fromMap(m)).toList();

      if (convs.isEmpty) {
        // Create initial default conversation
        final newId = await _db.createAiConversation(
          title: 'નવી વાતચીત (New Chat)',
          modelUsed: state.selectedModel,
        );
        final defaultConv = AiConversationModel(
          id: newId,
          title: 'નવી વાતચીત (New Chat)',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          modelUsed: state.selectedModel,
        );
        final welcomeMsg = _buildWelcomeGreeting(newId);
        await _db.saveAiMessageRecord(welcomeMsg.toMap());

        state = state.copyWith(
          conversations: [defaultConv],
          activeConversationId: newId,
          messages: [welcomeMsg],
        );
      } else {
        final targetId = (state.activeConversationId != null &&
                convs.any((c) => c.id == state.activeConversationId))
            ? state.activeConversationId!
            : convs.first.id;

        state = state.copyWith(
          conversations: convs,
          activeConversationId: targetId,
        );
        await selectConversation(targetId);
      }
    } catch (e) {
      final welcome = _buildWelcomeGreeting('default');
      state = state.copyWith(messages: [welcome]);
    }
  }

  AiMessageModel _buildWelcomeGreeting(String convId) {
    return AiMessageModel(
      id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      sender: 'ai',
      text: '''
નમસ્તે! હું **ProgressAI** છું 🤖
હું ChatGPT, Google Gemini અને Web Search ની શક્તિ સાથે સંપૂર્ણપણે જોડાયેલું AI Assistant છું!

તમે મને **ગુજરાતી, હિન્દી કે English** માં કંઈપણ પૂછી શકો છો:
• 🌐 *"આજના તાજા ટેક સમાચાર કે સોનાનો ભાવ જણાવો"* (Live Web Search)
• 🎨 *"સાયબરપંક શૈલીમાં ઉડતી કારની ઈમેજ જનરેટ કર"* (AI Image Generator)
• 📄 *"મારા Python લર્નિંગ પ્રોગ્રેસનો સુંદર PDF અથવા Word ડોક્યુમેન્ટ બનાવો"* (Doc Gen)
• 🚀 *"Flutter શીખવા 3 મહિનાનો વ્યવસ્થિત રોડમેપ બનાવી આપ"* (Roadmap Creator)
• ⏰ *"દરરોજ સવારે 6:30 વાગ્યાનો અભ્યાસ માટે એલાર્મ રાખી દે"* (Alarm Setter)
• 🧠 *"Python માં Decorators અને Multithreading સરળ રીતે સમજાવો"*

કહો, આજે આપણે શું નવું શીખીશું કે પ્લાન કરીશું? 😊
''',
      timestamp: DateTime.now(),
    );
  }

  Future<void> createNewChat() async {
    try {
      final newId = await _db.createAiConversation(
        title: 'નવી વાતચીત (New Chat)',
        modelUsed: state.selectedModel,
      );
      final newConv = AiConversationModel(
        id: newId,
        title: 'નવી વાતચીત (New Chat)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        modelUsed: state.selectedModel,
      );

      final welcomeMsg = _buildWelcomeGreeting(newId);
      await _db.saveAiMessageRecord(welcomeMsg.toMap());

      state = state.copyWith(
        conversations: [newConv, ...state.conversations],
        activeConversationId: newId,
        messages: [welcomeMsg],
        pendingAttachments: [],
      );
    } catch (_) {}
  }

  Future<void> selectConversation(String conversationId) async {
    try {
      final rawMsgs = await _db.getAiMessagesForConversation(conversationId);
      final msgs = rawMsgs.map((m) => AiMessageModel.fromMap(m)).toList();

      if (msgs.isEmpty) {
        final welcomeMsg = _buildWelcomeGreeting(conversationId);
        await _db.saveAiMessageRecord(welcomeMsg.toMap());
        state = state.copyWith(
          activeConversationId: conversationId,
          messages: [welcomeMsg],
          pendingAttachments: [],
        );
      } else {
        state = state.copyWith(
          activeConversationId: conversationId,
          messages: msgs,
          pendingAttachments: [],
        );
      }
    } catch (_) {
      state = state.copyWith(activeConversationId: conversationId);
    }
  }

  Future<void> renameConversation(String conversationId, String newTitle) async {
    if (newTitle.trim().isEmpty) return;
    await _db.updateAiConversationTitle(conversationId, newTitle.trim());
    final updated = state.conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(title: newTitle.trim(), updatedAt: DateTime.now());
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updated);
  }

  Future<void> togglePinConversation(String conversationId) async {
    final conv = state.conversations.firstWhere((c) => c.id == conversationId, orElse: () => state.conversations.first);
    final newPinned = !conv.isPinned;
    await _db.togglePinAiConversation(conversationId, newPinned);
    await loadConversations();
  }

  Future<void> deleteConversation(String conversationId) async {
    await _db.deleteAiConversation(conversationId);
    final remaining = state.conversations.where((c) => c.id != conversationId).toList();
    if (remaining.isEmpty) {
      await createNewChat();
    } else {
      state = state.copyWith(conversations: remaining);
      if (state.activeConversationId == conversationId) {
        await selectConversation(remaining.first.id);
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleWebSearch(bool enabled) {
    state = state.copyWith(isWebSearchEnabled: enabled);
  }

  void setSelectedModel(String model) {
    state = state.copyWith(selectedModel: model);
  }

  void addAttachment(MessageAttachmentModel attachment) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, attachment],
    );
  }

  void removeAttachment(int index) {
    if (index >= 0 && index < state.pendingAttachments.length) {
      final updated = List<MessageAttachmentModel>.from(state.pendingAttachments)..removeAt(index);
      state = state.copyWith(pendingAttachments: updated);
    }
  }

  void clearPendingAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  void stopGeneration() {
    _cancelled = true;
    state = state.copyWith(isGenerating: false, isLoading: false);
  }

  Future<void> rateMessage(String messageId, int rating) async {
    await _db.updateAiMessageRating(messageId, rating);
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(thumbsRating: rating);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> saveApiKey(String key) async {
    await _aiService.saveApiKey(key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty && state.pendingAttachments.isEmpty) return;

    // Ensure we have an active conversation
    String convId = state.activeConversationId ?? '';
    if (convId.isEmpty) {
      convId = await _db.createAiConversation(
        title: text.trim().isNotEmpty ? text.trim().split('\n').first : 'નવી વાતચીત',
        modelUsed: state.selectedModel,
      );
      state = state.copyWith(activeConversationId: convId);
    }

    final userAttachments = List<MessageAttachmentModel>.from(state.pendingAttachments);
    final userMsg = AiMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      sender: 'user',
      text: text.trim(),
      attachments: userAttachments,
      timestamp: DateTime.now(),
    );

    // Auto-update conversation title if it's the first real question and title is default
    final currentConv = state.activeConversation;
    if (currentConv != null &&
        (currentConv.title.contains('New Chat') || currentConv.title.contains('નવી વાતચીત')) &&
        text.trim().isNotEmpty) {
      String cleanTitle = text.trim().replaceAll('\n', ' ');
      if (cleanTitle.length > 30) {
        cleanTitle = '${cleanTitle.substring(0, 30)}...';
      }
      renameConversation(convId, cleanTitle);
    }

    // Persist user message to DB
    await _db.saveAiMessageRecord(userMsg.toMap());

    _cancelled = false;
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      pendingAttachments: [],
      isLoading: true,
      isGenerating: true,
    );

    try {
      final aiResponse = await _aiService.processPrompt(
        prompt: text.trim(),
        conversationHistory: state.messages,
        attachments: userAttachments,
        enableSearch: state.isWebSearchEnabled,
      );

      if (_cancelled) {
        state = state.copyWith(isLoading: false, isGenerating: false);
        return;
      }

      final aiMsg = AiMessageModel(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: convId,
        sender: 'ai',
        text: aiResponse.text,
        actionType: aiResponse.actionType,
        actionTitle: aiResponse.actionTitle,
        actionDetails: aiResponse.actionDetails,
        actionData: aiResponse.actionData,
        sources: aiResponse.sources,
        imageUrl: aiResponse.imageUrl,
        generatedFilePath: aiResponse.generatedFilePath,
        generatedFileName: aiResponse.generatedFileName,
        timestamp: DateTime.now(),
      );

      // Persist AI message to DB
      await _db.saveAiMessageRecord(aiMsg.toMap());

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
        isGenerating: false,
      );

      // Refresh app providers if an action was executed
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
      if (_cancelled) return;
      final errorMsg = AiMessageModel(
        id: 'msg_err_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: convId,
        sender: 'ai',
        text: 'માફ કરશો, પ્રોસેસિંગમાં કોઈ સમસ્યા આવી: $e',
        timestamp: DateTime.now(),
      );
      await _db.saveAiMessageRecord(errorMsg.toMap());
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        isGenerating: false,
      );
    }
  }

  Future<void> regenerateLastResponse() async {
    if (state.messages.isEmpty || state.isLoading) return;

    // Find the last user message
    final lastUserIndex = state.messages.lastIndexWhere((m) => m.isUser);
    if (lastUserIndex == -1) return;

    final userMessage = state.messages[lastUserIndex];

    // Remove any AI messages after that user message from state and DB
    final msgsToKeep = state.messages.sublist(0, lastUserIndex);
    final msgsToDelete = state.messages.sublist(lastUserIndex + 1);

    for (final m in msgsToDelete) {
      await _db.deleteAiMessage(m.id);
    }

    state = state.copyWith(
      messages: msgsToKeep,
      pendingAttachments: userMessage.attachments,
    );

    await sendMessage(userMessage.text);
  }

  Future<void> editMessage(String messageId, String newText) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    // Remove messages from idx onwards
    final msgsToDelete = state.messages.sublist(idx);
    for (final m in msgsToDelete) {
      await _db.deleteAiMessage(m.id);
    }

    final remaining = state.messages.sublist(0, idx);
    state = state.copyWith(messages: remaining);

    await sendMessage(newText);
  }

  void clearHistory() {
    if (state.activeConversationId != null) {
      deleteConversation(state.activeConversationId!);
    }
  }
}
