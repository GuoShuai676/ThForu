import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pixel_painter.dart';

/// Han Li (韩立) pixel-art skin — cultivation / xianxia style.
///
/// Drawn on the 32×32 grid with:
/// - Green robe (青袍) in [primaryColor]
/// - Black hair in a topknot (墨发/发髻)
/// - Storage pouch (储物袋) on the belt
/// - Small floating sword with glow (飞剑光效)
/// - Aura rings during thinking/speaking (灵气环绕)
class HanLiPainter extends PixelCharacterPainter {
  HanLiPainter({
    super.mood,
    super.breathValue,
    super.blinkValue,
    super.animPhase,
    super.primaryColor,
    super.accentColor,
    super.skinColor,
    super.hairColor,
    super.name,
  });

  Color get _robe => Color(primaryColor);
  Color get _robeDark =>
      HSLColor.fromColor(_robe).withLightness(0.18).toColor();
  Color get _robeLight =>
      HSLColor.fromColor(_robe).withLightness(0.42).toColor();
  Color get _trim => Color(accentColor);
  Color get _skin => Color(skinColor);
  Color get _hair => Color(hairColor);
  Color get _sword => const Color(0xFFB0C4DE);
  Color get _swordGlow => Color(accentColor).withValues(alpha: 0.7);

  /// Shorthand: create a non-antialiased Paint for a solid color.
  static Paint col(int color) => Paint()
    ..color = Color(color)
    ..isAntiAlias = false;

  @override
  void paintCharacter(Canvas canvas, PixelGrid g) {
    _drawAura(canvas, g);
    _drawShadow(canvas, g);
    _drawLegs(canvas, g);
    _drawRobe(canvas, g);
    _drawPouch(canvas, g);
    _drawArms(canvas, g);
    _drawHead(canvas, g);
    _drawSword(canvas, g);
    _drawSpeechBubble(canvas, g);
  }

  // --- Aura rings during thinking / speaking ---
  void _drawAura(Canvas c, PixelGrid g) {
    if (mood != PixelMood.thinking && mood != PixelMood.speaking) return;
    final alpha = mood == PixelMood.speaking ? 0.25 : 0.18;
    final p = Paint()
      ..color = _trim.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.px * 0.8
      ..isAntiAlias = false;

    final cy = 16;
    g.circle(c, p, 16, cy, 17 + (animPhase * 3).round());
    final p2 = Paint()
      ..color = _trim.withValues(alpha: alpha * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.px * 0.5
      ..isAntiAlias = false;
    g.circle(c, p2, 16, cy, 14 - (animPhase * 3).round() % 3);
  }

  void _drawShadow(Canvas c, PixelGrid g) {
    final p = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.15)
      ..isAntiAlias = false;
    g.rect(c, p, 9, 29, 14, 2);
  }

  void _drawLegs(Canvas c, PixelGrid g) {
    g.rect(c, col(0xFF332211), 12, 25, 3, 5);
    g.rect(c, col(0xFF332211), 17, 25, 3, 5);
    g.rect(c, col(0xFF1A1A1A), 11, 29, 4, 2);
    g.rect(c, col(0xFF1A1A1A), 17, 29, 4, 2);
  }

  void _drawRobe(Canvas c, PixelGrid g) {
    final bodyRows = [
      [10, 21, 3, 8],
      [10, 20, 4, 0],
      [9, 19, 5, 0],
      [9, 18, 5, 0],
      [8, 17, 6, 0],
      [8, 16, 6, 0],
      [8, 15, 7, 0],
      [8, 14, 8, 0],
      [7, 13, 9, 0],
      [7, 12, 10, 0],
      [6, 11, 11, 0],
      [6, 10, 11, 0],
      [5, 9, 12, 0],
      [5, 8, 13, 0],
      [5, 7, 14, 24],
    ];

    for (int i = 0; i < bodyRows.length; i++) {
      final row = bodyRows[i];
      final y = row[0];
      final height = row[1] - row[0];
      if (height <= 0) continue;

      final shade = i / bodyRows.length;
      final color = Color.lerp(_robeLight, _robeDark, shade) ?? _robe;
      final p = Paint()..color = color..isAntiAlias = false;
      g.rect(c, p, row[2], y, row[3], height > 0 ? height : 1);
    }

    // Center fold line
    final foldP = Paint()
      ..color = _robeDark.withValues(alpha: 0.3)
      ..isAntiAlias = false;
    g.rect(c, foldP, 15, 10, 1, 14);

    // Belt / sash
    g.rect(c, col(_trim.value), 7, 13, 18, 2);
  }

