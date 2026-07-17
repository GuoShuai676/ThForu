import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/companion_config.dart';
import '../../state/providers.dart';
import 'pixel_painter.dart';
import 'hanli_skin.dart';

// =============================================================================
// Pixel Companion — core widget
// =============================================================================

/// An overlay-based pixel-art companion that floats above the chat screen.
///
/// Features:
/// - State machine driven by [PixelMood]
/// - Pixel-art rendering with [HanLiPainter] (extensible via skin system)
/// - Drag-to-move with edge snapping
/// - Tap to show quick menu
/// - Position persistence via [CompanionConfig]
/// - Auto-sleep after inactivity
class PixelCompanion extends ConsumerStatefulWidget {
  /// Current AI state — drives the companion's mood.
  final PixelMood mood;
  /// Chat screen size (used for position clamping).
  final Size screenSize;
  /// Padding to avoid (e.g. input bar + nav bar area).
  final EdgeInsets safePadding;
  /// Called when the user taps a quick-menu action.
  final void Function(String action)? onQuickAction;

  const PixelCompanion({
    super.key,
    this.mood = PixelMood.idle,
    required this.screenSize,
    this.safePadding = EdgeInsets.zero,
    this.onQuickAction,
  });

  @override
  ConsumerState<PixelCompanion> createState() => _PixelCompanionState();
}

class _PixelCompanionState extends ConsumerState<PixelCompanion>
    with TickerProviderStateMixin {
  // ---- Animation controllers ----
  late final AnimationController _breathCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _moodCtrl; // mood transition

  // ---- Drag state ----
  OverlayEntry? _overlayEntry;
  Offset _position = Offset.zero;
  bool _isDragging = false;
  bool _docked = true;

  // ---- Idle timer ----
  Timer? _idleTimer;
  static const _idleTimeout = Duration(seconds: 30);

  // ---- Quick menu ----
  bool _showMenu = false;

  // ---- Blink loop ----
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _moodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _startBlinkLoop();
    _resetIdleTimer();
    _restorePosition();
  }

  void _restorePosition() {
    final config = ref.read(companionConfigProvider);
    final savedX = config.savedPositionX;
    final savedY = config.savedPositionY;
    if (savedX != null && savedY != null) {
      _position = Offset(savedX, savedY);
      _docked = true;
    } else {
      _position = _defaultPosition();
    }
  }

  Offset _defaultPosition() {
    final size = widget.screenSize;
    final companionSize = _companionSize;
    return Offset(
      size.width - companionSize - 12,
      size.height - companionSize * 1.6 - widget.safePadding.bottom - 76,
    );
  }

  double get _companionSize => ref.read(companionConfigProvider).size;

  void _startBlinkLoop() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(
      Duration(seconds: 2 + math.Random().nextInt(4)),
      (_) {
        if (!mounted) return;
        _blinkCtrl.forward().then((_) {
          if (mounted) _blinkCtrl.reverse();
        });
      },
    );
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted && widget.mood == PixelMood.idle) {
        // Transition to sleeping will happen via mood change from outside
      }
    });
  }

  // ---- Mood sync ----
  @override
  void didUpdateWidget(PixelCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood != oldWidget.mood) {
      _resetIdleTimer();
    }
  }

  // ---- Drag handling ----
  void _onDragStart(DragStartDetails d) {
    setState(() {
      _isDragging = true;
      _showMenu = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _position += d.delta;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    _isDragging = false;
    _snapToEdge();
    _savePosition();
  }

  void _snapToEdge() {
    final size = widget.screenSize;
    final companionSize = _companionSize;
    final padding = widget.safePadding;
    const margin = 12.0;

    final dockLeft = _position.dx + companionSize / 2 < size.width / 2;
    final targetX = dockLeft
        ? margin
        : size.width - companionSize - margin;
    final targetY = _position.dy.clamp(
      margin + padding.top,
      size.height - companionSize * 1.6 - padding.bottom - 76,
    );

    setState(() {
      _position = Offset(targetX, targetY);
      _docked = true;
    });
  }

  void _savePosition() {
    ref
        .read(companionConfigProvider.notifier)
        .savePosition(_position.dx, _position.dy);
  }

  void _onDoubleTap() {
    _snapToEdge();
    _savePosition();
  }

  // ---- Quick menu ----
  void _toggleMenu() {
    if (_isDragging) return;
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _dismissMenu() {
    if (_showMenu) setState(() => _showMenu = false);
  }

  // ---- Rendering ----
  PixelMood _effectiveMood() {
    if (_isDragging) return PixelMood.dragging;
    return widget.mood;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(companionConfigProvider);
    if (!config.enabled) return const SizedBox.shrink();

    final effectiveMood = _effectiveMood();
    final companionSize = config.size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      width: companionSize,
      height: companionSize * 1.6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        onPanEnd: _onDragEnd,
        onDoubleTapDown: (_) => _onDoubleTap(),
        onTap: _toggleMenu,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pixel character
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_breathCtrl, _blinkCtrl, _floatCtrl, _moodCtrl]),
              builder: (context, _) {
                final floatY =
                    math.sin(_floatCtrl.value * 2 * math.pi) * 3;
                final breath = 1.0 + _breathCtrl.value * 0.025;

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: SizedBox(
                    width: companionSize,
                    height: companionSize * 1.5,
                    child: CustomPaint(
                      painter: HanLiPainter(
                        mood: effectiveMood,
                        breathValue: breath,
                        blinkValue: _blinkCtrl.value,
                        animPhase: _floatCtrl.value,
                        primaryColor: config.primaryColor,
                        accentColor: config.accentColor,
                        skinColor: config.skinColor,
                        hairColor: config.hairColor,
                        name: config.showName ? config.name : null,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Name tag
            if (config.showName && config.name.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      config.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

            // Quick menu
            if (_showMenu && !_isDragging)
              Positioned(
                top: companionSize * 0.3,
                right: -130,
                child: _QuickMenu(
                  config: config,
                  onAction: (action) {
                    _dismissMenu();
                    widget.onQuickAction?.call(action);
                  },
                  onDismiss: _dismissMenu,
                ),
              ),

            // Drag indicator when docked
            if (_docked && !_isDragging)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _blinkCtrl.dispose();
    _floatCtrl.dispose();
    _moodCtrl.dispose();
    _idleTimer?.cancel();
    _blinkTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }
}

// =============================================================================
// Quick Menu
// =============================================================================

class _QuickMenu extends StatelessWidget {
  final CompanionConfig config;
  final void Function(String action) onAction;
  final VoidCallback onDismiss;

  const _QuickMenu({
    required this.config,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _MenuItem(icon: Icons.chat, label: '聊天', action: 'chat'),
      _MenuItem(icon: Icons.auto_awesome, label: '技能', action: 'skills'),
      _MenuItem(icon: Icons.settings, label: '设置', action: 'settings'),
      _MenuItem(icon: Icons.visibility_off, label: '隐藏', action: 'hide'),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onAction(item.action),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String action;
  const _MenuItem({required this.icon, required this.label, required this.action});
}
