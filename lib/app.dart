import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/providers.dart';
import 'screens/main_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/favorites_screen.dart';

class AIApp extends ConsumerWidget {
  const AIApp({super.key});

  static const _seedColor = Color(0xFF2196F3);

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: brightness,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF8F9FA)
          : const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFF8F9FA)
            : const Color(0xFF121212),
        foregroundColor: brightness == Brightness.light
            ? const Color(0xFF1A1A1A)
            : null,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFF8F9FA)
            : const Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: brightness == Brightness.light ? const Color(0xFF2196F3) : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);

    return MaterialApp(
      title: 'ThForu',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: _buildTheme(themeSettings.seedColor, Brightness.light),
      darkTheme: _buildTheme(themeSettings.seedColor, Brightness.dark),
      themeMode: themeSettings.themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const MainScreen(),
            );
          case '/chat':
            final args = settings.arguments;
            if (args is Map) {
              final convId = args['conversationId'] as String? ?? '';
              final msgId = args['messageId'] as String?;
              return MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: convId, scrollToMessageId: msgId),
              );
            } else if (args is String) {
              return MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const MainScreen(),
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
              builder: (_) => const MainScreen(),
            );
        }
      },
    );
  }
}
