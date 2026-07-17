import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/companion_config.dart';

class CompanionConfigNotifier extends StateNotifier<CompanionConfig> {
  static const _key = 'companion_config_v1';

  CompanionConfigNotifier() : super(const CompanionConfig()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      state = CompanionConfig.decode(raw);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.encode());
  }

  Future<void> update(CompanionConfig config) async {
    state = config;
    await _save();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _save();
  }

  Future<void> setName(String name) async {
    state = state.copyWith(name: name.trim().isEmpty ? '韩立' : name.trim());
    await _save();
  }

  Future<void> setStyle(CompanionStyle style) async {
    state = state.copyWith(style: style);
    await _save();
  }

  Future<void> setPrimaryColor(int color) async {
    state = state.copyWith(primaryColor: color);
    await _save();
  }

  Future<void> setAccentColor(int color) async {
    state = state.copyWith(accentColor: color);
    await _save();
  }

  Future<void> setSize(double size) async {
    state = state.copyWith(size: size.clamp(56, 96).toDouble());
    await _save();
  }

  Future<void> setShowName(bool showName) async {
    state = state.copyWith(showName: showName);
    await _save();
  }

  Future<void> resetHanLi() => update(const CompanionConfig());
}
