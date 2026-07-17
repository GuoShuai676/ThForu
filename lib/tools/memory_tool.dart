import 'dart:convert';
import 'tool_definition.dart';
import '../db/memory_dao.dart';

class MemoryTool {
  static const definition = ToolDefinition(
    name: 'memory',
    description:
        'Manage persistent memories. Use this to remember important information about the user, '
        'their preferences, past decisions, or any facts that should persist across conversations. '
        'Actions: save (store a fact), get (retrieve by key), list (show all), delete (remove by key), search (find relevant memories).',
    parameters: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['save', 'get', 'list', 'delete', 'search'],
          'description': 'The action to perform',
        },
        'key': {
          'type': 'string',
          'description': 'Memory key (required for save/get/delete)',
        },
        'value': {
          'type': 'string',
          'description': 'Memory value (required for save)',
        },
        'tags': {
          'type': 'string',
          'description': 'Comma-separated tags for categorization (optional)',
        },
        'query': {
          'type': 'string',
          'description': 'Search query (required for search action)',
        },
      },
      'required': ['action'],
    },
  );

  static Future<ToolResult> execute(
      String toolCallId, Map<String, dynamic> args, MemoryDao dao) async {
    final action = args['action'] as String? ?? '';
    final key = args['key'] as String? ?? '';
    final value = args['value'] as String? ?? '';
    final tagsStr = args['tags'] as String? ?? '';
    final query = args['query'] as String? ?? '';

    try {
      switch (action) {
        case 'save':
          if (key.isEmpty || value.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'Error: key and value are required for save',
                isError: true);
          }
          final tags = tagsStr.isEmpty
              ? <String>[]
              : tagsStr.split(',').map((t) => t.trim()).toList();
          await dao.upsert(MemoryEntry(key: key, value: value, tags: tags));
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output: 'Memory saved: $key = $value');

        case 'get':
          if (key.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'Error: key is required for get',
                isError: true);
          }
          final entry = await dao.getByKey(key);
          if (entry == null) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'No memory found with key: $key');
          }
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output:
                  '${entry.key} = ${entry.value}\nTags: ${entry.tags.join(", ")}');

        case 'list':
          final all = await dao.getAll();
          if (all.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'No memories stored.');
          }
          final buf = StringBuffer();
          buf.writeln('Stored memories (${all.length}):');
          for (final m in all) {
            buf.writeln(
                '- ${m.key}: ${m.value.length > 80 ? '${m.value.substring(0, 80)}...' : m.value}');
          }
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output: buf.toString());

        case 'delete':
          if (key.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'Error: key is required for delete',
                isError: true);
          }
          await dao.deleteByKey(key);
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output: 'Memory deleted: $key');

        case 'search':
          if (query.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'Error: query is required for search',
                isError: true);
          }
          final results = await dao.search(query);
          if (results.isEmpty) {
            return ToolResult(
                toolCallId: toolCallId,
                name: definition.name,
                output: 'No memories matching: $query');
          }
          final buf = StringBuffer();
          buf.writeln('Found ${results.length} memories matching "$query":');
          for (final m in results) {
            buf.writeln('- ${m.key}: ${m.value}');
          }
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output: buf.toString());

        default:
          return ToolResult(
              toolCallId: toolCallId,
              name: definition.name,
              output:
                  'Unknown action: $action. Use: save, get, list, delete, search',
              isError: true);
      }
    } catch (e) {
      return ToolResult(
          toolCallId: toolCallId,
          name: definition.name,
          output: 'Memory error: $e',
          isError: true);
    }
  }
}
