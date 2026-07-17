import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

const _uuid = Uuid();

class MemoryEntry {
  final String id;
  final String key;
  final String value;
  final List<String> tags;
  final String? sourceConversationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryEntry({
    String? id,
    required this.key,
    required this.value,
    this.tags = const [],
    this.sourceConversationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'value': value,
        'tags': tags.join(','),
        'source_conversation_id': sourceConversationId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory MemoryEntry.fromMap(Map<String, dynamic> map) {
    final tagsStr = map['tags'] as String? ?? '';
    return MemoryEntry(
      id: map['id'] as String,
      key: map['key'] as String,
      value: map['value'] as String,
      tags: tagsStr.isEmpty ? [] : tagsStr.split(','),
      sourceConversationId: map['source_conversation_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class MemoryDao {
  Future<List<MemoryEntry>> getAll() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('memories', orderBy: 'updated_at DESC');
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  Future<List<MemoryEntry>> search(String query) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'memories',
      where: 'key LIKE ? OR value LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }

  Future<MemoryEntry?> getByKey(String key) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('memories', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return MemoryEntry.fromMap(maps.first);
  }

  Future<void> upsert(MemoryEntry entry) async {
    final db = await DatabaseHelper.database;
    final existing = await getByKey(entry.key);
    if (existing != null) {
      final updated = MemoryEntry(
        id: existing.id,
        key: entry.key,
        value: entry.value,
        tags: entry.tags.isNotEmpty ? entry.tags : existing.tags,
        sourceConversationId:
            entry.sourceConversationId ?? existing.sourceConversationId,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await db.update('memories', updated.toMap(),
          where: 'id = ?', whereArgs: [updated.id]);
    } else {
      await db.insert('memories', entry.toMap());
    }
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByKey(String key) async {
    final db = await DatabaseHelper.database;
    await db.delete('memories', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clearAll() async {
    final db = await DatabaseHelper.database;
    await db.delete('memories');
  }

  Future<List<MemoryEntry>> getRelevant(String query, {int limit = 10}) async {
    final db = await DatabaseHelper.database;
    final keywords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
    if (keywords.isEmpty) return getAll().then((v) => v.take(limit).toList());

    final conditions = keywords
        .map((k) => '(key LIKE ? OR value LIKE ? OR tags LIKE ?)')
        .join(' OR ');
    final args = keywords.expand((k) => ['%$k%', '%$k%', '%$k%']).toList();

    final maps = await db.query(
      'memories',
      where: conditions,
      whereArgs: args,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map((m) => MemoryEntry.fromMap(m)).toList();
  }
}
