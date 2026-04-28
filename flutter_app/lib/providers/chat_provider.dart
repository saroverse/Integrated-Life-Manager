import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  String? _sessionId;

  Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('chat_session_id');
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
      await prefs.setString('chat_session_id', _sessionId!);
    }
    return _sessionId!;
  }

  Future<void> loadHistory() async {
    final sessionId = await _getSessionId();
    try {
      final result = await ApiService().getChatHistory(sessionId: sessionId);
      final msgs = (result['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: msgs, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Sends a message and returns the list of actions the AI performed (if any).
  Future<List<String>> sendMessage(String text) async {
    if (text.trim().isEmpty) return [];
    final sessionId = await _getSessionId();

    // Optimistic UI: add user message immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: tempId,
      sessionId: sessionId,
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, tempMsg],
      isLoading: true,
      error: null,
    );

    try {
      final response = await ApiService().sendChatMessage(
          message: text.trim(), sessionId: sessionId);
      // Reload full history to get confirmed IDs and assistant response
      await loadHistory();
      final actions = (response['actions_taken'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      return actions;
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != tempId).toList(),
        isLoading: false,
        error: 'Failed to send message. Is the backend running?',
      );
      return [];
    }
  }

  Future<void> clearHistory() async {
    final sessionId = await _getSessionId();
    try {
      await ApiService().clearChatHistory(sessionId);
    } catch (_) {}
    // Start a new session regardless
    final prefs = await SharedPreferences.getInstance();
    _sessionId = const Uuid().v4();
    await prefs.setString('chat_session_id', _sessionId!);
    state = const ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
