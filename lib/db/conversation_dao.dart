import 'storage.dart';
import '../models/conversation.dart';

class ConversationDao {
  Future<List<Conversation>> getAll() async {
    final storage = await Storage.instance;
    final maps = storage.getAllConversations();
    maps.sort((a, b) => (b['updated_at'] as int).compareTo(a['updated_at'] as int));
    return maps
        .map((m) {
          try { return Conversation.fromMap(m); } catch (_) { return null; }
        })
        .whereType<Conversation>()
        .toList();
  }

  Future<Conversation?> getById(String id) async {
    final storage = await Storage.instance;
    final map = storage.getConversation(id);
    if (map == null) return null;
    return Conversation.fromMap(map);
  }

  Future<void> insert(Conversation conv) async {
    final storage = await Storage.instance;
    await storage.insertConversation(conv.toMap());
  }

  Future<void> update(Conversation conv) async {
    final storage = await Storage.instance;
    await storage.updateConversation(conv.toMap());
  }

  Future<void> delete(String id) async {
    final storage = await Storage.instance;
    await storage.deleteConversation(id);
  }

  Future<void> updateTitle(String id, String title) async {
    final storage = await Storage.instance;
    final map = storage.getConversation(id);
    if (map != null) {
      map['title'] = title;
      map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      await storage.updateConversation(map);
    }
  }
}
