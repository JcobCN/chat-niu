import 'package:shared_preferences/shared_preferences.dart';

class ChatSettings {
  const ChatSettings({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  ChatSettings copyWith({String? baseUrl, String? apiKey, String? model}) {
    return ChatSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

class SettingsStore {
  static const _baseUrlKey = 'chat.baseUrl';
  static const _apiKeyKey = 'chat.apiKey';
  static const _modelKey = 'chat.model';

  static Future<ChatSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ChatSettings(
      baseUrl: preferences.getString(_baseUrlKey) ??
          const ChatSettings().baseUrl,
      apiKey: preferences.getString(_apiKeyKey) ?? '',
      model: preferences.getString(_modelKey) ?? const ChatSettings().model,
    );
  }

  static Future<void> save(ChatSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, settings.baseUrl.trim());
    await preferences.setString(_apiKeyKey, settings.apiKey.trim());
    await preferences.setString(_modelKey, settings.model.trim());
  }
}
