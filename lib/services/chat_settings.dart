import 'package:shared_preferences/shared_preferences.dart';

class ChatSettings {
  const ChatSettings({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.themeMode = 0,
    this.systemPrompt = '',
  });

  static const themeNames = ['跟随系统', '浅色', '深色'];

  final String baseUrl;
  final String apiKey;
  final String model;
  final int themeMode;
  final String systemPrompt;

  ChatSettings copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    int? themeMode,
    String? systemPrompt,
  }) {
    return ChatSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      themeMode: themeMode ?? this.themeMode,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

class SettingsStore {
  static const _baseUrlKey = 'chat.baseUrl';
  static const _apiKeyKey = 'chat.apiKey';
  static const _modelKey = 'chat.model';
  static const _themeModeKey = 'chat.themeMode';
  static const _systemPromptKey = 'chat.systemPrompt';

  static Future<ChatSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ChatSettings(
      baseUrl: preferences.getString(_baseUrlKey) ??
          const ChatSettings().baseUrl,
      apiKey: preferences.getString(_apiKeyKey) ?? '',
      model: preferences.getString(_modelKey) ?? const ChatSettings().model,
      themeMode: preferences.getInt(_themeModeKey) ?? 0,
      systemPrompt: preferences.getString(_systemPromptKey) ?? '',
    );
  }

  static Future<void> save(ChatSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, settings.baseUrl.trim());
    await preferences.setString(_apiKeyKey, settings.apiKey.trim());
    await preferences.setString(_modelKey, settings.model.trim());
    await preferences.setInt(_themeModeKey, settings.themeMode);
    await preferences.setString(_systemPromptKey, settings.systemPrompt.trim());
  }
}
