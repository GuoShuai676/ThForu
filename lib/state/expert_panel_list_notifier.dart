import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/storage.dart';
import '../models/expert_panel.dart';

class ExpertPanelListNotifier extends StateNotifier<List<ExpertPanel>> {
  ExpertPanelListNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final storage = await Storage.instance;
    final raw = storage.getAllExpertPanels();
    state = raw.map((m) => ExpertPanel.fromJson(m)).toList();
  }

  Future<void> _save() async {
    final storage = await Storage.instance;
    final raw = state.map((p) => p.toJson()).toList();
    await storage.saveAllExpertPanels(raw);
  }

  Future<void> add(ExpertPanel panel) async {
    state = [...state, panel];
    await _save();
  }

  Future<void> update(ExpertPanel panel) async {
    state = state.map((p) => p.id == panel.id ? panel : p).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }
}
