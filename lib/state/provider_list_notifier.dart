import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/provider_config.dart';

class ProviderListNotifier extends StateNotifier<List<AIProviderConfig>> {
  ProviderListNotifier() : super([]) {
    _load();
  }

  static const _key = 'provider_configs';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) {
      state = [];
      return;
    }
    state = raw.map((s) => AIProviderConfig.fromJson(jsonDecode(s))).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = state.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  Future<void> add(AIProviderConfig config) async {
    state = [...state, config];
    await _save();
  }

  Future<void> update(AIProviderConfig config) async {
    state = state.map((p) => p.id == config.id ? config : p).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }
}
