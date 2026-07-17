import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Skill {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final List<String> triggerKeywords;
  final List<String> toolAllowlist;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Skill({
    String? id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.triggerKeywords = const [],
    this.toolAllowlist = const [],
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Skill copyWith({
    String? name,
    String? description,
    String? systemPrompt,
    List<String>? triggerKeywords,
    List<String>? toolAllowlist,
    bool? enabled,
  }) {
    return Skill(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      triggerKeywords: triggerKeywords ?? this.triggerKeywords,
      toolAllowlist: toolAllowlist ?? this.toolAllowlist,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'triggerKeywords': triggerKeywords,
        'toolAllowlist': toolAllowlist,
        'enabled': enabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      triggerKeywords: (json['triggerKeywords'] as List?)?.cast<String>() ?? [],
      toolAllowlist: (json['toolAllowlist'] as List?)?.cast<String>() ?? [],
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : null,
    );
  }
}
