import 'tool_definition.dart';
import 'terminal_tool.dart';
import 'web_search_tool.dart';
import 'memory_tool.dart';
import 'datetime_tool.dart';
import '../db/memory_dao.dart';

class ToolRegistry {
  final Set<String> _enabledTools;

  ToolRegistry(MemoryDao memoryDao, {Set<String>? enabledTools})
      : _enabledTools =
            enabledTools ?? {'terminal', 'web_search', 'memory', 'datetime'};

  static const _allDefinitions = <String, ToolDefinition>{
    'terminal': TerminalTool.definition,
    'web_search': WebSearchTool.definition,
    'memory': MemoryTool.definition,
    'datetime': DateTimeTool.definition,
  };

  List<ToolDefinition> get enabledDefinitions {
    return _enabledTools
        .where(_allDefinitions.containsKey)
        .map((name) => _allDefinitions[name]!)
        .toList();
  }

  List<Map<String, dynamic>> get openAiTools =>
      enabledDefinitions.map((t) => t.toOpenAITool()).toList();

  Set<String> get enabledToolNames => Set.unmodifiable(_enabledTools);

  List<Map<String, dynamic>> openAiToolsFor(Set<String> names) {
    return names
        .where(_enabledTools.contains)
        .where(_allDefinitions.containsKey)
        .map((name) => _allDefinitions[name]!.toOpenAITool())
        .toList();
  }

  bool get hasTools => _enabledTools.isNotEmpty;

  void enable(String name) => _enabledTools.add(name);
  void disable(String name) => _enabledTools.remove(name);
  void toggle(String name) {
    if (_enabledTools.contains(name)) {
      _enabledTools.remove(name);
    } else {
      _enabledTools.add(name);
    }
  }

  bool isEnabled(String name) => _enabledTools.contains(name);
}
