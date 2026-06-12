import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Conversation {
  final String id;
  String title;
  final String providerConfigId;
  final String modelName;
  final String? expertPanelId;
  final String? personaId;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  String? wallpaperPath;

  Conversation({
    String? id,
    this.title = 'New Chat',
    required this.providerConfigId,
    required this.modelName,
    this.expertPanelId,
    this.personaId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.wallpaperPath,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'provider_config_id': providerConfigId,
        'model_name': modelName,
        'expert_panel_id': expertPanelId,
        'persona_id': personaId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'is_pinned': isPinned ? 1 : 0,
        'wallpaper_path': wallpaperPath,
      };

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      providerConfigId: map['provider_config_id'] as String,
      modelName: map['model_name'] as String,
      expertPanelId: map['expert_panel_id'] as String?,
      personaId: map['persona_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isPinned: map['is_pinned'] == 1 || map['is_pinned'] == true,
      wallpaperPath: map['wallpaper_path'] as String?,
    );
  }
}
