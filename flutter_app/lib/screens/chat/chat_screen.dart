import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/planner_provider.dart';
import '../../services/api_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _stt = SpeechToText();

  bool _sttAvailable = false;
  bool _listening = false;
  String? _commandFeedback;   // brief status after a voice command executes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadHistory();
      _initStt();
    });
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (_) => setState(() => _listening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _stt.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _scrollToBottom();
    final actions = await ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
    if (actions.isNotEmpty && mounted) {
      _onActionsPerformed(actions);
    }
  }

  void _onActionsPerformed(List<String> actions) {
    // Invalidate shared providers so other screens refresh on next visit.
    ref.invalidate(habitsTodayProvider);
    ref.invalidate(habitsStatsProvider(30));
    ref.invalidate(tasksTodayProvider);
    ref.invalidate(dashboardTodayProvider);
    ref.invalidate(plannerDayProvider(DateTime.now().toIso8601String().substring(0, 10)));
    ref.invalidate(plannerWeekProvider(DateTime.now().toIso8601String().substring(0, 10)));

    // Show a brief confirmation banner.
    setState(() => _commandFeedback = actions.first);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _commandFeedback = null);
    });
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_sttAvailable || _listening) return;
    setState(() { _listening = true; _commandFeedback = null; });
    await _stt.listen(
      localeId: 'de_DE',   // German first; falls back to device default if unavailable
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        if (result.finalResult) {
          _onVoiceResult(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _listening = false);
  }

  Future<void> _onVoiceResult(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { _listening = false; _commandFeedback = 'Processing: "$text"'; });

    try {
      final result = await ApiService().parseCommand(text);
      final action = result['action'] as String? ?? 'unknown';

      if (action == 'unknown') {
        // Fall through to chat
        _controller.text = text;
        await _send();
        if (mounted) setState(() => _commandFeedback = null);
        return;
      }

      final feedback = await _executeCommand(result);
      if (mounted) {
        _onActionsPerformed([feedback]);
      }
    } catch (e) {
      if (mounted) setState(() => _commandFeedback = 'Error: $e');
    }
  }

  Future<String> _executeCommand(Map<String, dynamic> cmd) async {
    final action = cmd['action'] as String;
    switch (action) {
      case 'add_list_item':
        final listName = (cmd['list_name'] as String? ?? 'shopping').toLowerCase();
        final item = cmd['item'] as String? ?? '';
        if (item.isEmpty) return 'Could not understand the item name.';

        // Find or create the list
        final lists = await ApiService().getLists();
        Map<String, dynamic>? target;
        for (final l in lists) {
          final m = l as Map<String, dynamic>;
          if ((m['name'] as String).toLowerCase().contains(listName) ||
              listName.contains((m['name'] as String).toLowerCase())) {
            target = m;
            break;
          }
        }
        if (target == null) {
          // Create a new list with a matching name
          final icon = _iconForList(listName);
          target = await ApiService().createList({'name': _capitalize(listName), 'icon': icon});
        }
        await ApiService().addListItem(target['id'] as String, item);
        return 'Added "$item" to ${target['name']}';

      case 'add_task':
        final title = cmd['title'] as String? ?? '';
        if (title.isEmpty) return 'Could not understand the task title.';
        await ApiService().createTask({
          'title': title,
          if (cmd['due_date'] != null) 'due_date': cmd['due_date'],
          if (cmd['due_time'] != null) 'due_time': cmd['due_time'],
          'priority': cmd['priority'] ?? 'medium',
        });
        return 'Task added: "$title"';

      case 'add_event':
        final title = cmd['title'] as String? ?? '';
        if (title.isEmpty) return 'Could not understand the event title.';
        await ApiService().createEvent({
          'title': title,
          'date': cmd['date'],
          if (cmd['start_time'] != null) 'start_time': cmd['start_time'],
          if (cmd['end_time'] != null) 'end_time': cmd['end_time'],
          'color': '#4F6EF7',
        });
        return 'Event added: "$title"';

      case 'log_habit':
        final name = (cmd['name'] as String? ?? '').toLowerCase();
        if (name.isEmpty) return 'Could not understand the habit name.';
        final habits = await ApiService().getHabitsToday();
        Map<String, dynamic>? match;
        for (final h in habits) {
          final m = h as Map<String, dynamic>;
          if ((m['name'] as String).toLowerCase().contains(name) ||
              name.contains((m['name'] as String).toLowerCase())) {
            match = m;
            break;
          }
        }
        if (match == null) return 'No habit found matching "$name"';
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await ApiService().logHabit(match['id'] as String, {'completed': 1, 'date': dateStr});
        return 'Logged habit: "${match['name']}"';

      default:
        return 'Command not recognized — try typing it instead.';
    }
  }

  String _iconForList(String name) {
    if (name.contains('shop') || name.contains('grocery') || name.contains('einkauf')) return '🛒';
    if (name.contains('watch') || name.contains('movie') || name.contains('film')) return '🎬';
    if (name.contains('birthday') || name.contains('geburtstag') || name.contains('gift')) return '🎁';
    if (name.contains('christmas') || name.contains('weihnacht')) return '🎄';
    if (name.contains('pack') || name.contains('travel') || name.contains('reise')) return '🧳';
    if (name.contains('read') || name.contains('buch') || name.contains('book')) return '📚';
    return '📋';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: const Color(0xFF0F1117),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1D27),
                  title: const Text('Clear chat history?', style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(chatProvider.notifier).clearHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Command feedback banner
          if (_commandFeedback != null)
            Container(
              width: double.infinity,
              color: const Color(0xFF1A3A2A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF27AE60), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_commandFeedback!,
                        style: const TextStyle(color: Color(0xFF27AE60), fontSize: 13)),
                  ),
                ],
              ),
            ),

          // Listening indicator
          if (_listening)
            Container(
              width: double.infinity,
              color: const Color(0xFF1A1D27),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _PulseDot(),
                  const SizedBox(width: 10),
                  const Text('Listening... speak now',
                      style: TextStyle(color: Color(0xFF4F6EF7), fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _stopListening,
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: chatState.messages[i]),
                  ),
          ),
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF4F6EF7)),
                  ),
                  SizedBox(width: 8),
                  Text('Thinking...',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          if (chatState.error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade900.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(chatState.error!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
            ),
          Container(
            color: const Color(0xFF1A1D27),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Mic button
                  if (_sttAvailable)
                    GestureDetector(
                      onTap: _listening ? _stopListening : _startListening,
                      child: Container(
                        width: 42,
                        height: 42,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _listening
                              ? const Color(0xFF4F6EF7)
                              : const Color(0xFF252836),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _listening ? Icons.stop : Icons.mic_none,
                          color: _listening ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      enabled: !chatState.isLoading,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _sttAvailable
                            ? 'Ask or say a command...'
                            : 'Ask about your health, tasks, habits...',
                        hintStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F1117),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: chatState.isLoading ? null : _send,
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF4F6EF7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulse animation for listening indicator ───────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF4F6EF7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isUser ? const Color(0xFF4F6EF7) : const Color(0xFF1A1D27),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4),
              )
            : MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFFB0B8CC)),
                  h2: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  h3: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  listBullet: const TextStyle(
                      fontSize: 14, color: Color(0xFFB0B8CC)),
                  code: const TextStyle(
                      fontSize: 12,
                      backgroundColor: Color(0xFF0F1117),
                      color: Color(0xFF9DBBFF)),
                  blockquote: const TextStyle(
                      fontSize: 13, color: Colors.grey),
                ),
              ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Ask me anything',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Or use the mic to say a command:\n"Add eggs to shopping" · "I just meditated"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _SuggestionChip(text: 'How did I sleep this week?'),
          const SizedBox(height: 8),
          _SuggestionChip(text: 'What tasks are overdue?'),
          const SizedBox(height: 8),
          _SuggestionChip(text: 'How are my habits going?'),
        ],
      ),
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(chatProvider.notifier).sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFF4F6EF7).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style:
                const TextStyle(color: Color(0xFF4F6EF7), fontSize: 13)),
      ),
    );
  }
}
