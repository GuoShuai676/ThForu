import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tool_settings.dart';

class ToolSettingsNotifier extends StateNotifier<ToolSettings> {
  static const _key = 'tool_settings';

  ToolSettingsNotifier() : super(const ToolSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      state = ToolSettings.decode(raw);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.encode());
  }

  Future<void> setToolsEnabled(bool v) async {
    state = state.copyWith(toolsEnabled: v);
    await _save();
  }

  Future<void> setTerminalEnabled(bool v) async {
    state = state.copyWith(terminalEnabled: v);
    await _save();
  }

  Future<void> setWebSearchEnabled(bool v) async {
    state = state.copyWith(webSearchEnabled: v);
    await _save();
  }

  Future<void> setMemoryEnabled(bool v) async {
    state = state.copyWith(memoryEnabled: v);
    await _save();
  }

  Future<void> setDatetimeEnabled(bool v) async {
    state = state.copyWith(datetimeEnabled: v);
    await _save();
  }

  Future<void> setTerminalPermission(String v) async {
    state = state.copyWith(terminalPermission: v);
    await _save();
  }

  Future<void> setWebSearchMaxResults(int v) async {
    state = state.copyWith(webSearchMaxResults: v);
    await _save();
  }
}
