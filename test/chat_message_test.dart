import 'package:flutter_test/flutter_test.dart';
import 'package:chat_niu/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('serializes user and assistant roles for the chat API', () {
      final message = ChatMessage(
        id: '1',
        role: ChatRole.user,
        content: 'Hello',
        createdAt: DateTime.utc(2025),
      );

      expect(message.toApiJson(), {'role': 'user', 'content': 'Hello'});
    });

    test('copyWith keeps identity and timestamp while updating content', () {
      final createdAt = DateTime.utc(2025);
      final message = ChatMessage(
        id: '1',
        role: ChatRole.assistant,
        content: 'Hi',
        createdAt: createdAt,
        isStreaming: true,
      );

      final updated = message.copyWith(content: 'Hello', isStreaming: false);

      expect(updated.id, message.id);
      expect(updated.createdAt, createdAt);
      expect(updated.content, 'Hello');
      expect(updated.isStreaming, isFalse);
    });
  });
}
