import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skill.dart';

class SkillListNotifier extends StateNotifier<List<Skill>> {
  static const _key = 'skills';

  SkillListNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        state = list.map((m) => Skill.fromJson(m)).toList();
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(state.map((s) => s.toJson()).toList()));
  }

  Future<void> add(Skill skill) async {
    state = [skill, ...state];
    await _save();
  }

  Future<void> update(Skill skill) async {
    state = state.map((s) => s.id == skill.id ? skill : s).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  Future<void> toggleEnabled(String id) async {
    state = state.map((s) {
      if (s.id == id) return s.copyWith(enabled: !s.enabled);
      return s;
    }).toList();
    await _save();
  }
}
