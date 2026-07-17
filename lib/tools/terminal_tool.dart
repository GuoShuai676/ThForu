import 'dart:convert';
import 'dart:io';
import 'tool_definition.dart';

class TerminalTool {
  static const definition = ToolDefinition(
    name: 'terminal',
    description: 'Execute a shell command on the local system. Returns stdout and stderr. '
        'Use for file operations, system info, running scripts, git commands, etc. '
        'Commands run in the user\'s home directory.',
    parameters: {
      'type': 'object',
      'properties': {
        'command': {
          'type': 'string',
          'description': 'The shell command to execute',
        },
      },
      'required': ['command'],
    },
  );

  static Future<ToolResult> execute(String toolCallId, Map<String, dynamic> args) async {
    final command = args['command'] as String? ?? '';
    if (command.isEmpty) {
      return ToolResult(toolCallId: toolCallId, name: definition.name, output: 'Error: empty command', isError: true);
    }

    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      ProcessResult result;

      if (Platform.isWindows) {
        result = await Process.run('cmd', ['/c', command], workingDirectory: home);
      } else {
        result = await Process.run('/bin/sh', ['-c', command], workingDirectory: home);
      }

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();
      final exitCode = result.exitCode;

      final buf = StringBuffer();
      if (stdout.isNotEmpty) buf.writeln(stdout);
      if (stderr.isNotEmpty) {
        buf.writeln('[stderr] $stderr');
      }
      buf.writeln('[exit code: $exitCode]');

      var output = buf.toString();
      if (output.length > 8000) {
        output = output.substring(0, 8000) + '\n... (truncated)';
      }

      return ToolResult(
        toolCallId: toolCallId,
        name: definition.name,
        output: output,
        isError: exitCode != 0,
      );
    } catch (e) {
      return ToolResult(toolCallId: toolCallId, name: definition.name, output: 'Error: $e', isError: true);
    }
  }

  static Future<List<String>> commandHistory() async {
    return [];
  }
}
