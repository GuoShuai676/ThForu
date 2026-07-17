import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FormulaDisplayMode {
  off, // 关闭公式渲染，显示原始 LaTeX 源码
  scroll, // 水平滑动查看完整公式
  scale, // 自适应缩放到屏幕宽度
}

class FormulaDisplayNotifier extends StateNotifier<FormulaDisplayMode> {
  static const _key = 'formula_display_mode_v2';

  FormulaDisplayNotifier() : super(FormulaDisplayMode.scale) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'off':
        state = FormulaDisplayMode.off;
        break;
      case 'scroll':
        state = FormulaDisplayMode.scroll;
        break;
      default:
        state = FormulaDisplayMode.scale;
    }
  }

  Future<void> setMode(FormulaDisplayMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final v = switch (mode) {
      FormulaDisplayMode.off => 'off',
      FormulaDisplayMode.scroll => 'scroll',
      FormulaDisplayMode.scale => 'scale',
    };
    await prefs.setString(_key, v);
  }
}
