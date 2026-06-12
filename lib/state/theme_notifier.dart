import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  final Color seedColor;

  const ThemeSettings({
    this.seedColor = Colors.indigo,
  });

  ThemeSettings copyWith({Color? seedColor}) {
    return ThemeSettings(
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeSettings> {
  ThemeNotifier() : super(const ThemeSettings()) {
    _load();
  }

  static const _colorKey = 'theme_seed_color';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_colorKey);
    state = ThemeSettings(
      seedColor: colorValue != null ? Color(colorValue) : Colors.indigo,
    );
  }

  Future<void> setSeedColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.toARGB32());
    state = state.copyWith(seedColor: color);
  }
}
