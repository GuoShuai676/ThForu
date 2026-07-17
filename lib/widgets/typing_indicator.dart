import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            final phase = (_controller.value * 3.0 - i * 0.8) % 3.0;
            final t = phase < 0
                ? 0.0
                : (phase > 1.0
                    ? (phase < 2.0 ? 1.0 - (phase - 1.0) : 0.0)
                    : phase);
            final smooth = t * t * (3.0 - 2.0 * t);
            final y = -7.0 * smooth;
            final scale = 0.85 + 0.15 * smooth;
            final alpha = 0.35 + 0.65 * smooth;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: alpha),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
