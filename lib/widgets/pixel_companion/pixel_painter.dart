import 'package:flutter/material.dart';

/// Pixel-art rendering primitives.
///
/// All drawing is done on a virtual grid of [gridSize] × [gridSize] cells
/// and scaled up with nearest-neighbor filtering (no anti-aliasing).
class PixelGrid {
  final int gridSize;
  final double px; // size of one pixel in logical coordinates

  PixelGrid({required this.gridSize, required double canvasSize})
      : px = canvasSize / gridSize;

  /// Draw a filled rectangle in grid coordinates.
  void rect(Canvas c, Paint p, int x, int y, int w, int h) {
    c.drawRect(
      Rect.fromLTWH(x * px, y * px, w * px, h * px),
      p,
    );
  }

  /// Draw a circle in grid coordinates.
  void circle(Canvas c, Paint p, int cx, int cy, int r) {
    c.drawCircle(Offset(cx * px, cy * px), r * px, p);
  }

  /// Draw a line in grid coordinates.
  void line(Canvas c, Paint p, int x1, int y1, int x2, int y2) {
    c.drawLine(
      Offset(x1 * px, y1 * px),
      Offset(x2 * px, y2 * px),
      p,
    );
  }

  /// Draw a single pixel-sized block.
  void dot(Canvas c, Paint p, int x, int y) {
    c.drawRect(
      Rect.fromLTWH(x * px, y * px, px, px),
      p,
    );
  }
}

/// Companion mood / state enum.
enum PixelMood {
  idle,
  thinking,
  speaking,
  toolRunning,
  error,
  dragging,
  sleeping,
}

/// Core pixel-art character painter.
///
/// Renders a character on a 32×32 grid.  Uses [PixelGrid] to map grid
/// coordinates to canvas coordinates.  Subclasses override [paintCharacter]
/// to draw the actual sprite.
///
/// The painter does NOT apply [FilterQuality.none] itself — that must be
/// set on the [Paint] objects or the [Canvas] by the caller (see
/// [PixelCompanionWidget]).
abstract class PixelCharacterPainter extends CustomPainter {
  final PixelMood mood;
  final double breathValue;  // 0→1 cyclical
  final double blinkValue;   // 0→1 (1 = fully closed)
  final double animPhase;    // 0→1 for special animations
  final int primaryColor;
  final int accentColor;
  final int skinColor;
  final int hairColor;
  final String? name;

  static const int gridSize = 32;

  PixelCharacterPainter({
    this.mood = PixelMood.idle,
    this.breathValue = 0.5,
    this.blinkValue = 0.0,
    this.animPhase = 0.0,
    this.primaryColor = 0xFF2F7D57,
    this.accentColor = 0xFFD6A84F,
    this.skinColor = 0xFFFFD9B3,
    this.hairColor = 0xFF161616,
    this.name,
  });

  PixelGrid get grid => PixelGrid(gridSize: gridSize, canvasSize: gridSize.toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the grid to the actual canvas size.
    final scale = size.width / gridSize;
    canvas.save();
    canvas.scale(scale, scale);

    // Disable anti-aliasing for crisp pixels.
    // (Paint objects can also set isAntiAlias = false individually.)
    paintCharacter(canvas, grid);

    canvas.restore();
  }

  /// Subclasses implement this to draw the character on the grid.
  void paintCharacter(Canvas canvas, PixelGrid g);

  /// Shorthand for creating a paint with a color value.
  Paint _color(int colorValue) => Paint()
    ..color = Color(colorValue)
    ..isAntiAlias = false;

  /// Common helper: draw eyes on the grid.
  void drawEyes(Canvas c, PixelGrid g, int cx, int eyeY, int eyeSpacing) {
    final isSleeping = mood == PixelMood.sleeping;
    final isClosed = blinkValue > 0.85;
    final closed = isSleeping || isClosed;

    final leftEyeX = cx - eyeSpacing;
    final rightEyeX = cx + eyeSpacing;

    if (closed) {
      // Closed = horizontal line
      final ep = _color(0xFF1A1A2E)..strokeWidth = g.px * 0.6;
      g.line(c, ep, leftEyeX - 2, eyeY, leftEyeX + 2, eyeY);
      g.line(c, ep, rightEyeX - 2, eyeY, rightEyeX + 2, eyeY);
    } else {
      // Open eye
      final eyeH = ((1.0 - blinkValue) * 3).round().clamp(1, 3);
      g.rect(c, _color(0xFFFFFFFF), leftEyeX - 2, eyeY - 1, 4, eyeH + 1);
      g.rect(c, _color(0xFFFFFFFF), rightEyeX - 2, eyeY - 1, 4, eyeH + 1);
      // Pupil
      g.dot(c, _color(0xFF1A1A2E), leftEyeX, eyeY);
      g.dot(c, _color(0xFF1A1A2E), rightEyeX, eyeY);
      // Highlight
      g.dot(c, _color(0xFFFFFFFF), leftEyeX - 1, eyeY - 1);
      g.dot(c, _color(0xFFFFFFFF), rightEyeX - 1, eyeY - 1);
    }
  }

  /// Draw mouth based on mood.
  void drawMouth(Canvas c, PixelGrid g, int cx, int my) {
    switch (mood) {
      case PixelMood.speaking:
        g.rect(c, _color(0xFF9A4E3F), cx - 2, my, 4, 3);
      case PixelMood.thinking:
        g.dot(c, _color(0xFF9A4E3F), cx, my + 1);
      case PixelMood.error:
        g.rect(c, _color(0xFF9A4E3F), cx - 1, my + 1, 3, 1);
      case PixelMood.idle:
        g.rect(c, _color(0xFF9A4E3F), cx - 1, my, 2, 1);
      case PixelMood.sleeping:
        // open mouth, small 'z' implied
        g.dot(c, _color(0xFF9A4E3F), cx, my);
      case PixelMood.dragging:
      case PixelMood.toolRunning:
        g.rect(c, _color(0xFF9A4E3F), cx - 1, my, 2, 2);
    }
  }

  /// Draw a simple name tag above the character — rendered by the overlay layer.
  void drawNameTag(Canvas c, PixelGrid g, String text) {
    // Name rendering is handled by the Overlay widget layer outside the
    // pixel grid, so the tag can use system fonts at proper resolution.
  }

  @override
  bool shouldRepaint(covariant PixelCharacterPainter old) =>
      mood != old.mood ||
      breathValue != old.breathValue ||
      blinkValue != old.blinkValue ||
      animPhase != old.animPhase ||
      primaryColor != old.primaryColor ||
      accentColor != old.accentColor ||
      skinColor != old.skinColor ||
      hairColor != old.hairColor ||
      name != old.name;
}
