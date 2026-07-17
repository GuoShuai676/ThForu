import 'dart:convert';

class ToolSettings {
  final bool toolsEnabled;
  final bool terminalEnabled;
  final bool webSearchEnabled;
  final bool memoryEnabled;
  final bool datetimeEnabled;
  final String terminalPermission;
  final int webSearchMaxResults;

  const ToolSettings({
    this.toolsEnabled = true,
    this.terminalEnabled = true,
    this.webSearchEnabled = true,
    this.memoryEnabled = true,
    this.datetimeEnabled = true,
    this.terminalPermission = 'read_only',
    this.webSearchMaxResults = 5,
  });

  Set<String> get enabledTools {
    final tools = <String>{};
    if (terminalEnabled) tools.add('terminal');
    if (webSearchEnabled) tools.add('web_search');
    if (memoryEnabled) tools.add('memory');
    if (datetimeEnabled) tools.add('datetime');
    return tools;
  }

  ToolSettings copyWith({
    bool? toolsEnabled,
    bool? terminalEnabled,
    bool? webSearchEnabled,
    bool? memoryEnabled,
    bool? datetimeEnabled,
    String? terminalPermission,
    int? webSearchMaxResults,
  }) {
    return ToolSettings(
      toolsEnabled: toolsEnabled ?? this.toolsEnabled,
      terminalEnabled: terminalEnabled ?? this.terminalEnabled,
      webSearchEnabled: webSearchEnabled ?? this.webSearchEnabled,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      datetimeEnabled: datetimeEnabled ?? this.datetimeEnabled,
      terminalPermission: terminalPermission ?? this.terminalPermission,
      webSearchMaxResults: webSearchMaxResults ?? this.webSearchMaxResults,
    );
  }

  Map<String, dynamic> toJson() => {
        'toolsEnabled': toolsEnabled,
        'terminalEnabled': terminalEnabled,
        'webSearchEnabled': webSearchEnabled,
        'memoryEnabled': memoryEnabled,
        'datetimeEnabled': datetimeEnabled,
        'terminalPermission': terminalPermission,
        'webSearchMaxResults': webSearchMaxResults,
      };

  factory ToolSettings.fromJson(Map<String, dynamic> json) {
    return ToolSettings(
      toolsEnabled: json['toolsEnabled'] as bool? ?? true,
      terminalEnabled: json['terminalEnabled'] as bool? ?? true,
      webSearchEnabled: json['webSearchEnabled'] as bool? ?? true,
      memoryEnabled: json['memoryEnabled'] as bool? ?? true,
      datetimeEnabled: json['datetimeEnabled'] as bool? ?? true,
      terminalPermission: json['terminalPermission'] as String? ?? 'read_only',
      webSearchMaxResults: json['webSearchMaxResults'] as int? ?? 5,
    );
  }

  String encode() => jsonEncode(toJson());

  static ToolSettings decode(String raw) {
    try {
      return ToolSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ToolSettings();
    }
  }
}
