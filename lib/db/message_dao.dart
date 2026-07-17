import 'database_helper.dart';
import '../models/message.dart';

class MessageDao {
  Future<List<Message>> getByConversation(String conversationId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> insert(Message msg) async {
    final db = await DatabaseHelper.database;
    await db.insert('messages', msg.toMap());
  }

  Future<void> updateContent(String conversationId, String id, String content) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'messages',
      {'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByConversation(String conversationId) async {
    final db = await DatabaseHelper.database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  Future<void> deleteById(String conversationId, String messageId) async {
    final db = await DatabaseHelper.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> toggleFavorite(String conversationId, String messageId) async {
    final db = await DatabaseHelper.database;
    await db.rawUpdate(
      'UPDATE messages SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END WHERE id = ?',
      [messageId],
    );
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await DatabaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT m.*, c.title as conversation_title
      FROM messages m
      LEFT JOIN conversations c ON m.conversation_id = c.id
      WHERE m.is_favorite = 1
      ORDER BY m.created_at DESC
    ''');
    return maps;
  }

  Future<Set<String>> searchConversationIds(String query) async {
    final db = await DatabaseHelper.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT conversation_id FROM messages WHERE content LIKE ?',
      ['%$query%'],
    );
    return maps.map((m) => m['conversation_id'] as String).toSet();
  }

  Future<void> deleteAfterMessage(String conversationId, String messageId) async {
    final db = await DatabaseHelper.database;
    final msg = await db.query('messages', where: 'id = ?', whereArgs: [messageId]);
    if (msg.isEmpty) return;
    final createdAt = msg.first['created_at'] as int;
    await db.delete(
      'messages',
      where: 'conversation_id = ? AND created_at >= ?',
      whereArgs: [conversationId, createdAt],
    );
  }
}
