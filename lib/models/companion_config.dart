import 'dart:convert';
import 'package:flutter/material.dart';

enum CompanionStyle { codex, hanLi }

class CompanionConfig {
  final bool enabled;
  final String name;
  final CompanionStyle style;
  final int primaryColor;
  final int accentColor;
  final double size;
  final bool showName;

  const CompanionConfig({
    this.enabled = true,
    this.name = '韩立',
    this.style = CompanionStyle.hanLi,
    this.primaryColor = 0xFF2F7D57,
    this.accentColor = 0xFFD6A84F,
    this.size = 72,
    this.showName = true,
  });

  Color get primary => Color(primaryColor);
  Color get accent => Color(accentColor);

  CompanionConfig copyWith({
    bool? enabled,
    String? name,
    CompanionStyle? style,
    int? primaryColor,
    int? accentColor,
    double? size,
    bool? showName,
  }) {
    return CompanionConfig(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      style: style ?? this.style,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      size: size ?? this.size,
      showName: showName ?? this.showName,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'name': name,
        'style': style.name,
        'primaryColor': primaryColor,
        'accentColor': accentColor,
        'size': size,
        'showName': showName,
      };

  factory CompanionConfig.fromJson(Map<String, dynamic> json) {
    final styleName = json['style'] as String? ?? CompanionStyle.hanLi.name;
    final style = CompanionStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => CompanionStyle.hanLi,
    );
    return CompanionConfig(
      enabled: json['enabled'] as bool? ?? true,
      name: json['name'] as String? ?? '韩立',
      style: style,
      primaryColor: json['primaryColor'] as int? ?? 0xFF2F7D57,
      accentColor: json['accentColor'] as int? ?? 0xFFD6A84F,
      size: (json['size'] as num?)?.toDouble() ?? 72,
      showName: json['showName'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());

  static CompanionConfig decode(String raw) {
    try {
      return CompanionConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const CompanionConfig();
    }
  }
}
