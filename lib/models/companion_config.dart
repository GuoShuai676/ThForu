import 'dart:convert';
import 'package:flutter/material.dart';

/// Companion visual style / skin preset.
enum CompanionSkin {
  hanLi,   // 韩立：修仙像素风
  codex,   // Codex：科技风
  custom,  // 自定义
}

/// Hair style for custom skin.
enum CompanionHair {
  topknot,    // 发髻
  loose,      // 披发
  short,      // 短发
  hooded,     // 兜帽
  none,       // 光头
}

/// Outfit / robe style.
enum CompanionOutfit {
  robe,       // 长袍
  tunic,      // 短打
  armor,      // 轻甲
  cloak,      // 斗篷
}

/// Accessory slot.
enum CompanionAccessory {
  none,
  sword,         // 飞剑
  staff,         // 法杖
  pouch,         // 储物袋
  scroll,        // 卷轴
  companion,     // 灵兽
}

/// Expression override (falls back to mood-driven when null).
enum CompanionExpression {
  neutral,
  focused,
  happy,
  surprised,
  worried,
}

/// Personality preset for flavor text / catchphrases.
enum CompanionPersonality {
  calm,       // 冷静
  playful,    // 活泼
  serious,    // 严肃
  mysterious, // 神秘
}

class CompanionConfig {
  // ---- Display ----
  final bool enabled;
  final CompanionSkin skin;
  final double size;

  // ---- Visual customization ----
  final int primaryColor;   // robe / main body
  final int accentColor;    // trim / aura / sword glow
  final int skinColor;      // face / hands
  final int hairColor;
  final CompanionHair hair;
  final CompanionOutfit outfit;
  final CompanionAccessory accessory;
  final CompanionExpression? expressionOverride;

  // ---- Character ----
  final String name;
  final CompanionPersonality personality;
  final List<String> catchphrases; // randomly spoken during idle/speaking
  final String customSystemPrompt; // injected when clicking the companion

  // ---- Behavior ----
  final bool showName;
  final bool autoHide;        // auto hide after inactivity
  final int autoHideSeconds;  // seconds before auto-hide (0 = never)
  final bool showQuickMenu;   // tap to show quick menu

  // ---- Position persistence ----
  final double? savedPositionX;
  final double? savedPositionY;
  final bool dockToEdge;

  const CompanionConfig({
    this.enabled = true,
    this.skin = CompanionSkin.hanLi,
    this.size = 72,
    this.primaryColor = 0xFF2F7D57,
    this.accentColor = 0xFFD6A84F,
    this.skinColor = 0xFFFFD9B3,
    this.hairColor = 0xFF161616,
    this.hair = CompanionHair.topknot,
    this.outfit = CompanionOutfit.robe,
    this.accessory = CompanionAccessory.sword,
    this.expressionOverride,
    this.name = '韩立',
    this.personality = CompanionPersonality.calm,
    this.catchphrases = const [
      '修仙之路，步步为营',
      '此物与我有缘',
      '天机不可泄露',
      '道友请留步',
    ],
    this.customSystemPrompt = '',
    this.showName = true,
    this.autoHide = false,
    this.autoHideSeconds = 0,
    this.showQuickMenu = true,
    this.savedPositionX,
    this.savedPositionY,
    this.dockToEdge = true,
  });

  Color get primary => Color(primaryColor);
  Color get accent => Color(accentColor);
  Color get faceColor => Color(skinColor);
  Color get hairC => Color(hairColor);

