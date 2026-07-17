import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Message {
  final String id;
  final String conversationId;
  final String role;
  String content;
  final List<String>? imagePaths;
  final String? filePath;
  final String? fileName;
  final List<String>? filePaths;
  final List<String>? fileNames;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isFavorite;
  final String? toolCallId;
  final List<Map<String, dynamic>>? toolCalls;

  Message({
    String? id,
    required this.conversationId,
    required this.role,
    this.content = '',
    this.imagePaths,
    this.filePath,
    this.fileName,
    this.filePaths,
    this.fileNames,
    this.metadata,
    DateTime? createdAt,
    this.isFavorite = false,
    this.toolCallId,
    this.toolCalls,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get hasImages => imagePaths != null && imagePaths!.isNotEmpty;
  bool get hasFile =>
      filePath != null || (filePaths != null && filePaths!.isNotEmpty);
  bool get isToolCall => toolCalls != null && toolCalls!.isNotEmpty;
  bool get isToolResult => role == 'tool';

  List<String> get allFilePaths {
    if (filePaths != null && filePaths!.isNotEmpty) return filePaths!;
    if (filePath != null) return [filePath!];
    return [];
  }

  List<String> get allFileNames {
    if (fileNames != null && fileNames!.isNotEmpty) return fileNames!;
    if (fileName != null) return [fileName!];
    return [];
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'image_paths': imagePaths != null ? jsonEncode(imagePaths) : null,
        'file_path': filePath ??
            (filePaths != null && filePaths!.isNotEmpty
                ? jsonEncode(filePaths)
                : null),
        'file_name': fileName ??
            (fileNames != null && fileNames!.isNotEmpty
                ? jsonEncode(fileNames)
                : null),
        'metadata': metadata != null ? jsonEncode(metadata) : null,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_favorite': isFavorite ? 1 : 0,
        'tool_call_id': toolCallId,
        'tool_calls': toolCalls != null ? jsonEncode(toolCalls) : null,
      };

  factory Message.fromMap(Map<String, dynamic> map) {
    List<String>? paths;
    if (map['image_paths'] != null) {
      paths = (jsonDecode(map['image_paths'] as String) as List).cast<String>();
    }
    Map<String, dynamic>? meta;
    if (map['metadata'] != null) {
      meta = (jsonDecode(map['metadata'] as String) as Map)
          .cast<String, dynamic>();
    }
    List<Map<String, dynamic>>? tcs;
    if (map['tool_calls'] != null) {
      tcs = (jsonDecode(map['tool_calls'] as String) as List)
          .cast<Map<String, dynamic>>();
    }
    String? fp = map['file_path'] as String?;
    String? fn = map['file_name'] as String?;
    List<String>? fps;
    List<String>? fns;
    if (fp != null && fp.startsWith('[')) {
      try {
        fps = (jsonDecode(fp) as List).cast<String>();
        fp = null;
      } catch (_) {}
    }
    if (fn != null && fn.startsWith('[')) {
      try {
        fns = (jsonDecode(fn) as List).cast<String>();
        fn = null;
      } catch (_) {}
    }
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      imagePaths: paths,
      filePath: fp,
      fileName: fn,
      filePaths: fps,
      fileNames: fns,
      metadata: meta,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isFavorite: (map['is_favorite'] as int?) == 1,
      toolCallId: map['tool_call_id'] as String?,
      toolCalls: tcs,
    );
  }

  /// Converts this message to an OpenAI-compatible message map.
  ///
  /// When [allowImageUrl] is false, images are replaced with a text placeholder
  /// instead of `image_url` parts.  Set to `false` for tool-calling requests or
  /// providers that don't support vision.
  ///
  /// When [allowFileText] is false, file content is replaced with a short
  /// placeholder instead of being inlined as text.
  Map<String, dynamic> toOpenAIMessage({
    bool allowImageUrl = true,
    bool allowFileText = true,
  }) {
    if (!hasImages && !hasFile && !isToolResult && !isToolCall) {
      return {'role': role, 'content': content};
    }

    if (isToolResult) {
      return {
        'role': 'tool',
        'tool_call_id': toolCallId,
        'content': content,
      };
    }

    if (isToolCall) {
      return {
        'role': 'assistant',
        'content': content.isEmpty ? null : content,
        'tool_calls': toolCalls,
      };
    }

    final contentList = <Map<String, dynamic>>[
      {'type': 'text', 'text': content},
    ];

    for (final path in imagePaths ?? <String>[]) {
      try {
        if (!allowImageUrl) {
          final name = path.split(RegExp(r'[\\/]+')).last;
          contentList.add({
            'type': 'text',
            'text': '[已附加图片: $name。当前请求只支持文本，图片未作为 image_url 发送。]',
          });
          continue;
        }
        final bytes = File(path).readAsBytesSync();
        final base64 = base64Encode(bytes);
        final ext = path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        contentList.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mime;base64,$base64',
          },
        });
      } catch (e) {
        contentList.add({'type': 'text', 'text': '[图片读取失败: $e]'});
      }
    }

    if (hasFile) {
      final paths = allFilePaths;
      final names = allFileNames;
      for (int i = 0; i < paths.length; i++) {
        try {
          final ext = paths[i].split('.').last.toLowerCase();
          final fName = i < names.length ? names[i] : 'file.$ext';
          if (allowFileText) {
            contentList.add({
              'type': 'text',
              'text': _fileAsPromptText(paths[i], fName),
            });
          } else {
            contentList.add({
              'type': 'text',
              'text': '[已附加文件: $fName]',
            });
          }
        } catch (e) {
          contentList.add({'type': 'text', 'text': '[文件读取失败: $e]'});
        }
      }
    }

    return {'role': role, 'content': contentList};
  }

  static String _fileAsPromptText(String path, String fileName) {
    final ext = path.split('.').last.toLowerCase();
    const textExtensions = {
      'txt',
      'md',
      'markdown',
      'json',
      'csv',
      'tsv',
      'xml',
      'html',
      'htm',
      'yaml',
      'yml',
      'dart',
      'js',
      'ts',
      'tsx',
      'jsx',
      'py',
      'java',
      'kt',
      'swift',
      'c',
      'cpp',
      'h',
      'hpp',
      'cs',
      'go',
      'rs',
      'php',
      'rb',
      'sh',
      'bat',
      'ps1',
      'sql',
      'log',
    };
    if (!textExtensions.contains(ext)) {
      return '[已附加文件: $fileName。当前聊天接口不支持直接上传 file 类型内容，请把文件内容复制为文本，或换用支持文件解析的接口。]';
    }

    final bytes = File(path).readAsBytesSync();
    final raw = utf8.decode(bytes, allowMalformed: true);
    const maxChars = 40000;
    final text = raw.length > maxChars
        ? '${raw.substring(0, maxChars)}\n\n[文件过长，已截断前 $maxChars 字符]'
        : raw;
    return '[文件: $fileName]\n$text';
  }

  Message copyWith({
    String? content,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
    List<String>? filePaths,
    List<String>? fileNames,
    Map<String, dynamic>? metadata,
    bool? isFavorite,
    String? toolCallId,
    List<Map<String, dynamic>>? toolCalls,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      imagePaths: imagePaths ?? this.imagePaths,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      filePaths: filePaths ?? this.filePaths,
      fileNames: fileNames ?? this.fileNames,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      toolCallId: toolCallId ?? this.toolCallId,
      toolCalls: toolCalls ?? this.toolCalls,
    );
  }
}
