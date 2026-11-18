import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ai/ai_service.dart';
import '../../providers/groups_provider.dart';

class AiRoadmapGeneratorDialog extends ConsumerStatefulWidget {
  const AiRoadmapGeneratorDialog({super.key});

  @override
  ConsumerState<AiRoadmapGeneratorDialog> createState() => _AiRoadmapGeneratorDialogState();
}

class _AiRoadmapGeneratorDialogState extends ConsumerState<AiRoadmapGeneratorDialog> {
  final _goalController = TextEditingController();
  String _selectedDuration = '3 Months';
  bool _isGenerating = false;
  String? _statusText;

  final List<String> _durationOptions = ['1 Month', '3 Months', '6 Months', '1 Year'];

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _generateRoadmap() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _statusText = 'ProgressAI તમારા માટે સંપૂર્ણ રોડમેપ બનાવી રહ્યું છે...';
    });

    try {
      final prompt = 'નવો રોડમેપ બનાવ: $goal (Duration: $_selectedDuration). આના માટે વિગતવાર સેક્શન્સ અને ટોપિક્સ બનાવો.';
      final response = await AiService.instance.processPrompt(
        prompt: prompt,
        conversationHistory: [],
      );

      ref.read(groupsProvider.notifier).loadGroups();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.actionDetails ?? 'નવો ગોલ રોડમેપ સફળતાપૂર્વક બની ગયો!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusText = 'એરર આવી: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Text('AI Roadmap Generator'),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'તમારે જે શીખવું હોય કે ગોલ બનાવવો હોય તે લખો. AI આપોઆપ તમામ મહિનાઓ, સેક્શન્સ અને ટોપિક્સ જનરેટ કરી દેશે:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                labelText: 'ગોલ અથવા વિષયનું નામ *',
                hintText: 'દા.ત. Flutter Developer, Gym & Fitness, English',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('સમયગાળો (Duration):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: _selectedDuration,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDuration = val);
                  },
                  items: _durationOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                ),
              ],
            ),
            if (_statusText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_statusText!, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(_isGenerating ? 'બનાવી રહ્યું છે...' : 'Generate with AI'),
          onPressed: _isGenerating ? null : _generateRoadmap,
        ),
      ],
    );
  }
}
