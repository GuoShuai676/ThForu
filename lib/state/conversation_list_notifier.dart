import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../db/conversation_dao.dart';

class ConversationListNotifier extends StateNotifier<List<Conversation>> {
  final ConversationDao _dao;

  ConversationListNotifier(this._dao) : super([]) {
    load();
  }

  Future<void> load() async {
    try {
      state = await _dao.getAll();
    } catch (_) {
      state = [];
    }
  }

  Future<Conversation> create({
    required String providerConfigId,
    required String modelName,
    String? expertPanelId,
    String? personaId,
  }) async {
    final conv = Conversation(
      providerConfigId: providerConfigId,
      modelName: modelName,
      expertPanelId: expertPanelId,
      personaId: personaId,
    );
    await _dao.insert(conv);
    state = [conv, ...state];
    return conv;
  }

  Future<void> updateTitle(String id, String title) async {
    await _dao.updateTitle(id, title);
    state = state.map((c) => c.id == id ? (c..title = title) : c).toList();
  }

  Future<void> remove(String id) async {
    await _dao.delete(id);
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> setWallpaper(String id, String? path) async {
    final conv = state.firstWhere((c) => c.id == id);
    conv.wallpaperPath = path;
    conv.updatedAt = DateTime.now();
    await _dao.update(conv);
    state = state.map((c) => c.id == id ? conv : c).toList();
  }

  Future<void> togglePin(String id) async {
    final conv = state.firstWhere((c) => c.id == id);
    conv.isPinned = !conv.isPinned;
    conv.updatedAt = DateTime.now();
    await _dao.update(conv);
    state = state.map((c) => c.id == id ? conv : c).toList();
  }
}