  void _drawPouch(Canvas c, PixelGrid g) {
    g.rect(c, col(0xFF8B6914), 7, 14, 3, 3);
    // Drawstring
    g.dot(c, col(0xFFDAA520), 8, 15);
    // Pouch highlight
    g.dot(c, col(0xFFDAA520), 8, 14);
  }

  void _drawArms(Canvas c, PixelGrid g) {
    final leftLift = mood == PixelMood.thinking ? -2 : 0;
    g.rect(c, col(_robeDark.value), 5, 10 + leftLift, 3, 7);
    g.rect(c, col(_robe.value), 6, 9 + leftLift, 2, 5);
    g.rect(c, col(_skin.value), 7, 16 + leftLift, 2, 2);

    final rightWave = mood == PixelMood.speaking ? (animPhase * 2).round() - 1 : 0;
    g.rect(c, col(_robeDark.value), 24, 10 + rightWave, 3, 7);
    g.rect(c, col(_skin.value), 22, 16 + rightWave, 2, 2);

    g.rect(c, col(_trim.value), 5, 16 + leftLift, 3, 1);
    g.rect(c, col(_trim.value), 24, 16 + rightWave, 3, 1);
  }

  void _drawHead(Canvas c, PixelGrid g) {
    final headCx = 16;

    // Hair
    final hairP = col(_hair.value);
    g.rect(c, hairP, 12, 0, 8, 2);
    g.rect(c, hairP, 12, 0, 9, 1);
    g.rect(c, hairP, 11, 2, 10, 5);

    // Topknot
    g.rect(c, hairP, 14, 0, 4, 2);
    g.dot(c, col(0xFF333333), 15, 0);

    // Face
    g.rect(c, col(_skin.value), 13, 3, 6, 5);

    // Eyes
    drawEyes(c, g, headCx, 5, 2);

    // Eyebrows
    final browP = col(0xFF333333);
    g.rect(c, browP, 13, 4, 2, 1);
    g.rect(c, browP, 17, 4, 2, 1);

    // Nose
    g.dot(c, col(0xFFE6B88A), headCx, 6);

    // Mouth
    drawMouth(c, g, headCx, 7);

    // Cheek blush when speaking
    if (mood == PixelMood.speaking) {
      final blush = Paint()
        ..color = const Color(0xFFFFAAAA).withValues(alpha: 0.3)
        ..isAntiAlias = false;
      g.dot(c, blush, 12, 6);
      g.dot(c, blush, 19, 6);
    }
  }

  void _drawSword(Canvas c, PixelGrid g) {
    final sx = 26;
    final sy = 22;
    final floatOffset = (math.sin(animPhase * math.pi * 2) * 2).round();

    // Sword blade
    final bladeP = Paint()
      ..color = _sword
      ..isAntiAlias = false;
    g.rect(c, bladeP, sx, sy - 4 + floatOffset, 1, 6);

    // Sword glow
    if (mood == PixelMood.thinking || mood == PixelMood.speaking) {
      final glowP = Paint()
        ..color = _swordGlow
        ..isAntiAlias = false;
      g.rect(c, glowP, sx - 1, sy - 5 + floatOffset, 3, 8);
    }

    // Hilt + guard
    g.rect(c, col(0xFF8B4513), sx - 1, sy + 2 + floatOffset, 3, 1);
    g.rect(c, col(_trim.value), sx - 1, sy + 1 + floatOffset, 3, 1);

    // Pommel gem
    g.dot(c, col(_trim.value), sx, sy + 3 + floatOffset);
  }

  void _drawSpeechBubble(Canvas c, PixelGrid g) {
    if (mood == PixelMood.speaking) {
      final dotGap = animPhase < 0.33 ? 0 : animPhase < 0.66 ? 1 : 2;
      for (int i = 0; i <= dotGap; i++) {
        g.dot(c, col(_trim.value), 12 + i * 3, -2);
      }
    } else if (mood == PixelMood.thinking) {
      final p1 = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6)
        ..isAntiAlias = false;
      final p2 = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4)
        ..isAntiAlias = false;
      g.rect(c, p1, 13, -2, 2, 1);
      g.rect(c, p2, 11, -3, 3, 1);
    }
  }
}
