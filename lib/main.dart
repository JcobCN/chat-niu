import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/chat_controller.dart';
import 'screens/chat_screen.dart';
import 'services/chat_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(ChatNiuApp(settings: settings));
}

class ChatNiuApp extends StatelessWidget {
  const ChatNiuApp({super.key, required this.settings});

  final ChatSettings settings;

  ThemeMode _themeModeFromIndex(int index) {
    switch (index) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF10A37F);
    return ChangeNotifierProvider(
      create: (_) => ChatController(settings: settings),
      child: MaterialApp(
        title: 'Chat Niu',
        debugShowCheckedModeBanner: false,
        themeMode: _themeModeFromIndex(settings.themeMode),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF8F9FA),
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF14171A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF14171A),
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E2328),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
