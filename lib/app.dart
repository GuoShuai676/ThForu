import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/conversations_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/favorites_screen.dart';
import 'state/providers.dart';

class AIApp extends ConsumerWidget {
  const AIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final seed = themeSettings.seedColor;

    return MaterialApp(
      title: 'ThForu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const ConversationsScreen(),
            );
          case '/chat':
            final convId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ChatScreen(conversationId: convId),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            );
          case '/favorites':
            return MaterialPageRoute(
              builder: (_) => const FavoritesScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const ConversationsScreen(),
            );
        }
      },
    );
  }
}
