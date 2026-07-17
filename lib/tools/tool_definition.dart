class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toOpenAITool() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class ToolResult {
  final String toolCallId;
  final String name;
  final String output;
  final bool isError;

  const ToolResult({
    required this.toolCallId,
    required this.name,
    required this.output,
    this.isError = false,
  });

  Map<String, dynamic> toMessage() => {
        'role': 'tool',
        'tool_call_id': toolCallId,
        'name': name,
        'content': output,
      };
}
