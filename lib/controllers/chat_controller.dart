import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/chat_api.dart';
import '../services/chat_settings.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this._settings,
    ChatApi? api,
  }) : _api = api ?? ChatApi();

  final ChatApi _api;
  final List<ChatMessage> _messages = [];
  ChatSettings _settings;
  bool _isBusy = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatSettings get settings => _settings;
  bool get isBusy => _isBusy;

  Future<void> updateSettings(ChatSettings settings) async {
    _settings = settings;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isBusy) return;

    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: prompt,
      createdAt: DateTime.now(),
    );
    final conversation = [
      ..._messages.where((message) => !message.isError && message.content.isNotEmpty),
      userMessage,
    ];
    final assistantId = '${userMessage.id}-assistant';

    _messages
      ..add(userMessage)
      ..add(ChatMessage(
        id: assistantId,
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        isStreaming: true,
      ));
    _isBusy = true;
    notifyListeners();

    try {
      await _api.streamReply(
        settings: _settings,
        messages: conversation,
        onDelta: (delta) {
          final index = _messages.indexWhere((message) => message.id == assistantId);
          if (index == -1) return;
          _messages[index] = _messages[index].copyWith(
            content: '${_messages[index].content}$delta',
          );
          notifyListeners();
        },
      );
    } catch (error) {
      final index = _messages.indexWhere((message) => message.id == assistantId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: '抱歉，回复失败了。\n\n$error',
          isError: true,
        );
      }
    } finally {
      final index = _messages.indexWhere((message) => message.id == assistantId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isStreaming: false);
      }
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    if (_isBusy) return;
    _messages.clear();
    notifyListeners();
  }
}
