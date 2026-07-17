import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import 'math_markdown.dart';
import 'streaming_cursor.dart';
import 'assistant_avatar.dart';

class _MessageEntrance extends StatefulWidget {
  final Widget child;
  final bool isUser;

  const _MessageEntrance({required this.child, required this.isUser});

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.15 : -0.15, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isStreaming;
  final String? highlight;
  final bool isCurrentSearchMatch;
  final void Function(String content, String messageId)? onFollowUp;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;
  final void Function(String messageId)? onScrollToMessage;
  final VoidCallback? onExportWord;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onExportTxt;
  final VoidCallback? onRegenerate;
  final void Function(String messageId, String currentContent)? onEdit;
  final bool isSelected;
  final bool multiSelectMode;
  final VoidCallback? onToggleSelect;
  final IconData? assistantIcon;
  final Color? assistantColor;
  final String? assistantName;
  final AssistantState assistantState;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.highlight,
    this.isCurrentSearchMatch = false,
    this.onFollowUp,
    this.onDelete,
    this.onToggleFavorite,
    this.onScrollToMessage,
    this.onExportWord,
    this.onExportMarkdown,
    this.onExportTxt,
    this.onRegenerate,
    this.onEdit,
    this.isSelected = false,
    this.multiSelectMode = false,
    this.onToggleSelect,
    this.assistantIcon,
    this.assistantColor,
    this.assistantName,
    this.assistantState = AssistantState.idle,
  });

  bool get _isExpertResponse =>
      message.metadata != null &&
      message.metadata!['type'] == 'expert_response';

  void _showContextMenu(BuildContext context) {
    if (isStreaming) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.content.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制文本'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制到剪贴板'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.replay),
                title: const Text('引用回复'),
                subtitle: Text(
                  message.content.length > 200
                      ? '${message.content.substring(0, 200)}...'
                      : message.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final preview = message.content.length > 200
                      ? '${message.content.substring(0, 200)}...'
                      : message.content;
                  onFollowUp?.call(preview, message.id);
                },
              ),
            ],
            ListTile(
              leading: Icon(
                message.isFavorite ? Icons.star : Icons.star_border,
                color: message.isFavorite ? Colors.amber : null,
              ),
              title: Text(message.isFavorite ? '取消收藏' : '收藏'),
              onTap: () {
                Navigator.pop(ctx);
                onToggleFavorite?.call();
              },
            ),
            if (message.role == 'assistant' &&
                message.content.isNotEmpty &&
                !message.content.startsWith('错误:'))
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新生成'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate?.call();
                },
              ),
            if (message.role == 'user')
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑重发'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit?.call(message.id, message.content);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('导出为 Word'),
              onTap: () {
                Navigator.pop(ctx);
                onExportWord?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('导出为 Markdown'),
              onTap: () {
                Navigator.pop(ctx);
                onExportMarkdown?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('导出为 TXT'),
              onTap: () {
                Navigator.pop(ctx);
                onExportTxt?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, String imagePath) {
    // Close keyboard before opening image viewer
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(imagePath: imagePath),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final isMatch = highlight != null;

    if (_isExpertResponse) {
      return _buildExpertResponse(context, theme);
    }

    return _MessageEntrance(
      isUser: isUser,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: isUser
              ? _buildUserRow(context, theme, isMatch)
              : _buildAssistantColumn(context, theme, isMatch),
        ),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, ThemeData theme, bool isMatch) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (multiSelectMode)
          GestureDetector(
            onTap: onToggleSelect,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
                border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        Flexible(
          child: _buildBubble(context, theme, isMatch, isUser: true),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 17,
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.person, size: 20, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildAssistantColumn(
      BuildContext context, ThemeData theme, bool isMatch) {
    final state = isStreaming ? AssistantState.streaming : assistantState;
    final avIcon = assistantIcon ?? Icons.smart_toy;
    final avColor = assistantColor ?? const Color(0xFF6366F1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AssistantAvatar(
                icon: avIcon,
                color: avColor,
                size: 32,
                state: state,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                assistantName ?? 'AI 助手',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: avColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onLongPress: multiSelectMode
                    ? onToggleSelect
                    : () => _showContextMenu(context),
                child: _buildBubble(context, theme, isMatch, isUser: false),
              ),
              if (multiSelectMode)
                GestureDetector(
                  onTap: onToggleSelect,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, ThemeData theme, bool isMatch,
      {required bool isUser}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isCurrentSearchMatch
            ? LinearGradient(colors: [
                Colors.amber.withValues(alpha: 0.4),
                Colors.amber.withValues(alpha: 0.2)
              ])
            : isMatch
                ? LinearGradient(colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.08)
                  ])
                : isUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                        ],
                      )
                    : null,
        color: (!isUser && !isMatch && !isCurrentSearchMatch)
            ? const Color(0xFFE8EDF2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isUser ? 0.06 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCurrentSearchMatch
            ? Border.all(color: Colors.amber, width: 2)
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft:
              isUser ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight:
              isUser ? const Radius.circular(4) : const Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.metadata != null &&
              message.metadata!['replyToId'] != null)
            GestureDetector(
              onTap: () {
                final targetId = message.metadata!['replyToId'] as String;
                onScrollToMessage?.call(targetId);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (message.metadata!['replyPreview'] as String? ?? '')
                                    .length >
                                40
                            ? '${(message.metadata!['replyPreview'] as String).substring(0, 40)}...'
                            : (message.metadata!['replyPreview'] as String? ??
                                ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (message.hasImages) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: message.imagePaths!.map((path) {
                return GestureDetector(
                  onTap: () => _openImageViewer(context, path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (message.content.isNotEmpty) const SizedBox(height: 8),
          ],
          if (message.hasFile) ...[
            ...message.allFileNames.map(
                (name) => _FileAttachmentBubble(fileName: name, theme: theme)),
            if (message.content.isNotEmpty) const SizedBox(height: 8),
          ],
          if (isUser)
            Text(message.content,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer))
          else if (isStreaming && message.content.isEmpty)
            _TypingIndicator(theme: theme)
          else if (isStreaming)
            _StreamingContent(
              content: message.content,
              theme: theme,
            )
          else
            RepaintBoundary(
              child: MathMarkdown(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface),
                  code: theme.textTheme.bodySmall?.copyWith(
                    backgroundColor: theme.colorScheme.surface,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (isStreaming && message.content.isNotEmpty) ...[
            const SizedBox(height: 2),
            _BlinkingCursor(theme: theme),
          ],
          if (message.isFavorite) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 13, color: Colors.amber.shade600),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpertResponse(BuildContext context, ThemeData theme) {
    final providerName = message.metadata?['providerName'] as String? ?? '未知来源';
    final isEmpty = message.content.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 36),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showContextMenu(context),
              child: _ExpertResponseCard(
                providerName: providerName,
                content: message.content,
                isEmpty: isEmpty,
                isStreaming: isStreaming,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the offset of the first unclosed LaTeX delimiter, or -1 if all closed.
int _latexSplitOffset(String text) {
  int i = 0;
  while (i < text.length) {
    if (i + 1 < text.length && text[i] == r'$' && text[i + 1] == r'$') {
      final end = text.indexOf(r'$$', i + 2);
      if (end < 0) return i;
      i = end + 2;
    } else if (i + 1 < text.length && text[i] == '\\' && text[i + 1] == '[') {
      final end = text.indexOf('\\]', i + 2);
      if (end < 0) return i;
      i = end + 2;
    } else if (text[i] == r'$') {
      final end = text.indexOf(r'$', i + 1);
      if (end < 0) return i;
      i = end + 1;
    } else {
      i++;
    }
  }
  return -1;
}

/// Renders streaming content: complete formulas with MathMarkdown,
/// incomplete tail with plain Text.
class _StreamingContent extends StatelessWidget {
  final String content;
  final ThemeData theme;

  const _StreamingContent({
    required this.content,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final splitAt = _latexSplitOffset(content);

    final mdStyle = MarkdownStyleSheet(
      p: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurface),
      code: theme.textTheme.bodySmall?.copyWith(
        backgroundColor: theme.colorScheme.surface,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    if (splitAt < 0) {
      return RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MathMarkdown(
              data: content,
              selectable: true,
              styleSheet: mdStyle,
            ),
            const StreamingCursor(),
          ],
        ),
      );
    }

    final completePart = content.substring(0, splitAt);
    final tailPart = content.substring(splitAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (completePart.isNotEmpty)
          RepaintBoundary(
            child: MathMarkdown(
              data: completePart,
              selectable: true,
              styleSheet: mdStyle,
            ),
          ),
        Text.rich(TextSpan(
            children: [
              TextSpan(text: tailPart),
              const WidgetSpan(child: StreamingCursor()),
            ],
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface))),
      ],
    );
  }
}

class _ExpertResponseCard extends StatefulWidget {
  final String providerName;
  final String content;
  final bool isEmpty;
  final bool isStreaming;
  final ThemeData theme;

  const _ExpertResponseCard({
    required this.providerName,
    required this.content,
    required this.isEmpty,
    required this.isStreaming,
    required this.theme,
  });

  @override
  State<_ExpertResponseCard> createState() => _ExpertResponseCardState();
}

class _ExpertResponseCardState extends State<_ExpertResponseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.purple.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology,
                      size: 14, color: Colors.purple.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    widget.providerName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.isEmpty && widget.isStreaming) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (widget.content.isNotEmpty)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
              child: MathMarkdown(
                data: widget.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                  code: theme.textTheme.bodySmall?.copyWith(
                    backgroundColor: theme.colorScheme.surface,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final ThemeData theme;
  const _TypingIndicator({required this.theme});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (_, __) {
            final phase = (_controller.value * 3.0 - i * 0.8) % 3.0;
            final t = phase < 0
                ? 0.0
                : (phase > 1.0
                    ? (phase < 2.0 ? 1.0 - (phase - 1.0) : 0.0)
                    : phase);
            final smooth = t * t * (3.0 - 2.0 * t);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, -6.0 * smooth),
                child: Transform.scale(
                  scale: 0.8 + 0.2 * smooth,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.primary
                          .withValues(alpha: 0.35 + 0.65 * smooth),
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

class _BlinkingCursor extends StatefulWidget {
  final ThemeData theme;
  const _BlinkingCursor({required this.theme});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 2.5,
        height: 17,
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

class _FileAttachmentBubble extends StatelessWidget {
  final String fileName;
  final ThemeData theme;

  const _FileAttachmentBubble({required this.fileName, required this.theme});

  IconData _iconForName(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip,
      'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' => Icons.audio_file,
      'mp4' || 'avi' || 'mkv' || 'mov' || 'wmv' => Icons.video_file,
      'txt' || 'md' || 'log' => Icons.article,
      'py' ||
      'js' ||
      'ts' ||
      'dart' ||
      'java' ||
      'c' ||
      'cpp' ||
      'h' =>
        Icons.code,
      'json' || 'xml' || 'yaml' || 'yml' || 'toml' => Icons.data_object,
      'html' || 'css' || 'htm' => Icons.language,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'bmp' ||
      'webp' ||
      'svg' =>
        Icons.image,
      _ => Icons.insert_drive_file,
    };
  }

  Color _colorForExt(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Colors.red,
      'doc' || 'docx' => Colors.blue,
      'xls' || 'xlsx' || 'csv' => Colors.green,
      'ppt' || 'pptx' => Colors.orange,
      'zip' || 'rar' || '7z' => Colors.brown,
      'mp3' || 'wav' || 'flac' => Colors.purple,
      'mp4' || 'avi' || 'mkv' => Colors.deepPurple,
      'py' || 'js' || 'ts' || 'dart' => Colors.teal,
      'jpg' || 'jpeg' || 'png' || 'gif' => Colors.pink,
      _ => theme.colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ext = fileName.split('.').last.toLowerCase();
    final icon = _iconForName(fileName);
    final color = _colorForExt(fileName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  ext.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen image viewer with pinch-to-zoom
// ---------------------------------------------------------------------------

class _ImageViewerPage extends StatelessWidget {
  final String imagePath;
  const _ImageViewerPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('无法加载图片', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }
}
