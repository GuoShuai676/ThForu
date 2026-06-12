import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../state/formula_display_notifier.dart';

/// Fullscreen, landscape-oriented formula viewer with pinch-to-zoom.
class FormulaViewer extends StatelessWidget {
  final String formula;
  final FormulaDisplayMode displayMode;

  const FormulaViewer({
    super.key,
    required this.formula,
    required this.displayMode,
  });

  static Future<void> show(BuildContext context, String formula,
      FormulaDisplayMode mode) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FormulaViewer(formula: formula, displayMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('公式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > constraints.maxHeight;

            return InteractiveViewer(
              maxScale: 8.0,
              minScale: 0.1,
              constrained: true,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildFormula(theme, isWide),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormula(ThemeData theme, bool isWide) {
    // Apply the same preprocessing pipeline used in MathMarkdown
    final safeFormula = _safeLatex(formula);
    return Math.tex(
      safeFormula,
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontSize: isWide ? 28 : 22,
        color: theme.colorScheme.onSurface,
      ),
      mathStyle: MathStyle.display,
    );
  }

  /// Minimal inline copy of _safeLatex so FormulaViewer can preprocess
  /// independently (avoids importing math_markdown.dart internals).
  static String _safeLatex(String raw) {
    // Clean invisible / zero-width characters
    var s = raw
        .replaceAll('​', '')
        .replaceAll('‌', '')
        .replaceAll('‍', '')
        .replaceAll('⁠', '')
        .replaceAll('﻿', '')
        .replaceAll('　', ' ')
        .replaceAll(' ', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    // Strip declare/new/def macros
    s = s.replaceAll(RegExp(r'\\DeclareMathOperator\s*\*?\s*\{\\.+?\}\s*\{[^}]*\}'), '');
    s = s.replaceAll(RegExp(r'\\(?:new|renew)command\s*\*?\s*\{\\.+?\}\s*(\[\d+\])?\s*\{[^}]*\}'), '');
    s = s.replaceAll(RegExp(r'\\def\s*\\.+?\{[^}]*\}'), '');
    // Convert environments
    s = s.replaceAllMapped(RegExp(r'\\begin\{align\*?\}([\s\S]*?)\\end\{align\*?\}'), (m) => '\\begin{aligned}${m.group(1) ?? ''}\\end{aligned}');
    s = s.replaceAllMapped(RegExp(r'\\begin\{equation\*?\}([\s\S]*?)\\end\{equation\*?\}'), (m) => (m.group(1) ?? '').trim());
    s = s.replaceAllMapped(RegExp(r'\\begin\{eqnarray\*?\}([\s\S]*?)\\end\{eqnarray\*?\}'), (m) => '\\begin{aligned}${m.group(1) ?? ''}\\end{aligned}');
    s = s.replaceAllMapped(RegExp(r'\\begin\{gather\*?\}([\s\S]*?)\\end\{gather\*?\}'), (m) => '\\begin{gathered}${m.group(1) ?? ''}\\end{gathered}');
    // Strip labels / refs / tags
    s = s.replaceAll(RegExp(r'\\label\s*\{[^}]*\}'), '');
    s = s.replaceAll(RegExp(r'\\ref\s*\{[^}]*\}'), '?');
    s = s.replaceAll(RegExp(r'\\eqref\s*\{[^}]*\}'), '(?)');
    s = s.replaceAll(RegExp(r'\\cite\s*(\[[^\]]*\])?\s*\{[^}]*\}'), '');
    s = s.replaceAll(RegExp(r'\\nonumber'), '');
    s = s.replaceAll(RegExp(r'\\tag\s*\{[^}]*\}'), '');
    // Command aliases
    s = s.replaceAll(RegExp(r'\\bm\s*\{'), '\\boldsymbol{');
    s = s.replaceAll(RegExp(r'\\bf\b'), r'\mathbf');
    // Redundant style commands
    s = s.replaceAll(RegExp(r'\\displaystyle\b'), '');
    s = s.replaceAll(RegExp(r'\\textstyle\b'), '');
    s = s.replaceAll(RegExp(r'\\scriptstyle\b'), '');
    s = s.replaceAll(RegExp(r'\\limits\b'), '');
    s = s.replaceAll(RegExp(r'\\nolimits\b'), '');
    // Invisible fences
    s = s.replaceAll(RegExp(r'\\left\.\s*'), '');
    s = s.replaceAll(RegExp(r'\\right\.\s*'), '');
    // Niche commands
    s = s.replaceAllMapped(RegExp(r'\\ce\s*\{([^}]*)\}'), (m) => '\\mathrm{${m.group(1) ?? ''}}');
    s = s.replaceAllMapped(RegExp(r'\\operatorname\s*\{([^}]*)\}'), (m) => '\\mathrm{${m.group(1) ?? ''}}');
    s = s.replaceAllMapped(RegExp(r'\\cancel\s*\{([^}]*)\}'), (m) => m.group(1) ?? '');
    s = s.replaceAllMapped(RegExp(r'\\[bx]cancel\s*\{([^}]*)\}'), (m) => m.group(1) ?? '');
    s = s.replaceAll(RegExp(r'\\[hv]space\s*\*?\s*\{[^}]*\}'), '');
    s = s.replaceAll(RegExp(r'\\[hv]fill\b'), '');
    s = s.replaceAll(RegExp(r'\\\\\s*\[[^\]]*\]'), r'\\');
    // Whitespace
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.split('\n').map((l) => l.trim()).join('\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}
