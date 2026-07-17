import 'dart:async';
import '../services/terminal/terminal_runner.dart';
import '../services/terminal/terminal_policy.dart';
import 'tool_definition.dart';

class TerminalTool {
  static TerminalRunner? _sharedRunner;
  static TerminalPolicy _policy = const TerminalPolicy(
    mode: TerminalMode.sandboxOnly,
    permissions: {},
  );

  static const definition = ToolDefinition(
    name: 'terminal',
    description: 'Execute a shell command in the app sandbox terminal. '
        'Built-in commands: cd, pwd, ls, cat, mkdir, touch, write, append, rm, clear. '
        'Use for file operations, system info, directory listing, reading/writing files. '
        'Commands run in the app documents directory.',
    parameters: {
      'type': 'object',
      'properties': {
        'command': {
          'type': 'string',
          'description': 'The command to execute',
        },
      },
      'required': ['command'],
    },
  );

  static Future<void> init({TerminalPolicy? policy}) async {
    if (policy != null) _policy = policy;
    _sharedRunner = await TerminalRunner.create(policy: _policy);
  }

  static void updatePolicy(TerminalPolicy policy) {
    _policy = policy;
    _sharedRunner?.updatePolicy(policy);
  }

  static TerminalRunner? get runner => _sharedRunner;

  static Future<ToolResult> execute(
      String toolCallId, Map<String, dynamic> args) async {
    final command = args['command'] as String? ?? '';
    if (command.isEmpty) {
      return ToolResult(
        toolCallId: toolCallId,
        name: definition.name,
        output: 'Error: empty command',
        isError: true,
      );
    }

    if (_sharedRunner == null) {
      try {
        await init();
      } catch (e) {
        return ToolResult(
          toolCallId: toolCallId,
          name: definition.name,
          output: 'Terminal not available: $e',
          isError: true,
        );
      }
    }

    final result = await _sharedRunner!.run(command);

    final buf = StringBuffer();
    if (result.blockedReason != null) {
      buf.writeln('[BLOCKED] ${result.blockedReason}');
    }
    if (result.stdout.isNotEmpty) {
      buf.writeln(result.stdout);
    }
    if (result.stderr.isNotEmpty) {
      buf.writeln('[stderr] ${result.stderr}');
    }
    if (result.timedOut) {
      buf.writeln('[timed out after ${result.duration.inSeconds}s]');
    }
    buf.writeln(
        '[exit code: ${result.exitCode}, duration: ${result.duration.inMilliseconds}ms]');
    buf.writeln('[cwd: ${result.cwd}]');

    var output = buf.toString();
    if (output.length > 8000) {
      output = '${output.substring(0, 8000)}\n... (truncated)';
    }

    return ToolResult(
      toolCallId: toolCallId,
      name: definition.name,
      output: output,
      isError: !result.isSuccess,
    );
  }
}