  CompanionConfig copyWith({
    bool? enabled,
    CompanionSkin? skin,
    double? size,
    int? primaryColor,
    int? accentColor,
    int? skinColor,
    int? hairColor,
    CompanionHair? hair,
    CompanionOutfit? outfit,
    CompanionAccessory? accessory,
    CompanionExpression? expressionOverride,
    bool clearExpression = false,
    String? name,
    CompanionPersonality? personality,
    List<String>? catchphrases,
    String? customSystemPrompt,
    bool? showName,
    bool? autoHide,
    int? autoHideSeconds,
    bool? showQuickMenu,
    double? savedPositionX,
    double? savedPositionY,
    bool? dockToEdge,
  }) {
    return CompanionConfig(
      enabled: enabled ?? this.enabled,
      skin: skin ?? this.skin,
      size: size ?? this.size,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      skinColor: skinColor ?? this.skinColor,
      hairColor: hairColor ?? this.hairColor,
      hair: hair ?? this.hair,
      outfit: outfit ?? this.outfit,
      accessory: accessory ?? this.accessory,
      expressionOverride:
          clearExpression ? null : expressionOverride ?? this.expressionOverride,
      name: name ?? this.name,
      personality: personality ?? this.personality,
      catchphrases: catchphrases ?? this.catchphrases,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
      showName: showName ?? this.showName,
      autoHide: autoHide ?? this.autoHide,
      autoHideSeconds: autoHideSeconds ?? this.autoHideSeconds,
      showQuickMenu: showQuickMenu ?? this.showQuickMenu,
      savedPositionX: savedPositionX ?? this.savedPositionX,
      savedPositionY: savedPositionY ?? this.savedPositionY,
      dockToEdge: dockToEdge ?? this.dockToEdge,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'skin': skin.name,
        'size': size,
        'primaryColor': primaryColor,
        'accentColor': accentColor,
        'skinColor': skinColor,
        'hairColor': hairColor,
        'hair': hair.name,
        'outfit': outfit.name,
        'accessory': accessory.name,
        'expressionOverride': expressionOverride?.name,
        'name': name,
        'personality': personality.name,
        'catchphrases': catchphrases,
        'customSystemPrompt': customSystemPrompt,
        'showName': showName,
        'autoHide': autoHide,
        'autoHideSeconds': autoHideSeconds,
        'showQuickMenu': showQuickMenu,
        'savedPositionX': savedPositionX,
        'savedPositionY': savedPositionY,
        'dockToEdge': dockToEdge,
      };

  factory CompanionConfig.fromJson(Map<String, dynamic> json) {
    return CompanionConfig(
      enabled: json['enabled'] as bool? ?? true,
      skin: _enumFromName(CompanionSkin.values, json['skin'], CompanionSkin.hanLi),
      size: (json['size'] as num?)?.toDouble() ?? 72,
      primaryColor: json['primaryColor'] as int? ?? 0xFF2F7D57,
      accentColor: json['accentColor'] as int? ?? 0xFFD6A84F,
      skinColor: json['skinColor'] as int? ?? 0xFFFFD9B3,
      hairColor: json['hairColor'] as int? ?? 0xFF161616,
      hair: _enumFromName(
          CompanionHair.values, json['hair'], CompanionHair.topknot),
      outfit: _enumFromName(
          CompanionOutfit.values, json['outfit'], CompanionOutfit.robe),
      accessory: _enumFromName(
          CompanionAccessory.values, json['accessory'], CompanionAccessory.sword),
      expressionOverride: _parseExpressionOverride(json['expressionOverride']),
      name: json['name'] as String? ?? '韩立',
      personality: _enumFromName(
          CompanionPersonality.values, json['personality'], CompanionPersonality.calm),
      catchphrases:
          (json['catchphrases'] as List?)?.cast<String>() ?? const [],
      customSystemPrompt: json['customSystemPrompt'] as String? ?? '',
      showName: json['showName'] as bool? ?? true,
      autoHide: json['autoHide'] as bool? ?? false,
      autoHideSeconds: json['autoHideSeconds'] as int? ?? 0,
      showQuickMenu: json['showQuickMenu'] as bool? ?? true,
      savedPositionX: (json['savedPositionX'] as num?)?.toDouble(),
      savedPositionY: (json['savedPositionY'] as num?)?.toDouble(),
      dockToEdge: json['dockToEdge'] as bool? ?? true,
    );
  }

  static CompanionExpression? _parseExpressionOverride(String? name) {
    if (name == null) return null;
    for (final v in CompanionExpression.values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static T _enumFromName<T extends Enum>(
      List<T> values, String? name, T defaultValue) {
    if (name == null) return defaultValue;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return defaultValue;
  }

  String encode() => jsonEncode(toJson());

  static CompanionConfig decode(String raw) {
    try {
      return CompanionConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const CompanionConfig();
    }
  }
}
