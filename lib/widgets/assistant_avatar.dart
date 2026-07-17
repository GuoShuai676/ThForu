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

  const AssistantAvatar.defaults({
    super.key,
    this.name,
    this.size = 38,
    this.state = AssistantState.idle,
  })  : icon = Icons.smart_toy,
        color = const Color(0xFF6366F1);

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

  Color get _baseColor => widget.color;

  List<Color> get _gradientColors {
    final hsl = HSLColor.fromColor(_baseColor);
    return [
      hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final isActive = widget.state != AssistantState.idle;
        final breathe = isActive ? (math.sin(_ctrl.value * 2 * math.pi) * 0.06 + 1.0) : 1.0;
        final glowOpacity = isActive ? (0.2 + 0.15 * math.sin(_ctrl.value * 2 * math.pi)) : 0.0;
        final rotate = widget.state == AssistantState.thinking
            ? math.sin(_ctrl.value * 2 * math.pi) * 0.08
            : 0.0;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _baseColor.withValues(alpha: glowOpacity),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              Transform.scale(
                scale: breathe,
                child: Transform.rotate(
                  angle: rotate,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _baseColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: widget.size * 0.48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AssistantLabel extends StatelessWidget {
  final String name;
  final Color color;

  const AssistantLabel({
    super.key,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        name,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
