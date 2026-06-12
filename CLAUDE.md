# ai_chat — Flutter AI Chat App

## Project overview
- Flutter Android/Windows 聊天应用，支持多 AI provider（OpenAI 等）、专家模式、语音输入
- 状态管理：Riverpod (`flutter_riverpod`)
- 数据库：SQLite (`sqflite`)
- 持久化：SharedPreferences

## Directory structure (lib/)
```
lib/
├── main.dart                          # 入口
├── app.dart                           # MaterialApp 配置
├── db/                                # 数据库层
│   ├── database_helper.dart           # SQLite 初始化
│   ├── conversation_dao.dart          # 对话 CRUD
│   ├── message_dao.dart               # 消息 CRUD
│   └── storage.dart                   # 存储抽象
├── models/                            # 数据模型
│   ├── conversation.dart
│   ├── message.dart
│   ├── persona.dart
│   ├── provider_config.dart
│   └── expert_panel.dart
├── services/                          # 业务服务
│   ├── ai_service.dart                # AI API 调用
│   ├── expert_mode_service.dart
│   ├── audio_service.dart             # 语音录制/转写
│   └── image_service.dart             # 图片选取
├── state/                             # Riverpod 状态
│   ├── chat_state.dart / chat_notifier.dart
│   ├── providers.dart
│   ├── conversation_list_notifier.dart
│   ├── persona_list_notifier.dart
│   ├── expert_panel_list_notifier.dart
│   ├── provider_list_notifier.dart
│   ├── theme_notifier.dart
│   └── formula_display_notifier.dart   # 公式显示模式 (off/scroll/scale)
├── screens/
│   ├── chat_screen.dart               # 主聊天界面
│   ├── conversations_screen.dart      # 对话列表
│   ├── settings_screen.dart           # 设置
│   └── favorites_screen.dart          # 收藏
└── widgets/                           # UI 组件
    ├── message_bubble.dart            # 消息气泡（调用 MathMarkdown）
    ├── math_markdown.dart             # ★ 核心：Markdown+LaTeX+SVG 混合渲染
    ├── formula_viewer.dart            # 全屏公式查看器
    ├── chat_input_bar.dart            # 输入栏
    ├── svg_block.dart                 # SVG 渲染
    ├── conversation_tile.dart         # 对话列表项
    ├── expert_progress_widget.dart
    ├── expert_panel_form_dialog.dart
    ├── persona_form_dialog.dart
    ├── provider_form_dialog.dart
    └── image_preview_sheet.dart
```

## Key rendering pipeline (math_markdown.dart)
1. **块级提取** `_findBlockSpecials`: 提取 `$$...$$` / `\[...\]` / `<svg>`
2. **表格渲染** `_TableBlock`: `Table` + `IntrinsicColumnWidth`（列对齐）+ `SingleChildScrollView`（水平滑动）+ tap 全屏 `InteractiveViewer`
3. **行内渲染** `_InlineRichSegment`: `RichText` + `WidgetSpan`（行内公式流式嵌入）
4. **LaTeX 预处理** `_safeLatex()`: 清洗不可见字符 + 剥离小众命令 + 环境转换 → `Math.tex()`
5. **公式保护** `_protectUnderscoresInMath()`: 传给 MarkdownBody 前转义 `$...$` 内 `_`，防止 markdown 斜体破坏 LaTeX

## Critical dependencies
- `flutter_math_fork` — LaTeX 渲染（Math.tex widget）
- `flutter_markdown 0.7.7+1` — Markdown 渲染（已 discontinued，替代品 flutter_markdown_plus）
- `flutter_riverpod 2.6.1`
- `image_picker_android` — 图片选取
- `record` — 语音录制
- `sqflite` — SQLite 数据库
- `shared_preferences` — 键值持久化

## Build notes
- **必须加 `--no-tree-shake-icons`**: chat_screen.dart:411 有非 const IconData，不加会编译失败
- 仅 Android 和 Windows 平台支持
- AGP 8.9.1 / Kotlin 2.1.20（有弃用警告但可用）
- APK 输出路径: `build\app\outputs\flutter-apk\app-release.apk`
- 构建命令: `flutter build apk --release --no-tree-shake-icons`

## 当前已知状态
- ✅ 行内公式流式嵌入、显示公式块排版
- ✅ 表格列对齐 + 水平滑动 + tap 全屏缩放
- ✅ LaTeX 预处理管道（环境转换、命令降级、`_` 保护）
- ✅ 纯文本表格单元格不经过 Math.tex（防截断）
- ✅ 代码块无滚动包裹，完整显示
- ✅ 追问逻辑：输入框不复制内容，发送时自动包裹上下文
- ⚠️ `forceInlineOnly` 参数未使用（math_markdown.dart:731）
- ⚠️ AGP/Kotlin 版本有未来弃用警告
