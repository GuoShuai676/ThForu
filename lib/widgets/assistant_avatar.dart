import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AssistantState { idle, listening, thinking, streaming }

class AssistantAvatar extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? name;
  final double size;
  final AssistantState state;

  const AssistantAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.name,
    this.size = 38,
    this.state = AssistantState.idle,
  });

  @override
  State<AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<AssistantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.state != AssistantState.idle) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(AssistantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (widget.state == AssistantState.idle) {
        _ctrl.stop();
        _ctrl.reset();
      } else if (!_ctrl.isAnimating) {
        _ctrl.repeat();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final hsl = HSLColor.fromColor(base);
    final lighter =
        hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final darker =
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final active = widget.state != AssistantState.idle;
          final glow =
              active ? 0.3 + 0.2 * math.sin(_ctrl.value * 2 * math.pi) : 0.0;
          final scale =
              active ? 1.0 + 0.05 * math.sin(_ctrl.value * 2 * math.pi) : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Container(
                  width: widget.size + 8,
                  height: widget.size + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: base.withValues(alpha: glow),
                  ),
                ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [lighter, darker],
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: base.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(widget.icon,
                      size: widget.size * 0.5, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
