import 'tool_definition.dart';
import 'terminal_tool.dart';
import 'web_search_tool.dart';
import 'memory_tool.dart';
import 'datetime_tool.dart';
import '../db/memory_dao.dart';

class ToolExecutor {
  final MemoryDao _memoryDao;

  ToolExecutor(this._memoryDao);

  Future<ToolResult> execute(ToolCall call) async {
    switch (call.name) {
      case 'terminal':
        return TerminalTool.execute(call.id, call.arguments);
      case 'web_search':
        return WebSearchTool.execute(call.id, call.arguments);
      case 'memory':
        return MemoryTool.execute(call.id, call.arguments, _memoryDao);
      case 'datetime':
        return DateTimeTool.execute(call.id, call.arguments);
      default:
        return ToolResult(
          toolCallId: call.id,
          name: call.name,
          output: 'Unknown tool: ${call.name}',
          isError: true,
        );
    }
  }

  Future<List<ToolResult>> executeAll(List<ToolCall> calls) async {
    final results = <ToolResult>[];
    for (final call in calls) {
      results.add(await execute(call));
    }
    return results;
  }
}
