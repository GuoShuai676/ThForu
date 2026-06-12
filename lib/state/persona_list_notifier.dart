import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/persona.dart';

class PersonaListNotifier extends StateNotifier<List<Persona>> {
  PersonaListNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('personas');
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Persona.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'personas', jsonEncode(state.map((p) => p.toJson()).toList()));
  }

  Future<void> add(Persona persona) async {
    state = [...state, persona];
    await _save();
  }

  Future<void> update(Persona persona) async {
    state = state.map((p) => p.id == persona.id ? persona : p).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }
}
