import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CompanionMood { idle, thinking, streaming, sleeping, happy, surprised }

enum CompanionVisualStyle { codex, hanLi }

class CompanionCharacter extends StatefulWidget {
  final CompanionMood mood;
  final Color color;
  final Color accentColor;
  final double size;
  final String? name;
  final bool showName;
  final CompanionVisualStyle visualStyle;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  const CompanionCharacter({
    super.key,
    this.mood = CompanionMood.idle,
    this.color = const Color(0xFF6366F1),
    this.accentColor = const Color(0xFF8B5CF6),
    this.size = 70,
    this.name,
    this.showName = true,
    this.visualStyle = CompanionVisualStyle.codex,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<CompanionCharacter> createState() => _CompanionCharacterState();
}

class _CompanionCharacterState extends State<CompanionCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _armCtrl;

  CompanionMood _currentMood = CompanionMood.idle;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
    _armCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _startBlinkLoop();
  }

  void _startBlinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: 2 + math.Random().nextInt(4)));
      if (!mounted || _currentMood == CompanionMood.sleeping) continue;
      _blinkCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 130));
      if (!mounted) return;
      _blinkCtrl.reverse();
    }
  }

  @override
  void didUpdateWidget(CompanionCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != oldWidget.mood) {
      _currentMood = widget.mood;
      if (widget.mood == CompanionMood.happy ||
          widget.mood == CompanionMood.streaming) {
        _bounceCtrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _blinkCtrl.dispose();
    _bounceCtrl.dispose();
    _floatCtrl.dispose();
    _armCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_breathCtrl, _blinkCtrl, _bounceCtrl, _floatCtrl, _armCtrl]),
      builder: (context, _) {
        final floatY = math.sin(_floatCtrl.value * 2 * math.pi) * 4;
        final bounceY = _bounceCtrl.isAnimating
            ? -math.sin(_bounceCtrl.value * math.pi) * 14
            : 0.0;
        final breath = 1.0 + _breathCtrl.value * 0.025;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: widget.onDragUpdate,
          onPanEnd: widget.onDragEnd,
          onTap: () {
            setState(() => _currentMood = CompanionMood.happy);
            _bounceCtrl.forward(from: 0);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _currentMood = widget.mood);
            });
          },
          child: Transform.translate(
            offset: Offset(0, floatY + bounceY),
            child: SizedBox(
              width: widget.size,
              height: widget.size * 1.5,
              child: CustomPaint(
                painter: _CharacterPainter(
                  color: widget.color,
                  accentColor: widget.accentColor,
                  mood: _currentMood,
                  breathScale: breath,
                  blinkValue: _blinkCtrl.value,
                  armWave: _armCtrl.isAnimating
                      ? math.sin(_armCtrl.value * math.pi * 2) * 0.6
                      : 0.0,
                  name: widget.showName ? widget.name : null,
                  visualStyle: widget.visualStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final CompanionMood mood;
  final double breathScale;
  final double blinkValue;
  final double armWave;
  final String? name;
  final CompanionVisualStyle visualStyle;

  _CharacterPainter({
    required this.color,
    required this.accentColor,
    required this.mood,
    required this.breathScale,
    required this.blinkValue,
    required this.armWave,
    this.name,
    required this.visualStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final s = size.width;
    final headR = s * 0.32;
    final headY = s * 0.32;
    final bodyY = headY + headR + s * 0.04;
    final bodyRx = s * 0.22;
    final bodyRy = s * 0.18;

    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    if (visualStyle == CompanionVisualStyle.hanLi) {
      _paintHanLi(canvas, size, cx, s, headR, headY, bodyY, bodyRx, bodyRy,
          light, dark);
      return;
    }

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, size.height * 0.96),
          width: s * 0.45,
          height: s * 0.04),
      Paint()..color = color.withValues(alpha: 0.2),
    );

    // --- Legs ---
    final legPaint = Paint()
      ..color = dark
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;
    final legSpread = s * 0.09;
    final legTop = bodyY + bodyRy * 0.65;
    final legBot = size.height * 0.92;
    canvas.drawLine(Offset(cx - legSpread, legTop),
        Offset(cx - legSpread, legBot), legPaint);
    canvas.drawLine(Offset(cx + legSpread, legTop),
        Offset(cx + legSpread, legBot), legPaint);
    // Feet
    final feetPaint = Paint()..color = dark;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - legSpread, legBot + 2),
            width: s * 0.09,
            height: s * 0.035),
        feetPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + legSpread, legBot + 2),
            width: s * 0.09,
            height: s * 0.035),
        feetPaint);

    // --- Body ---
    canvas.save();
    canvas.translate(cx, bodyY);
    canvas.scale(breathScale);
    final bodyGrad =
        RadialGradient(colors: [light, color], center: Alignment.topLeft)
            .createShader(Rect.fromCenter(
                center: Offset.zero, width: bodyRx * 2, height: bodyRy * 2));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: bodyRx * 2, height: bodyRy * 2),
        Paint()..shader = bodyGrad);
    // Belly highlight
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, bodyRy * 0.15),
          width: bodyRx * 0.8,
          height: bodyRy * 0.6),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();

    // --- Arms ---
    final armPaint = Paint()
      ..color = color
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    final armLen = s * 0.18;
    // Left arm
    final la = -0.4 + armWave * 0.4;
    canvas.drawLine(
      Offset(cx - bodyRx * 0.85, bodyY),
      Offset(cx - bodyRx * 0.85 - math.cos(la) * armLen,
          bodyY + math.sin(la) * armLen),
      armPaint,
    );
    // Right arm
    final ra = mood == CompanionMood.thinking ? -1.3 : (-0.4 - armWave * 0.6);
    canvas.drawLine(
      Offset(cx + bodyRx * 0.85, bodyY),
      Offset(cx + bodyRx * 0.85 + math.cos(ra) * armLen,
          bodyY + math.sin(ra) * armLen),
      armPaint,
    );

    // --- Head ---
    canvas.save();
    canvas.translate(cx, headY);
    canvas.scale(breathScale);
    final headGrad =
        RadialGradient(colors: [light, color], center: Alignment.topLeft)
            .createShader(Rect.fromCenter(
                center: Offset.zero, width: headR * 2, height: headR * 2));
    canvas.drawCircle(Offset.zero, headR, Paint()..shader = headGrad);
    // Head highlight
    canvas.drawCircle(Offset(-headR * 0.2, -headR * 0.25), headR * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.15));

    // --- Cheeks ---
    final cheekPaint = Paint()..color = Colors.pink.withValues(alpha: 0.25);
    canvas.drawCircle(
        Offset(-headR * 0.55, headR * 0.2), headR * 0.13, cheekPaint);
    canvas.drawCircle(
        Offset(headR * 0.55, headR * 0.2), headR * 0.13, cheekPaint);

    // --- Eyes ---
    final eyeY = -headR * 0.05;
    final eyeX = headR * 0.32;
    final eyeR = headR * 0.11;

    if (mood == CompanionMood.sleeping) {
      final ep = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(-eyeX - eyeR, eyeY), Offset(-eyeX + eyeR, eyeY), ep);
      canvas.drawLine(Offset(eyeX - eyeR, eyeY), Offset(eyeX + eyeR, eyeY), ep);
    } else if (mood == CompanionMood.surprised) {
      final ep = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(-eyeX, eyeY), eyeR * 1.6, ep);
      canvas.drawCircle(Offset(eyeX, eyeY), eyeR * 1.6, ep);
      canvas.drawCircle(Offset(-eyeX, eyeY), eyeR * 0.8,
          Paint()..color = const Color(0xFF1A1A2E));
      canvas.drawCircle(Offset(eyeX, eyeY), eyeR * 0.8,
          Paint()..color = const Color(0xFF1A1A2E));
    } else {
      final eyeH = eyeR * (1.0 - blinkValue);
      if (eyeH > 0.5) {
        final ep = Paint()..color = Colors.white;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(-eyeX, eyeY), width: eyeR * 2, height: eyeH * 2),
            ep);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(eyeX, eyeY), width: eyeR * 2, height: eyeH * 2),
            ep);
        final pp = Paint()..color = const Color(0xFF1A1A2E);
        final po = mood == CompanionMood.thinking ? 2.0 : 0.0;
        canvas.drawCircle(Offset(-eyeX + po, eyeY), eyeR * 0.55, pp);
        canvas.drawCircle(Offset(eyeX + po, eyeY), eyeR * 0.55, pp);
        canvas.drawCircle(Offset(-eyeX + po - 1, eyeY - 1), eyeR * 0.2,
            Paint()..color = Colors.white);
        canvas.drawCircle(Offset(eyeX + po - 1, eyeY - 1), eyeR * 0.2,
            Paint()..color = Colors.white);
      }
    }

    // --- Mouth ---
    final mouthY = headR * 0.35;
    final mp = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (mood) {
      case CompanionMood.happy:
      case CompanionMood.streaming:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(0, mouthY - 3),
                width: headR * 0.45,
                height: headR * 0.35),
            0.1 * math.pi,
            0.8 * math.pi,
            false,
            mp);
      case CompanionMood.thinking:
        canvas.drawCircle(Offset(headR * 0.05, mouthY), headR * 0.06,
            Paint()..color = Colors.white);
      case CompanionMood.surprised:
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(0, mouthY + 2),
                width: headR * 0.2,
                height: headR * 0.22),
            Paint()..color = Colors.white);
      case CompanionMood.sleeping:
        final zp = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(headR * 0.5, -headR * 0.75),
            Offset(headR * 0.7, -headR * 0.75), zp);
        canvas.drawLine(Offset(headR * 0.7, -headR * 0.75),
            Offset(headR * 0.5, -headR * 0.55), zp);
        canvas.drawLine(Offset(headR * 0.5, -headR * 0.55),
            Offset(headR * 0.7, -headR * 0.55), zp);
      case CompanionMood.idle:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(0, mouthY),
                width: headR * 0.3,
                height: headR * 0.18),
            0.1 * math.pi,
            0.8 * math.pi,
            false,
            mp);
    }

    canvas.restore();

    // --- Name tag ---
    if (name != null && name!.isNotEmpty && s >= 80) {
      final tp = TextPainter(
        text: TextSpan(
            text: name,
            style: TextStyle(
                color: Colors.white,
                fontSize: s * 0.11,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      final tagX = cx - tp.width / 2;
      final tagY = s * 0.01;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(tagX - 4, tagY, tp.width + 8, tp.height + 4),
            const Radius.circular(5)),
        Paint()..color = color.withValues(alpha: 0.75),
      );
      tp.paint(canvas, Offset(tagX, tagY + 2));
    }
  }

  void _paintHanLi(
    Canvas canvas,
    Size size,
    double cx,
    double s,
    double headR,
    double headY,
    double bodyY,
    double bodyRx,
    double bodyRy,
    Color light,
    Color dark,
  ) {
    final robe = color;
    final robeDark =
        HSLColor.fromColor(robe).withLightness(0.24).toColor();
    final skin = const Color(0xFFFFD9B3);
    final hair = const Color(0xFF161616);
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..color = accentColor.withValues(alpha: 0.32);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.96),
        width: s * 0.56,
        height: s * 0.05,
      ),
      Paint()..color = robeDark.withValues(alpha: 0.2),
    );

    if (mood == CompanionMood.streaming || mood == CompanionMood.happy) {
      canvas.drawCircle(Offset(cx, bodyY), s * 0.46, auraPaint);
      canvas.drawCircle(
        Offset(cx, bodyY),
        s * 0.36,
        auraPaint..color = accentColor.withValues(alpha: 0.22),
      );
    }

    final swordPaint = Paint()
      ..color = const Color(0xFFC9D4DD)
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + s * 0.25, bodyY - s * 0.18),
      Offset(cx + s * 0.42, bodyY + s * 0.34),
      swordPaint,
    );
    canvas.drawLine(
      Offset(cx + s * 0.23, bodyY - s * 0.1),
      Offset(cx + s * 0.33, bodyY - s * 0.13),
      Paint()
        ..color = accentColor
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round,
    );

    canvas.save();
    canvas.translate(cx, bodyY);
    canvas.scale(breathScale);
    final robePath = Path()
      ..moveTo(-bodyRx * 0.95, -bodyRy * 0.55)
      ..quadraticBezierTo(0, -bodyRy * 1.15, bodyRx * 0.95, -bodyRy * 0.55)
      ..lineTo(bodyRx * 1.3, bodyRy * 1.95)
      ..quadraticBezierTo(0, bodyRy * 2.35, -bodyRx * 1.3, bodyRy * 1.95)
      ..close();
    canvas.drawPath(
      robePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, robe, robeDark],
        ).createShader(Rect.fromCenter(
          center: Offset.zero,
          width: bodyRx * 3,
          height: bodyRy * 4,
        )),
    );
    canvas.drawLine(
      Offset(-bodyRx * 0.6, -bodyRy * 0.25),
      Offset(bodyRx * 0.78, bodyRy * 1.45),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(0, bodyRy * 0.72),
      s * 0.035,
      Paint()..color = accentColor,
    );
    canvas.restore();

    final armPaint = Paint()
      ..color = robe
      ..strokeWidth = s * 0.052
      ..strokeCap = StrokeCap.round;
    final armLift = mood == CompanionMood.thinking ? -0.16 : 0.0;
    canvas.drawLine(
      Offset(cx - bodyRx * 0.86, bodyY - bodyRy * 0.2),
      Offset(cx - bodyRx * 1.35, bodyY + bodyRy * (0.62 + armLift)),
      armPaint,
    );
    canvas.drawLine(
      Offset(cx + bodyRx * 0.82, bodyY - bodyRy * 0.2),
      Offset(cx + bodyRx * 1.26, bodyY + bodyRy * (0.56 - armWave * 0.2)),
      armPaint,
    );

    canvas.save();
    canvas.translate(cx, headY);
    canvas.scale(breathScale);
    canvas.drawCircle(Offset(0, -headR * 0.88), headR * 0.18,
        Paint()..color = hair);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -headR * 0.12),
          width: headR * 1.78,
          height: headR * 1.94),
      Paint()..color = hair,
    );
    canvas.drawCircle(Offset.zero, headR * 0.78, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(0, -headR * 0.08),
          width: headR * 1.62,
          height: headR * 1.35),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = hair
        ..strokeWidth = headR * 0.38
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(-headR * 0.2, -headR * 0.1),
      headR * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    _paintEyesAndMouth(canvas, headR);
    canvas.restore();

    if (name != null && name!.isNotEmpty) {
      _paintNameTag(canvas, size, cx, s);
    }
  }

  void _paintEyesAndMouth(Canvas canvas, double headR) {
    final eyeY = -headR * 0.02;
    final eyeX = headR * 0.28;
    final eyeR = headR * 0.08;
    final eyePaint = Paint()..color = const Color(0xFF20202A);

    if (mood == CompanionMood.sleeping) {
      final ep = Paint()
        ..color = const Color(0xFF20202A)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(-eyeX - eyeR, eyeY), Offset(-eyeX + eyeR, eyeY), ep);
      canvas.drawLine(Offset(eyeX - eyeR, eyeY), Offset(eyeX + eyeR, eyeY), ep);
    } else {
      final eyeH = eyeR * (1.0 - blinkValue);
      if (eyeH > 0.5) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(-eyeX, eyeY), width: eyeR * 1.5, height: eyeH * 2),
            eyePaint);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(eyeX, eyeY), width: eyeR * 1.5, height: eyeH * 2),
            eyePaint);
      }
    }

    final mouthPaint = Paint()
      ..color = const Color(0xFF9A4E3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final mouthY = headR * 0.34;
    if (mood == CompanionMood.surprised) {
      canvas.drawCircle(Offset(0, mouthY), headR * 0.06,
          Paint()..color = const Color(0xFF9A4E3F));
    } else {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(0, mouthY - 1),
            width: headR * 0.28,
            height: headR * 0.18),
        0.12 * math.pi,
        0.76 * math.pi,
        false,
        mouthPaint,
      );
    }
  }

  void _paintNameTag(Canvas canvas, Size size, double cx, double s) {
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.12,
              fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tagX = cx - tp.width / 2;
    final tagY = s * 0.02;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(tagX - 6, tagY, tp.width + 12, tp.height + 5),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFF111827).withValues(alpha: 0.68),
    );
    tp.paint(canvas, Offset(tagX, tagY + 2));
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.mood != mood ||
      old.color != color ||
      old.accentColor != accentColor ||
      old.visualStyle != visualStyle ||
      old.name != name ||
      old.breathScale != breathScale ||
      old.blinkValue != blinkValue ||
      old.armWave != armWave;
}
