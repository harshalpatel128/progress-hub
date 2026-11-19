import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import '../../models/ai_message_model.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../core/database/database_service.dart';
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
      drawer: _buildHistoryDrawer(context, ref, aiState),
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Chat History',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    aiState.activeConversation?.title ?? 'ProgressAI',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          aiState.isWebSearchEnabled ? 'Live Web Connected' : 'ChatGPT & Gemini Mode',
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Web Search Grounding Toggle
          IconButton(
            tooltip: aiState.isWebSearchEnabled ? 'Web Search: Active' : 'Web Search: Off',
            icon: Icon(
              Icons.travel_explore_rounded,
              color: aiState.isWebSearchEnabled ? const Color(0xFF10B981) : Colors.grey,
            ),
            onPressed: () {
              ref.read(aiAssistantProvider.notifier).toggleWebSearch(!aiState.isWebSearchEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(aiState.isWebSearchEnabled ? 'Web Search બંધ કર્યું' : 'Web Search ચાલુ કર્યું (Google Grounding)'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // New Chat Button
          IconButton(
            tooltip: 'New Chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => ref.read(aiAssistantProvider.notifier).createNewChat(),
          ),

          // More Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'memory') {
                _showAiMemoryDialog(context);
              } else if (val == 'key') {
                _showApiKeyDialog(context, ref, aiState.apiKey);
              } else if (val == 'clear') {
                ref.read(aiAssistantProvider.notifier).clearHistory();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'memory',
                child: Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text('AI Brain & Memory'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'key',
                child: Row(
                  children: [
                    Icon(
                      aiState.apiKey != null && aiState.apiKey!.isNotEmpty ? Icons.key_rounded : Icons.key_off_rounded,
                      color: aiState.apiKey != null && aiState.apiKey!.isNotEmpty ? const Color(0xFF10B981) : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Gemini API Key'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Conversation', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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
                final isLastAi = msg.isAi && idx == aiState.messages.length - 1;
                return _buildMessageBubble(context, ref, msg, isLastAi);
              },
            ),
          ),

          // Loading / Generating Indicator with Stop button
          if (aiState.isLoading || aiState.isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ProgressAI વિચાર કરી રહ્યું છે, સર્ચ અને એક્શન લઈ રહ્યું છે...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.stop_circle_rounded, size: 16),
                    label: const Text('Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.read(aiAssistantProvider.notifier).stopGeneration();
                    },
                  ),
                ],
              ),
            ),

          // Pending attachments preview in composer
          if (aiState.pendingAttachments.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: aiState.pendingAttachments.length,
                itemBuilder: (ctx, idx) {
                  final att = aiState.pendingAttachments[idx];
                  return Container(
                    margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          att.type == 'image' ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                          size: 14,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            att.name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => ref.read(aiAssistantProvider.notifier).removeAttachment(idx),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Quick Prompt Chips
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildPromptChip('🌐 આજના તાજા સમાચાર'),
                _buildPromptChip('🎨 સાયબરપંક કારની ઈમેજ બનાવો'),
                _buildPromptChip('📄 મારા પ્રોગ્રેસનો PDF રિપોર્ટ બનાવો'),
                _buildPromptChip('🚀 Flutter નો 3 મહિનાનો રોડમેપ'),
                _buildPromptChip('⏰ સવારે 6:30 વાગ્યાનો એલાર્મ રાખો'),
                _buildPromptChip('🧠 Python Decorators સરળ રીતે સમજાવો'),
              ],
            ),
          ),

          // Input field and send button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    tooltip: 'Attach Image / Document',
                    icon: const Icon(Icons.attach_file_rounded, color: Colors.grey, size: 22),
                    onPressed: () => _pickAttachment(context, ref),
                  ),

                  // Text input
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
                          hintText: 'ગુજરાતી, હિન્દી કે English માં કંઈપણ પૂછો...',
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

                  // Send button
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
    final hasAttachments = ref.read(aiAssistantProvider).pendingAttachments.isNotEmpty;
    if (text.isNotEmpty || hasAttachments) {
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

  Widget _buildMessageBubble(BuildContext context, WidgetRef ref, AiMessageModel msg, bool isLastAi) {
    final theme = Theme.of(context);
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  // User attachments chips (if any)
                  if (msg.attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.attachments.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                a.type == 'image' ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Formatted text & code blocks
                  ..._renderFormattedText(context, msg.text, isUser),

                  // AI Generated Image Card
                  if (msg.hasImage)
                    _buildGeneratedImage(context, msg.imageUrl!),

                  // AI Generated Document Card (PDF, DOCX, XLSX, PPTX, CSV)
                  if (msg.hasGeneratedFile)
                    _buildGeneratedDocument(context, msg.generatedFilePath!, msg.generatedFileName),

                  // Web Search Sources (Google Search Grounding citations)
                  if (msg.hasSources)
                    _buildWebSources(context, msg.sources),

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

                  // Message Action Bar (Copy, Share, Edit, Regenerate, Thumbs)
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy Text
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ટેક્સ્ટ કોપી થઈ ગયું!'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.copy_rounded, size: 14, color: isUser ? Colors.white70 : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Share
                      InkWell(
                        onTap: () {
                          Share.share(msg.text);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.share_outlined, size: 14, color: isUser ? Colors.white70 : Colors.grey),
                        ),
                      ),

                      if (isUser) ...[
                        const SizedBox(width: 8),
                        // Edit prompt
                        InkWell(
                          onTap: () => _showEditMessageDialog(context, ref, msg.id, msg.text),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                          ),
                        ),
                      ],

                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        // Thumbs up
                        InkWell(
                          onTap: () => ref.read(aiAssistantProvider.notifier).rateMessage(msg.id, 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(
                              msg.thumbsRating == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                              size: 14,
                              color: msg.thumbsRating == 1 ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Thumbs down
                        InkWell(
                          onTap: () => ref.read(aiAssistantProvider.notifier).rateMessage(msg.id, -1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(
                              msg.thumbsRating == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                              size: 14,
                              color: msg.thumbsRating == -1 ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                        ),

                        // Regenerate for last AI response
                        if (isLastAi) ...[
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () => ref.read(aiAssistantProvider.notifier).regenerateLastResponse(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text('Regenerate', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RICH MARKDOWN & CODE BLOCKS FORMATTING
  // -------------------------------------------------------------

  List<Widget> _renderFormattedText(BuildContext context, String text, bool isUser) {
    final theme = Theme.of(context);
    final textColor = isUser ? Colors.white : (theme.textTheme.bodyMedium?.color ?? Colors.white);

    if (!text.contains('```')) {
      return [_renderInlineMarkdown(text, textColor)];
    }

    final widgets = <Widget>[];
    final parts = text.split('```');
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i % 2 == 0) {
        if (part.trim().isNotEmpty) {
          widgets.add(_renderInlineMarkdown(part, textColor));
        }
      } else {
        final lines = part.split('\n');
        String lang = 'code';
        String code = part;
        if (lines.isNotEmpty && lines.first.trim().isNotEmpty && !lines.first.contains(' ')) {
          lang = lines.first.trim();
          code = lines.sublist(1).join('\n');
        }
        widgets.add(_buildCodeBlock(context, lang, code.trim()));
      }
    }
    return widgets;
  }

  Widget _renderInlineMarkdown(String text, Color textColor) {
    final lines = text.split('\n');
    final spans = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        spans.add(const SizedBox(height: 6));
        continue;
      }

      if (line.startsWith('### ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(4),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
          ),
        ));
        continue;
      } else if (line.startsWith('## ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            line.substring(3),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ));
        continue;
      } else if (line.startsWith('# ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            line.substring(2),
            style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: textColor),
          ),
        ));
        continue;
      }

      final isBullet = line.trim().startsWith('•') || line.trim().startsWith('* ') || line.trim().startsWith('- ');
      final cleanLine = isBullet ? line.trim().substring(2).trim() : line;
      final inlineSpans = _parseInlineSpans(cleanLine, textColor);

      if (isBullet) {
        spans.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
              Expanded(
                child: RichText(
                  text: TextSpan(children: inlineSpans),
                ),
              ),
            ],
          ),
        ));
      } else {
        spans.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(children: inlineSpans),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  List<InlineSpan> _parseInlineSpans(String text, Color defaultColor) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: defaultColor, fontSize: 13.5, height: 1.45),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: TextStyle(color: defaultColor, fontWeight: FontWeight.bold, fontSize: 13.5, height: 1.45),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              matchedText.substring(1, matchedText.length - 1),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
            ),
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: defaultColor, fontSize: 13.5, height: 1.45),
      ));
    }

    return spans;
  }

  Widget _buildCodeBlock(BuildContext context, String language, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard!'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // AI GENERATED IMAGE VIEW
  // -------------------------------------------------------------

  Widget _buildGeneratedImage(BuildContext context, String imagePathOrUrl) {
    final isLocal = File(imagePathOrUrl).existsSync();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () {
              _showFullScreenImage(context, imagePathOrUrl, isLocal);
            },
            child: Hero(
              tag: imagePathOrUrl,
              child: isLocal
                  ? Image.file(
                      File(imagePathOrUrl),
                      fit: BoxFit.cover,
                      height: 220,
                    )
                  : Image.network(
                      imagePathOrUrl,
                      fit: BoxFit.cover,
                      height: 220,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 220,
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF10B981)),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.black12,
                        child: const Center(child: Text('ઈમેજ લોડ કરવામાં ક્ષતિ આવી')),
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black.withOpacity(0.2),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                const Text('AI Generated Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Share Image',
                  onPressed: () {
                    if (isLocal) {
                      Share.shareXFiles([XFile(imagePathOrUrl)], text: 'ProgressAI Generated Image');
                    } else {
                      Share.share('Check out this AI Generated Image: $imagePathOrUrl');
                    }
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Fullscreen View',
                  onPressed: () => _showFullScreenImage(context, imagePathOrUrl, isLocal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String pathOrUrl, bool isLocal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () {
                  if (isLocal) {
                    Share.shareXFiles([XFile(pathOrUrl)]);
                  } else {
                    Share.share(pathOrUrl);
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: isLocal
                  ? Image.file(File(pathOrUrl))
                  : Image.network(pathOrUrl),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // AI GENERATED DOCUMENT VIEW (PDF, DOCX, XLSX, PPTX, CSV)
  // -------------------------------------------------------------

  Widget _buildGeneratedDocument(BuildContext context, String filePath, String? fileName) {
    final file = File(filePath);
    final name = fileName ?? file.uri.pathSegments.last;
    final ext = name.split('.').last.toLowerCase();

    Color badgeColor = const Color(0xFF10B981);
    IconData badgeIcon = Icons.insert_drive_file_rounded;

    if (ext == 'pdf') {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = Icons.picture_as_pdf_rounded;
    } else if (ext == 'docx') {
      badgeColor = const Color(0xFF2563EB);
      badgeIcon = Icons.description_rounded;
    } else if (ext == 'xlsx') {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.table_chart_rounded;
    } else if (ext == 'pptx') {
      badgeColor = const Color(0xFFF97316);
      badgeIcon = Icons.slideshow_rounded;
    } else if (ext == 'csv') {
      badgeColor = const Color(0xFF14B8A6);
      badgeIcon = Icons.grid_on_rounded;
    }

    int fileSize = 0;
    try {
      if (file.existsSync()) {
        fileSize = file.lengthSync();
      }
    } catch (_) {}

    final sizeString = fileSize > 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(1)} KB';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${ext.toUpperCase()} Document • $sizeString',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Share Document',
            icon: Icon(Icons.share_rounded, color: badgeColor, size: 20),
            onPressed: () {
              if (file.existsSync()) {
                Share.shareXFiles([XFile(filePath)], text: name);
              }
            },
          ),
          if (ext == 'pdf' && file.existsSync())
            IconButton(
              tooltip: 'Print / View PDF',
              icon: Icon(Icons.print_rounded, color: badgeColor, size: 20),
              onPressed: () async {
                try {
                  final bytes = await file.readAsBytes();
                  await Printing.layoutPdf(onLayout: (_) => bytes);
                } catch (_) {}
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // WEB SOURCES VIEW (GOOGLE SEARCH CITATIONS)
  // -------------------------------------------------------------

  Widget _buildWebSources(BuildContext context, List<WebSourceModel> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 14, color: Colors.blueAccent),
              SizedBox(width: 6),
              Text(
                'સોર્સ અને સંદર્ભ (Web Sources):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sources.map((s) {
              return InkWell(
                onTap: () {
                  _showSourceDetailsDialog(context, s);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public, size: 12, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showSourceDetailsDialog(BuildContext context, WebSourceModel source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.public_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(source.title, style: const TextStyle(fontSize: 14))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              source.url,
              style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
            ),
            if (source.snippet != null && source.snippet!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(source.snippet!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: source.url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied to clipboard!')),
              );
            },
            child: const Text('Copy Link'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CONVERSATION HISTORY DRAWER
  // -------------------------------------------------------------

  Widget _buildHistoryDrawer(BuildContext context, WidgetRef ref, AiChatState state) {
    final filtered = state.filteredConversations;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ProgressAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Chat History & Sessions', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('નવી વાતચીત (New Chat)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(aiAssistantProvider.notifier).createNewChat();
                },
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (val) => ref.read(aiAssistantProvider.notifier).setSearchQuery(val),
              ),
            ),

            const Divider(height: 1),

            // Conversation list
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No conversations found', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemBuilder: (ctx, idx) {
                        final conv = filtered[idx];
                        final isSelected = conv.id == state.activeConversationId;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF10B981).withOpacity(0.12),
                          leading: Icon(
                            conv.isPinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : (conv.isPinned ? Colors.amber : Colors.grey),
                          ),
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF10B981) : null,
                              fontSize: 13,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                            onSelected: (action) {
                              if (action == 'rename') {
                                _showRenameConversationDialog(context, ref, conv.id, conv.title);
                              } else if (action == 'pin') {
                                ref.read(aiAssistantProvider.notifier).togglePinConversation(conv.id);
                              } else if (action == 'delete') {
                                ref.read(aiAssistantProvider.notifier).deleteConversation(conv.id);
                              }
                            },
                            itemBuilder: (c) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Rename'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16),
                                    SizedBox(width: 8),
                                    Text(conv.isPinned ? 'Unpin' : 'Pin'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref.read(aiAssistantProvider.notifier).selectConversation(conv.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ATTACHMENT & EDIT DIALOGS
  // -------------------------------------------------------------

  Future<void> _pickAttachment(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx', 'pptx', 'csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final ext = (file.extension ?? '').toLowerCase();
          String fileType = 'file';
          if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
            fileType = 'image';
          } else if (ext == 'pdf') {
            fileType = 'pdf';
          } else if (ext == 'docx') {
            fileType = 'docx';
          } else if (ext == 'xlsx') {
            fileType = 'xlsx';
          } else if (ext == 'pptx') {
            fileType = 'pptx';
          } else if (ext == 'csv') {
            fileType = 'csv';
          } else if (ext == 'txt') {
            fileType = 'txt';
          }

          ref.read(aiAssistantProvider.notifier).addAttachment(
            MessageAttachmentModel(
              path: file.path!,
              name: file.name,
              type: fileType,
              sizeBytes: file.size,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _showEditMessageDialog(BuildContext context, WidgetRef ref, String msgId, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Edit your prompt...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(aiAssistantProvider.notifier).editMessage(msgId, ctrl.text.trim());
            },
            child: const Text('Save & Submit'),
          ),
        ],
      ),
    );
  }

  void _showRenameConversationDialog(BuildContext context, WidgetRef ref, String convId, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(aiAssistantProvider.notifier).renameConversation(convId, ctrl.text.trim());
            },
            child: const Text('Rename'),
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
              'ગૂગલના સૌથી પાવરફુલ અને રિયલ Gemini 1.5 Flash AI સાથે સીધું જોડાવા માટે તમારી ફ્રી API Key અહીં નાખો:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📌 ફ્રી કી મેળવવાની રીત (૧ મિનિટ):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF10B981))),
                  SizedBox(height: 4),
                  Text('1. બ્રાઉઝરમાં aistudio.google.com ખોલો\n2. "Get API key" પર ક્લિક કરો\n3. કી કોપી કરી નીચે પેસ્ટ કરો', style: TextStyle(fontSize: 11, height: 1.4)),
                  SizedBox(height: 4),
                  Text('💡 આ કી ૧૦૦% કાયમ માટે ફ્રી છે (દરરોજ ૧૫૦૦ પ્રશ્નો).', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Gemini API Key',
                hintText: 'AIzaSy...',
                isDense: true,
              ),
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

  void _showAiMemoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseService.instance.getAiMemories(),
        builder: (ctx, snapshot) {
          final memories = snapshot.data ?? [];
          final theme = Theme.of(context);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Brain & Learned Memory',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'વાતચીતમાંથી શીખેલી વિગતો અને આદતો',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (memories.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear Memory',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            await DatabaseService.instance.clearAiMemories();
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('AI મેમરી રીસેટ થઈ ગઈ છે.')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: memories.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 48, color: Colors.grey.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'AI હજી નવું શીખી રહ્યું છે!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'જેમ જેમ તમે ProgressAI સાથે ચેટ કરશો (તમારું નામ, પસંદગીઓ, ગોલ, સમય), તેમ તેમ AI આપોઆપ શીખીને પોતાની જાતને ટ્રેઇન કરશે અને બધું યાદ રાખશે.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: memories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final m = memories[idx];
                            final category = m['category'] as String? ?? 'general';
                            final key = m['key'] as String? ?? '';
                            final value = m['value'] as String? ?? '';
                            final times = (m['times_referenced'] as num?)?.toInt() ?? 1;

                            IconData catIcon = Icons.lightbulb_outline;
                            if (category == 'user_profile') catIcon = Icons.person_outline;
                            if (category == 'interest') catIcon = Icons.code_rounded;
                            if (category == 'lifestyle') catIcon = Icons.fitness_center_rounded;
                            if (category == 'habit') catIcon = Icons.schedule_rounded;
                            if (category == 'preference') catIcon = Icons.tune_rounded;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(catIcon, color: const Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              key.replaceAll('_', ' ').toUpperCase(),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981)),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text('Trained x$times', style: const TextStyle(fontSize: 9, color: Color(0xFF10B981))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
