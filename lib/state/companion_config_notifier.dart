import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/companion_config.dart';

class CompanionConfigNotifier extends StateNotifier<CompanionConfig> {
  static const _key = 'companion_config_v2';

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

  // ---- Quick toggles ----

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _save();
  }

  Future<void> setSkin(CompanionSkin skin) async {
    state = state.copyWith(skin: skin);
    await _save();
  }

  Future<void> setSize(double v) async {
    state = state.copyWith(size: v.clamp(48, 120).toDouble());
    await _save();
  }

  // ---- Colors ----

  Future<void> setPrimaryColor(int c) async {
    state = state.copyWith(primaryColor: c);
    await _save();
  }

  Future<void> setAccentColor(int c) async {
    state = state.copyWith(accentColor: c);
    await _save();
  }

  Future<void> setSkinColor(int c) async {
    state = state.copyWith(skinColor: c);
    await _save();
  }

  Future<void> setHairColor(int c) async {
    state = state.copyWith(hairColor: c);
    await _save();
  }

  // ---- Appearance ----

  Future<void> setHair(CompanionHair h) async {
    state = state.copyWith(hair: h);
    await _save();
  }

  Future<void> setOutfit(CompanionOutfit o) async {
    state = state.copyWith(outfit: o);
    await _save();
  }

  Future<void> setAccessory(CompanionAccessory a) async {
    state = state.copyWith(accessory: a);
    await _save();
  }

  Future<void> setExpressionOverride(CompanionExpression? e) async {
    state = state.copyWith(
      expressionOverride: e,
      clearExpression: e == null,
    );
    await _save();
  }

  // ---- Character ----

  Future<void> setName(String name) async {
    state = state.copyWith(
        name: name.trim().isEmpty ? '韩立' : name.trim());
    await _save();
  }

  Future<void> setPersonality(CompanionPersonality p) async {
    state = state.copyWith(personality: p);
    await _save();
  }

  Future<void> setCatchphrases(List<String> phrases) async {
    state = state.copyWith(catchphrases: phrases);
    await _save();
  }

  Future<void> setCustomSystemPrompt(String prompt) async {
    state = state.copyWith(customSystemPrompt: prompt);
    await _save();
  }

  // ---- Behavior ----

  Future<void> setShowName(bool v) async {
    state = state.copyWith(showName: v);
    await _save();
  }

  Future<void> setAutoHide(bool v) async {
    state = state.copyWith(autoHide: v);
    await _save();
  }

  Future<void> setAutoHideSeconds(int v) async {
    state = state.copyWith(autoHideSeconds: v);
    await _save();
  }

  Future<void> setShowQuickMenu(bool v) async {
    state = state.copyWith(showQuickMenu: v);
    await _save();
  }

  // ---- Position ----

  Future<void> savePosition(double x, double y) async {
    state = state.copyWith(savedPositionX: x, savedPositionY: y);
    await _save();
  }

  Future<void> setDockToEdge(bool v) async {
    state = state.copyWith(dockToEdge: v);
    await _save();
  }

  // ---- Reset ----

  Future<void> resetHanLi() async {
    state = const CompanionConfig();
    await _save();
  }
}
