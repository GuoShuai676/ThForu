import 'database_helper.dart';
import '../models/conversation.dart';

class ConversationDao {
  Future<List<Conversation>> getAll() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('conversations', orderBy: 'updated_at DESC');
    return maps
        .map((m) {
          try {
            return Conversation.fromMap(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<Conversation>()
        .toList();
  }

  Future<Conversation?> getById(String id) async {
    final db = await DatabaseHelper.database;
    final maps =
        await db.query('conversations', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  Future<void> insert(Conversation conv) async {
    final db = await DatabaseHelper.database;
    await db.insert('conversations', conv.toMap());
  }

  Future<void> update(Conversation conv) async {
    final db = await DatabaseHelper.database;
    await db.update('conversations', conv.toMap(),
        where: 'id = ?', whereArgs: [conv.id]);
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTitle(String id, String title) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateWallpaper(String id, String? wallpaperPath) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'conversations',
      {'wallpaper_path': wallpaperPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateModel(
      String id, String modelName, String? reasoningEffort) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'conversations',
      {
        'model_name': modelName,
        'reasoning_effort': reasoningEffort,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
