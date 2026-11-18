import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ai_message_model.dart';
import '../../providers/ai_assistant_provider.dart';
import '../groups/groups_screen.dart';
import '../alarms/alarms_screen.dart';
import '../profile/profile_screen.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;

  const AiAssistantScreen({super.key, this.initialPrompt});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(aiAssistantProvider.notifier).sendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiAssistantProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ProgressAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Autonomous App Controller', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gemini API Key',
            icon: Icon(
              aiState.apiKey != null && aiState.apiKey!.isNotEmpty ? Icons.key_rounded : Icons.key_off_rounded,
              color: aiState.apiKey != null && aiState.apiKey!.isNotEmpty ? const Color(0xFF10B981) : Colors.grey,
            ),
            onPressed: () => _showApiKeyDialog(context, ref, aiState.apiKey),
          ),
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => ref.read(aiAssistantProvider.notifier).clearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: aiState.messages.length,
              itemBuilder: (ctx, idx) {
                final msg = aiState.messages[idx];
                return _buildMessageBubble(context, msg);
              },
            ),
          ),

          if (aiState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('ProgressAI વિચાર કરી રહ્યું છે અને એક્શન લઈ રહ્યું છે...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // Quick Prompt Chips
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildPromptChip('🚀 નવો ગોલ: Flutter 3 Months'),
                _buildPromptChip('🏋️ નવો ગોલ: Gym & Fitness'),
                _buildPromptChip('⏰ સવારે 6 વાગ્યાનો એલાર્મ રાખ'),
                _buildPromptChip('✅ ટોપિક Completed માર્ક કર'),
                _buildPromptChip('📊 મારો પ્રોગ્રેસ બતાવ'),
                _buildPromptChip('🧠 Python Async સમજાવો'),
              ],
            ),
          ),

          // Input field and send button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _inputController,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'ગુજરાતી, હિન્દી કે English માં કહો...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          if (!aiState.isLoading) {
                            _sendCurrentText();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: aiState.isLoading ? null : _sendCurrentText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendCurrentText() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _inputController.clear();
      ref.read(aiAssistantProvider.notifier).sendMessage(text);
      _scrollToBottom();
    }
  }

  Widget _buildPromptChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          ref.read(aiAssistantProvider.notifier).sendMessage(label);
          _scrollToBottom();
        },
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, AiMessageModel msg) {
    final theme = Theme.of(context);
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF10B981)
                    : theme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),

                  // Action Execution Card (if AI performed an app action!)
                  if (msg.hasAction) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.task_alt_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  msg.actionTitle ?? 'App Action Executed',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (msg.actionDetails != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              msg.actionDetails!,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: const Color(0xFF10B981),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                label: const Text('Open & View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  if (msg.actionType?.contains('group') == true) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen()));
                                  } else if (msg.actionType?.contains('alarm') == true) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmsScreen()));
                                  } else if (msg.actionType?.contains('profile') == true) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, String? currentKey) {
    final keyCtrl = TextEditingController(text: currentKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Google Gemini API Key'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'સંપૂર્ણ ChatGPT / Gemini જેવી લાઇવ ઇન્ટેલિજન્સ અને બધી જગ્યાએ સર્ચ કરવા માટે તમારી ફ્રી Google Gemini API Key અહીં નાખો:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key (Optional)',
                hintText: 'AIzaSy...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Key વગર પણ ઍપનું સ્માર્ટ લોકલ AI કામ કરે છે!\n• ફ્રી કી લેવા માટે aistudio.google.com પર જઈ શકો છો.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(aiAssistantProvider.notifier).saveApiKey(keyCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }
}
