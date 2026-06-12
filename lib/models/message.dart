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
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isFavorite;

  Message({
    String? id,
    required this.conversationId,
    required this.role,
    this.content = '',
    this.imagePaths,
    this.filePath,
    this.fileName,
    this.metadata,
    DateTime? createdAt,
    this.isFavorite = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get hasImages => imagePaths != null && imagePaths!.isNotEmpty;
  bool get hasFile => filePath != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'image_paths':
            imagePaths != null ? jsonEncode(imagePaths) : null,
        'file_path': filePath,
        'file_name': fileName,
        'metadata':
            metadata != null ? jsonEncode(metadata) : null,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Message.fromMap(Map<String, dynamic> map) {
    List<String>? paths;
    if (map['image_paths'] != null) {
      paths = (jsonDecode(map['image_paths'] as String) as List)
          .cast<String>();
    }
    Map<String, dynamic>? meta;
    if (map['metadata'] != null) {
      meta = (jsonDecode(map['metadata'] as String) as Map)
          .cast<String, dynamic>();
    }
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      imagePaths: paths,
      filePath: map['file_path'] as String?,
      fileName: map['file_name'] as String?,
      metadata: meta,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isFavorite: (map['is_favorite'] as int?) == 1,
    );
  }

  Map<String, dynamic> toOpenAIMessage() {
    if (!hasImages && !hasFile) {
      return {'role': role, 'content': content};
    }

    final contentList = <Map<String, dynamic>>[
      {'type': 'text', 'text': content},
    ];

    for (final path in imagePaths ?? <String>[]) {
      try {
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
      final bytes = File(filePath!).readAsBytesSync();
      final base64 = base64Encode(bytes);
      final ext = filePath!.split('.').last.toLowerCase();
      contentList.add({
        'type': 'file',
        'file': {
          'filename': fileName ?? 'file.$ext',
          'file_data': base64,
        },
      });
    }

    return {'role': role, 'content': contentList};
  }

  Message copyWith({
    String? content,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
    Map<String, dynamic>? metadata,
    bool? isFavorite,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      imagePaths: imagePaths ?? this.imagePaths,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
