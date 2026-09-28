import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'chat_settings.dart';

class ChatApiException implements Exception {
  const ChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatApi {
  Future<void> streamReply({
    required ChatSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
  }) async {
    final apiKey = settings.apiKey.trim();
    if (apiKey.isEmpty) {
      throw const ChatApiException('请先在设置中填写 API Key。');
    }

    final baseUrl = settings.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(
      baseUrl.endsWith('/chat/completions')
          ? baseUrl
          : '$baseUrl/chat/completions',
    );
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const ChatApiException('API 地址无效，请使用 http:// 或 https:// 地址。');
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'model': settings.model.trim(),
          'stream': true,
          'messages': messages.map((message) => message.toApiJson()).toList(),
        });

      final response = await client.send(request).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw const ChatApiException('连接超时，请检查网络或 API 地址。'),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        final trimmedBody = body.trim();
        final detail = trimmedBody.isEmpty
            ? '服务返回 HTTP ${response.statusCode}'
            : trimmedBody.substring(
                0,
                trimmedBody.length > 500 ? 500 : trimmedBody.length,
              );
        throw ChatApiException('请求失败（${response.statusCode}）：$detail');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;

        try {
          final payload = jsonDecode(data) as Map<String, dynamic>;
          final choices = payload['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final delta = (choices.first as Map<String, dynamic>)['delta'];
          if (delta is! Map<String, dynamic>) continue;
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            onDelta(content);
          } else if (content is List) {
            for (final part in content) {
              if (part is Map<String, dynamic> && part['text'] is String) {
                onDelta(part['text'] as String);
              }
            }
          }
        } on FormatException {
          // Ignore malformed keep-alive or provider-specific SSE frames.
        } on TypeError {
          // Ignore frames that do not follow the OpenAI-compatible shape.
        }
      }
    } on ChatApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw ChatApiException('网络连接失败：${error.message}');
    } catch (error) {
      throw ChatApiException('聊天请求失败：$error');
    } finally {
      client.close();
    }
  }
}
