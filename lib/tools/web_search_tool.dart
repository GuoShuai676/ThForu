import 'tool_definition.dart';
import '../services/search_service.dart';

class WebSearchTool {
  static const definition = ToolDefinition(
    name: 'web_search',
    description:
        'Search the web for information. Returns a list of search results with titles, URLs, and snippets. '
        'Use when you need current information, facts, documentation, or anything not in your training data.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The search query',
        },
        'max_results': {
          'type': 'integer',
          'description': 'Maximum number of results (default 5, max 10)',
        },
      },
      'required': ['query'],
    },
  );

  static Future<ToolResult> execute(
      String toolCallId, Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;

    if (query.isEmpty) {
      return ToolResult(
          toolCallId: toolCallId,
          name: definition.name,
          output: 'Error: empty query',
          isError: true);
    }

    try {
      final results = await SearchService.search(query,
          maxResults: maxResults.clamp(1, 10));
      if (results.isEmpty) {
        return ToolResult(
            toolCallId: toolCallId,
            name: definition.name,
            output: 'No results found for: $query');
      }

      final buf = StringBuffer();
      buf.writeln('Found ${results.length} results for "$query":\n');
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        buf.writeln('${i + 1}. ${r.title}');
        buf.writeln('   URL: ${r.url}');
        buf.writeln('   ${r.snippet}');
        buf.writeln('');
      }

      return ToolResult(
          toolCallId: toolCallId,
          name: definition.name,
          output: buf.toString());
    } catch (e) {
      return ToolResult(
          toolCallId: toolCallId,
          name: definition.name,
          output: 'Search error: $e',
          isError: true);
    }
  }
}
