import 'tool_definition.dart';

class DateTimeTool {
  static const definition = ToolDefinition(
    name: 'datetime',
    description:
        'Get the current date, time, day of week, or timezone information. '
        'Use when you need to know the current date/time or perform date-related calculations.',
    parameters: {
      'type': 'object',
      'properties': {
        'format': {
          'type': 'string',
          'description':
              'Optional: "full" for complete info, "date" for date only, "time" for time only, "unix" for unix timestamp. Default: "full"',
        },
      },
    },
  );

  static Future<ToolResult> execute(
      String toolCallId, Map<String, dynamic> args) async {
    final format = args['format'] as String? ?? 'full';
    final now = DateTime.now();

    String output;
    switch (format) {
      case 'date':
        output =
            'Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case 'time':
        output =
            'Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      case 'unix':
        output = 'Unix timestamp: ${now.millisecondsSinceEpoch ~/ 1000}';
      default:
        final weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        output = 'Current datetime:\n'
            '  Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}\n'
            '  Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}\n'
            '  Day: ${weekdays[now.weekday - 1]}\n'
            '  Timezone: ${now.timeZoneName}\n'
            '  Unix: ${now.millisecondsSinceEpoch ~/ 1000}';
    }

    return ToolResult(
        toolCallId: toolCallId, name: definition.name, output: output);
  }
}
