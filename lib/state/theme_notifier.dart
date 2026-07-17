import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  final Color seedColor;
  final ThemeMode themeMode;

  const ThemeSettings({
    this.seedColor = Colors.indigo,
    this.themeMode = ThemeMode.system,
  });

  ThemeSettings copyWith({Color? seedColor, ThemeMode? themeMode}) {
    return ThemeSettings(
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeSettings> {
  ThemeNotifier() : super(const ThemeSettings()) {
    _load();
  }

  static const _colorKey = 'theme_seed_color';
  static const _modeKey = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_colorKey);
    final modeIndex = prefs.getInt(_modeKey) ?? 0;
    final mode = ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)];
    state = ThemeSettings(
      seedColor: colorValue != null ? Color(colorValue) : Colors.indigo,
      themeMode: mode,
    );
  }

  Future<void> setSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.toARGB32());
    state = state.copyWith(seedColor: color);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }
}
