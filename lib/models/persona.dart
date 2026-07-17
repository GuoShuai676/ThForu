import 'package:uuid/uuid.dart';

class Persona {
  final String id;
  final String name;
  final String systemPrompt;
  final int avatarIcon; // Icons.codePoint
  final int avatarColor; // Color.value

  Persona({
    String? id,
    required this.name,
    required this.systemPrompt,
    required this.avatarIcon,
    required this.avatarColor,
  }) : id = id ?? const Uuid().v4();

  Persona copyWith({
    String? name,
    String? systemPrompt,
    int? avatarIcon,
    int? avatarColor,
  }) {
    return Persona(
      id: id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'system_prompt': systemPrompt,
        'avatar_icon': avatarIcon,
        'avatar_color': avatarColor,
      };

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] as String,
      name: json['name'] as String,
      systemPrompt: json['system_prompt'] as String,
      avatarIcon: json['avatar_icon'] as int,
      avatarColor: json['avatar_color'] as int,
    );
  }
}
