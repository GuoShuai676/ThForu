import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static Database? _db;
  static const int _version = 2;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_chat.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT 'New Chat',
        provider_config_id TEXT NOT NULL,
        model_name TEXT NOT NULL,
        reasoning_effort TEXT,
        expert_panel_id TEXT,
        persona_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        wallpaper_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('user','assistant','system','tool')),
        content TEXT NOT NULL DEFAULT '',
        image_paths TEXT,
        file_path TEXT,
        file_name TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        tool_call_id TEXT,
        tool_calls TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE memories (
        id TEXT PRIMARY KEY,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        tags TEXT,
        source_conversation_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conversation
      ON messages(conversation_id, created_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_favorite
      ON messages(is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX idx_memories_key
      ON memories(key)
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
            "ALTER TABLE conversations ADD COLUMN reasoning_effort TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE messages ADD COLUMN tool_call_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE messages ADD COLUMN tool_calls TEXT");
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS memories (
          id TEXT PRIMARY KEY,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          tags TEXT,
          source_conversation_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_memories_key ON memories(key)');
    }
  }

  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('conversations');
    if (raw == null) return;

    final db = await database;
    final batch = db.batch();

    final convList = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    for (final conv in convList) {
      batch.insert('conversations', conv);
      final convId = conv['id'] as String;
      final msgRaw = prefs.getString('messages_$convId');
      if (msgRaw != null) {
        final msgList =
            (jsonDecode(msgRaw) as List).cast<Map<String, dynamic>>();
        for (final msg in msgList) {
          batch.insert('messages', msg);
        }
      }
    }

    await batch.commit(noResult: true);

    await prefs.remove('conversations');
    for (final conv in convList) {
      await prefs.remove('messages_${conv['id']}');
    }
  }
}
