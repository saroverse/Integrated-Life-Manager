class ChatMessage {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final String? modelUsed;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.modelUsed,
    required this.timestamp,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      modelUsed: json['model_used'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
