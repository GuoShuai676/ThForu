import 'storage.dart';
import '../models/message.dart';

class MessageDao {
  Future<List<Message>> getByConversation(String conversationId) async {
    final storage = await Storage.instance;
    final maps = storage.getMessages(conversationId);
    maps.sort((a, b) => (a['created_at'] as int).compareTo(b['created_at'] as int));
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> insert(Message msg) async {
    final storage = await Storage.instance;
    await storage.insertMessage(msg.toMap());
  }

  Future<void> updateContent(String id, String content) async {
    final storage = await Storage.instance;
    final allConvs = storage.getAllConversations();
    for (final conv in allConvs) {
      final msgs = storage.getMessages(conv['id'] as String);
      final idx = msgs.indexWhere((m) => m['id'] == id);
      if (idx >= 0) {
        msgs[idx]['content'] = content;
        await storage.saveMessages(conv['id'] as String, msgs);
        return;
      }
    }
  }

  Future<void> deleteByConversation(String conversationId) async {
    final storage = await Storage.instance;
    await storage.deleteMessages(conversationId);
  }

  Future<void> deleteById(String conversationId, String messageId) async {
    final storage = await Storage.instance;
    final msgs = storage.getMessages(conversationId);
    msgs.removeWhere((m) => m['id'] == messageId);
    await storage.saveMessages(conversationId, msgs);
  }

  Future<void> toggleFavorite(String conversationId, String messageId) async {
    final storage = await Storage.instance;
    final msgs = storage.getMessages(conversationId);
    for (final m in msgs) {
      if (m['id'] == messageId) {
        m['is_favorite'] = (m['is_favorite'] as int? ?? 0) == 1 ? 0 : 1;
        break;
      }
    }
    await storage.saveMessages(conversationId, msgs);
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final storage = await Storage.instance;
    final allConvs = storage.getAllConversations();
    final favorites = <Map<String, dynamic>>[];
    for (final conv in allConvs) {
      final msgs = storage.getMessages(conv['id'] as String);
      for (final m in msgs) {
        if ((m['is_favorite'] as int? ?? 0) == 1) {
          favorites.add({
            ...m,
            'conversation_title': conv['title'] as String? ?? 'Chat',
          });
        }
      }
    }
    favorites.sort((a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int));
    return favorites;
  }

  Future<Set<String>> searchConversationIds(String query) async {
    final storage = await Storage.instance;
    final allConvs = storage.getAllConversations();
    final matches = <String>{};
    for (final conv in allConvs) {
      final msgs = storage.getMessages(conv['id'] as String);
      for (final msg in msgs) {
        if ((msg['content'] as String).toLowerCase().contains(query.toLowerCase())) {
          matches.add(conv['id'] as String);
          break;
        }
      }
    }
    return matches;
  }
}
