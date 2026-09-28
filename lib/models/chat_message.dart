enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isStreaming;
  final bool isError;

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
    );
  }

  Map<String, String> toApiJson() => {
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
