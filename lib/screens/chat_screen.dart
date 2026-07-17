import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/conversation.dart';
import '../models/provider_config.dart';
import '../models/expert_panel.dart';
import '../models/persona.dart';
import '../state/providers.dart';
import '../state/chat_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/expert_progress_widget.dart';
import '../widgets/assistant_avatar.dart';
import '../widgets/tool_execution_widget.dart';
import '../services/deep_search_service.dart';
import '../services/word_generator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? scrollToMessageId;

  const ChatScreen({super.key, required this.conversationId, this.scrollToMessageId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';
  String? _followUpContext;
  String? _followUpMessageId;
  final _messageKeys = <String, GlobalKey>{};
  bool _multiSelectMode = false;
  final Set<String> _selectedMessageIds = {};
  bool _userScrolledUp = false;
  String? _lastSentText;
  List<String>? _lastSentImages;
  String? _lastSentFilePath;
  String? _lastSentFileName;
  bool _errorExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    if (widget.scrollToMessageId != null && widget.scrollToMessageId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _scrollToMessage(widget.scrollToMessageId!);
        });
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    // reverse:true → pixels 0 == bottom. Treat any meaningful upward
    // movement (≥ 60px from bottom) as "user scrolled up" so we stop
    // auto-scrolling immediately, instead of fighting the user's gesture.
    if (pixels >= 60 && !_userScrolledUp) {
      _userScrolledUp = true;
    } else if (pixels < 30 && _userScrolledUp) {
      _userScrolledUp = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    ref.read(chatProvider(widget.conversationId).notifier).loadMessages();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // reverse:true — pixels=0 = bottom, pixels=maxExtent = top
  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels < 100;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _userScrolledUp = false;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Jumps to the bottom, then verifies we actually reached it.  If the
  /// ListView hasn't finished laying out variable-height items (common in
  /// expert mode with collapsible cards), retry in the next frame.
  void _scrollToBottomInitial() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      // Layout not done yet — retry next frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottomInitial());
      return;
    }
    _scrollController.jumpTo(maxExtent);
    // After the jump, check if we really reached it.  If not, the
    // extent grew during layout (more items were built) — retry once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final newExtent = _scrollController.position.maxScrollExtent;
      if (newExtent > maxExtent + 10) {
        _scrollController.jumpTo(newExtent);
      }
    });
  }

  /// Scrolls to [messageId] using [Scrollable.ensureVisible] for pixel-perfect
  /// positioning.  If the target is off-screen (not yet built), uses a
  /// proportional jump first to bring it into the build region, then retries.
  void _scrollToMessage(String messageId, {int retry = 0}) {
    if (!_scrollController.hasClients) {
      if (retry < 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToMessage(messageId, retry: retry + 1);
        });
      }
      return;
    }

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.15,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      return;
    }

    // Target not built yet — proportional jump to bring it into view
    final messages = ref.read(chatProvider(widget.conversationId)).messages;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return; // message deleted?

    final listViewIndex = messages.length - 1 - idx;
    final fraction = listViewIndex /
        (messages.length > 1 ? messages.length - 1 : 1);
    final estimate =
        fraction * _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(estimate);

    if (retry < 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(messageId, retry: retry + 1);
      });
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
    });
  }

  void _jumpToSearchResult(int originalIndex) {
    final messages = ref.read(chatProvider(widget.conversationId)).messages;
    final targetMsg = messages[originalIndex];

    // Remove listener so _searchCtrl.clear() doesn't trigger _onSearchChanged
    // which would cause a nested setState during this setState.
    _searchCtrl.removeListener(_onSearchChanged);
    setState(() {
      _showSearch = false;
      _searchCtrl.clear();
      _searchQuery = '';
    });
    _searchCtrl.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMessage(targetMsg.id);
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (msgDay.year == today.year) {
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildSearchResults(List messages, ThemeData theme) {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      final content = messages[i].content as String;
      if (content.toLowerCase().contains(_searchQuery)) {
        results.add({
          'index': i,
          'content': content,
          'role': messages[i].role,
          'createdAt': messages[i].createdAt as DateTime,
          'isFavorite': messages[i].isFavorite,
        });
      }
    }

    return Column(
      children: [
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('未找到 "${_searchCtrl.text.trim()}" 的相关消息',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('找到 ${results.length} 条记录',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) {
                final r = results[i];
                final isUser = r['role'] == 'user';
                final content = r['content'] as String;
                final createdAt = r['createdAt'] as DateTime;
                final timeStr = _formatTime(createdAt);

                // Build a snippet around the first match of the search term
                final lowerContent = content.toLowerCase();
                final matchPos = lowerContent.indexOf(_searchQuery);
                String snippet;
                if (matchPos >= 0) {
                  final start = (matchPos - 20).clamp(0, content.length);
                  final end = (matchPos + _searchQuery.length + 60)
                      .clamp(0, content.length);
                  snippet = (start > 0 ? '…' : '') +
                      content.substring(start, end).replaceAll('\n', ' ') +
                      (end < content.length ? '…' : '');
                } else {
                  snippet = content.replaceAll('\n', ' ').substring(
                      0, 120.clamp(0, content.length));
                  if (content.length > 120) snippet += '…';
                }

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _jumpToSearchResult(r['index'] as int),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isUser
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.tertiaryContainer,
                            child: Icon(
                              isUser ? Icons.person : Icons.smart_toy,
                              size: 16,
                              color: isUser
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isUser ? '你' : 'AI',
                                      style: theme
                                          .textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.outline,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      timeStr,
                                      style: theme
                                          .textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.outline,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    children: _buildHighlightedSpans(snippet, _searchQuery, theme),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  List<TextSpan> _buildHighlightedSpans(String text, String query, ThemeData theme) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int pos = 0;
    while (pos < text.length) {
      final matchIdx = lowerText.indexOf(lowerQuery, pos);
      if (matchIdx < 0) {
        spans.add(TextSpan(text: text.substring(pos)));
        break;
      }
      if (matchIdx > pos) {
        spans.add(TextSpan(text: text.substring(pos, matchIdx)));
      }
      spans.add(TextSpan(
        text: text.substring(matchIdx, matchIdx + query.length),
        style: TextStyle(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ));
      pos = matchIdx + query.length;
    }
    return spans;
  }

  void _toggleMultiSelect() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String id) {
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
        if (_selectedMessageIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  void _selectAllMessages() {
    final chatState = ref.read(chatProvider(widget.conversationId));
    setState(() {
      if (_selectedMessageIds.length == chatState.messages.length) {
        _selectedMessageIds.clear();
      } else {
        _selectedMessageIds.addAll(chatState.messages.map((m) => m.id));
      }
    });
  }

  Future<void> _batchDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除 ${_selectedMessageIds.length} 条消息？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true) {
      final notifier = ref.read(chatProvider(widget.conversationId).notifier);
      for (final id in _selectedMessageIds) {
        await notifier.deleteMessage(id);
      }
      setState(() { _selectedMessageIds.clear(); _multiSelectMode = false; });
    }
  }

  Future<void> _batchFavorite() async {
    final notifier = ref.read(chatProvider(widget.conversationId).notifier);
    final count = _selectedMessageIds.length;
    for (final id in _selectedMessageIds) {
      await notifier.toggleFavorite(id);
    }
    setState(() { _selectedMessageIds.clear(); _multiSelectMode = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已收藏 $count 条消息')));
  }

  Future<void> _batchExportWord() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final selected = chatState.messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selected.isEmpty) return;

    final nameCtrl = TextEditingController(text: '对话导出');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出 Word'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '文件名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('导出')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
    if (dir == null) return;

    try {
      final file = File('$dir/$name.docx');
      final messages = selected.map((m) => {'role': m.role, 'content': _stripFormatting(m.content)}).toList();
      await WordGenerator.generate(title: name, messages: messages, outputPath: file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${file.path}')));
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.share), title: const Text('分享文件'), onTap: () => Navigator.pop(ctx, 'share')),
            ListTile(leading: const Icon(Icons.check), title: const Text('完成'), onTap: () => Navigator.pop(ctx)),
          ])),
        );
        if (result == 'share') await Share.shareXFiles([XFile(file.path)], text: name);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
    setState(() { _selectedMessageIds.clear(); _multiSelectMode = false; });
  }

  String _stripFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), '')
        .replaceAll(RegExp(r'\$[^$]+?\$'), '')
        .replaceAll(RegExp(r'\\\([\s\S]*?\\\)'), '')
        .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[^`]+`'), '')
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
        .replaceAll(RegExp(r'#{1,6}\s+'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '')
        .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^---\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _exportChatAsWord() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final conv = ref.read(conversationListProvider).where((c) => c.id == widget.conversationId).firstOrNull;
    final title = conv?.title ?? '对话记录';

    final nameCtrl = TextEditingController(text: title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出 Word'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '文件名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('导出')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
      if (dir == null) return;
      final file = File('$dir/$name.docx');
      final messages = chatState.messages.map((m) => {'role': m.role, 'content': _stripFormatting(m.content)}).toList();
      await WordGenerator.generate(title: name, messages: messages, outputPath: file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${file.path}')));
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.share), title: const Text('分享文件'), onTap: () => Navigator.pop(ctx, 'share')),
            ListTile(leading: const Icon(Icons.check), title: const Text('完成'), onTap: () => Navigator.pop(ctx)),
          ])),
        );
        if (result == 'share') await Share.shareXFiles([XFile(file.path)], text: name);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.conversationId));
    final providers = ref.watch(providerListProvider);
    final conversations = ref.watch(conversationListProvider);
    final panels = ref.watch(expertPanelListProvider);

    // reverse:true makes the list grow upward from the bottom —
    // first frame already shows the newest messages, no jump needed.
    ref.listen(chatProvider(widget.conversationId), (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;
      if (nextLen > prevLen && !_userScrolledUp && _isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    Conversation? conv;
    if (conversations.isNotEmpty) {
      final idx =
          conversations.indexWhere((c) => c.id == widget.conversationId);
      if (idx >= 0) conv = conversations[idx];
    }

    // Resolve provider (single mode) and expert panel info
    AIProviderConfig? provider;
    ExpertPanel? expertPanel;
    List<AIProviderConfig> expertConfigs = [];
    AIProviderConfig? gatewayConfig;
    bool isExpertMode = false;

    if (conv != null && providers.isNotEmpty) {
      final c = conv;
      if (c.expertPanelId != null) {
        isExpertMode = true;
        try {
          expertPanel =
              panels.firstWhere((p) => p.id == c.expertPanelId);
          final ep = expertPanel;
          for (final pid in ep.expertProviderIds) {
            try {
              final config = providers
                  .cast<AIProviderConfig?>()
                  .firstWhere((p) => p!.id == pid);
              if (config != null) expertConfigs.add(config);
            } catch (_) {}
          }
          try {
            gatewayConfig = providers
                .cast<AIProviderConfig?>()
                .firstWhere((p) => p!.id == ep.gatewayProviderId);
          } catch (_) {}
        } catch (_) {
          isExpertMode = false;
        }
      } else {
        try {
          provider = providers
              .cast<AIProviderConfig?>()
              .firstWhere((p) => p!.id == c.providerConfigId);
        } catch (_) {}
      }
    }

    // Resolve persona for avatar display
    Persona? persona;
    final cnv = conv; // local copy for null promotion
    if (cnv?.personaId != null) {
      final personas = ref.watch(personaListProvider);
      try {
        persona = personas.firstWhere((p) => p.id == cnv!.personaId);
      } catch (_) {}
    }

    final theme = Theme.of(context);

    if (chatState.isStreaming && !_userScrolledUp && _isNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    // Determine support flags for ChatInputBar
    final supportsVision = isExpertMode
        ? expertConfigs.every((c) => c.supportsVision)
        : (provider?.supportsVision ?? false);
    final supportsFile = isExpertMode
        ? expertConfigs.any((c) => c.supportsFile)
        : (provider?.supportsFile ?? false);
    final hintText = isExpertMode ? '向兼听提问...' : '输入消息...';

    return Scaffold(
      appBar: _showSearch
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchCtrl.clear();
                  });
                },
              ),
              title: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索消息...',
                  border: InputBorder.none,
                ),
              ),
            )
          : _multiSelectMode
              ? AppBar(
                  leading: IconButton(icon: const Icon(Icons.close), onPressed: _toggleMultiSelect),
                  title: Text('已选择 ${_selectedMessageIds.length} 条'),
                  actions: [
                    IconButton(icon: Icon(_selectedMessageIds.length == chatState.messages.length ? Icons.deselect : Icons.select_all), tooltip: '全选', onPressed: _selectAllMessages),
                    IconButton(icon: const Icon(Icons.delete_outline), tooltip: '删除', onPressed: _batchDelete),
                    IconButton(icon: const Icon(Icons.star_outline), tooltip: '收藏', onPressed: _batchFavorite),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'word') _batchExportWord();
                        else if (v == 'md') _exportSelectedAsMarkdown();
                        else if (v == 'txt') _exportSelectedAsTxt();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'word', child: Text('导出 Word')),
                        const PopupMenuItem(value: 'md', child: Text('导出 Markdown')),
                        const PopupMenuItem(value: 'txt', child: Text('导出 TXT')),
                      ],
                      child: const Icon(Icons.description),
                    ),
                  ],
                )
              : AppBar(
              automaticallyImplyLeading: true,
              title: Text(conv?.title ?? 'Chat'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '搜索聊天记录',
                  onPressed: () {
                    setState(() => _showSearch = true);
                  },
                ),
                if (isExpertMode && expertPanel != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: Text(
                        '兼听·${expertPanel.name}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.purple.withValues(alpha: 0.15),
                      side: BorderSide(
                          color: Colors.purple.withValues(alpha: 0.3)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else if (provider != null && conv != null)
                  _ModelSelectorChip(
                    provider: provider,
                    currentModel: conv.modelName,
                    reasoningEffort: conv.reasoningEffort,
                    onModelChanged: (model, effort) {
                      ref.read(conversationListProvider.notifier).switchModel(
                            widget.conversationId,
                            model,
                            effort,
                          );
                    },
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'wallpaper') {
                      _setWallpaper();
                    } else if (value == 'clear_wallpaper') {
                      ref
                          .read(conversationListProvider.notifier)
                          .setWallpaper(widget.conversationId, null);
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    } else if (value == 'select') {
                      _toggleMultiSelect();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                        value: 'select', child: Text('选择消息')),
                    const PopupMenuItem(
                        value: 'wallpaper', child: Text('设置壁纸')),
                    if (conv?.wallpaperPath != null)
                      const PopupMenuItem(
                          value: 'clear_wallpaper',
                          child: Text('清除壁纸')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('删除会话')),
                  ],
                ),
              ],
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: wallpaper
          if (conv?.wallpaperPath != null)
            Image.file(
              File(conv!.wallpaperPath!),
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.6),
              colorBlendMode: BlendMode.darken,
            ),
          // Layer 1: chat (always in the tree so GlobalKeys stay alive)
          Column(
            children: [
              if (chatState.errorMessage != null)
                MaterialBanner(
                  content: GestureDetector(
                    onTap: () => setState(() => _errorExpanded = !_errorExpanded),
                    child: Text(
                      _errorExpanded || chatState.errorMessage!.length < 80
                          ? chatState.errorMessage!
                          : '${chatState.errorMessage!.substring(0, 80)}...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.errorContainer,
                  actions: [
                    if (_lastSentText != null)
                      FilledButton(
                        onPressed: () {
                          final text = _lastSentText!;
                          final images = _lastSentImages;
                          final filePath = _lastSentFilePath;
                          final fileName = _lastSentFileName;
                          ref.read(chatProvider(widget.conversationId).notifier).clearError();
                          setState(() {
                            _errorExpanded = false;
                            _lastSentText = null;
                            _lastSentImages = null;
                            _lastSentFilePath = null;
                            _lastSentFileName = null;
                          });
                          final notifier = ref.read(chatProvider(widget.conversationId).notifier);
                          final conversations = ref.read(conversationListProvider);
                          final currentConv = conversations.firstWhere((c) => c.id == widget.conversationId);
                          if (isExpertMode && expertPanel != null && gatewayConfig != null) {
                            notifier.sendExpertMessage(panel: expertPanel, expertConfigs: expertConfigs, gatewayConfig: gatewayConfig, text: text, imagePaths: images, filePath: filePath, fileName: fileName);
                          } else if (provider != null) {
                            notifier.sendMessage(providerConfig: provider, text: text, imagePaths: images, filePath: filePath, fileName: fileName, overrideModel: currentConv.modelName, reasoningEffort: currentConv.reasoningEffort);
                          }
                        },
                        child: const Text('重试'),
                      ),
                    TextButton(
                      onPressed: () {
                        ref.read(chatProvider(widget.conversationId).notifier).clearError();
                        setState(() { _errorExpanded = false; });
                      },
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              // Expert progress indicator
              if (chatState.expertPhase != ExpertPhase.none)
                ExpertProgressWidget(
                  phase: chatState.expertPhase,
                  statuses: chatState.expertStatuses,
                ),
              // Tool execution indicator
              if (chatState.toolExecutions.isNotEmpty)
                ToolExecutionWidget(executions: chatState.toolExecutions),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification && notification.dragDetails != null && _scrollController.hasClients && _scrollController.position.pixels >= 60) {
                        setState(() => _userScrolledUp = true);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      // reverse:true puts index 0 at the bottom, so we feed
                      // messages in reverse so newest (last) maps to index 0.
                      final msg = chatState.messages[
                          chatState.messages.length - 1 - index];
                      final isLastAssistant =
                          index == 0 && msg.role == 'assistant';
                      // Expert-response / gateway bubbles each get their
                      // own spinner while content is still empty; it
                      // disappears the moment that expert finishes.
                      final isExpertMsg = msg.metadata != null &&
                          (msg.metadata!['type'] == 'expert_response' ||
                           msg.metadata!['type'] == 'gateway_synthesis');
                      final showStreaming = isExpertMsg
                          ? msg.content.isEmpty && chatState.isStreaming
                          : isLastAssistant && chatState.isStreaming;
                      return MessageBubble(
                        key: _messageKeys.putIfAbsent(msg.id, () => GlobalKey()),
                        message: msg,
                        isStreaming: showStreaming,
                        assistantIcon: persona != null
                            ? IconData(persona.avatarIcon,
                                fontFamily: 'MaterialIcons')
                            : null,
                        assistantColor: persona != null
                            ? Color(persona.avatarColor)
                            : null,
                        assistantName: persona?.name,
                        assistantState: showStreaming
                            ? AssistantState.streaming
                            : AssistantState.idle,
                        onFollowUp: (content, msgId) {
                          setState(() {
                            _followUpContext = content;
                            _followUpMessageId = msgId;
                          });
                        },
                        onDelete: () {
                          ref
                              .read(chatProvider(widget.conversationId)
                                  .notifier)
                              .deleteMessage(msg.id);
                        },
                        onToggleFavorite: () {
                          ref
                              .read(chatProvider(widget.conversationId)
                                  .notifier)
                              .toggleFavorite(msg.id);
                        },
                        onScrollToMessage: (targetId) {
                          _scrollToMessage(targetId);
                        },
                        onExportWord: () => _exportChatAsWord(),
                        onExportMarkdown: () => _exportChatAsMarkdown(),
                        onExportTxt: () => _exportChatAsTxt(),
                        onRegenerate: () {
                          if (provider != null) {
                            ref.read(chatProvider(widget.conversationId).notifier).regenerateLastResponse(
                              providerConfig: provider,
                              overrideModel: conv?.modelName,
                              reasoningEffort: conv?.reasoningEffort,
                            );
                          }
                        },
                        onEdit: (msgId, currentContent) {
                          _showEditDialog(msgId, currentContent, provider);
                        },
                        multiSelectMode: _multiSelectMode,
                        isSelected: _selectedMessageIds.contains(msg.id),
                        onToggleSelect: () => _toggleMessageSelection(msg.id),
                      );
                    },
                  ),
                ),
                ),
              ),
              if (!_multiSelectMode && (isExpertMode
                  ? (gatewayConfig != null && expertConfigs.isNotEmpty)
                  : provider != null))
                SafeArea(
                  top: false,
                  child: ChatInputBar(
                  key: const ValueKey('chat_input_bar'),
                  onSend: ({
                    required String text,
                    List<String>? imagePaths,
                    String? filePath,
                    String? fileName,
                    bool? deepSearch,
                  }) async {
                    _lastSentText = text;
                    _lastSentImages = imagePaths;
                    _lastSentFilePath = filePath;
                    _lastSentFileName = fileName;
                    final replyTo = _followUpMessageId;
                    final replyPreview = _followUpContext;
                    final notifier = ref.read(
                        chatProvider(widget.conversationId).notifier);
                    if (deepSearch == true && provider != null) {
                      await notifier.sendDeepSearchMessage(
                        providerConfig: provider,
                        text: text,
                      );
                    } else if (isExpertMode &&
                        expertPanel != null &&
                        gatewayConfig != null) {
                      await notifier.sendExpertMessage(
                        panel: expertPanel,
                        expertConfigs: expertConfigs,
                        gatewayConfig: gatewayConfig,
                        text: text,
                        imagePaths: imagePaths,
                        filePath: filePath,
                        fileName: fileName,
                      );
                    } else if (provider != null) {
                      await notifier.sendMessage(
                        providerConfig: provider,
                        text: text,
                        imagePaths: imagePaths,
                        filePath: filePath,
                        fileName: fileName,
                        replyToId: replyTo,
                        replyPreview: replyPreview,
                        overrideModel: conv?.modelName,
                        reasoningEffort: conv?.reasoningEffort,
                      );
                    }
                  },
                  onMessageSent: () {
                    _userScrolledUp = false;
                    setState(() {
                      _followUpContext = null;
                      _followUpMessageId = null;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  },
                  supportsVision: supportsVision,
                  supportsFile: supportsFile,
                  hintText: hintText,
                  prefillText: null,
                  followUpContent: _followUpContext,
                  onCancelFollowUp: () {
                    setState(() {
                      _followUpContext = null;
                      _followUpMessageId = null;
                    });
                  },
                ),
                ),
            ],
          ),
          // Layer 2: search overlay (covers chat when active)
          if (_showSearch && _searchQuery.isNotEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: _buildSearchResults(chatState.messages, theme),
              ),
            ),
          // Layer 3: scroll-to-bottom FAB
          if (_userScrolledUp)
            Positioned(
              right: 16,
              bottom: 120,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: FloatingActionButton.small(
                  heroTag: 'scroll_to_bottom',
                  onPressed: _scrollToBottom,
                  child: const Icon(Icons.keyboard_double_arrow_down),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setWallpaper() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked != null && mounted) {
        ref
            .read(conversationListProvider.notifier)
            .setWallpaper(widget.conversationId, picked.path);
      }
    } catch (_) {}
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？所有消息将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(conversationListProvider.notifier)
                  .remove(widget.conversationId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String messageId, String currentContent, AIProviderConfig? provider) {
    if (provider == null) return;
    final ctrl = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(labelText: '修改内容'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newText = ctrl.text.trim();
              if (newText.isNotEmpty && newText != currentContent) {
                final conversations = ref.read(conversationListProvider);
                final conv = conversations.firstWhere((c) => c.id == widget.conversationId);
                ref.read(chatProvider(widget.conversationId).notifier).editAndResend(
                  providerConfig: provider,
                  messageId: messageId,
                  newText: newText,
                  overrideModel: conv.modelName,
                  reasoningEffort: conv.reasoningEffort,
                );
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChatAsMarkdown() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final conv = ref.read(conversationListProvider).where((c) => c.id == widget.conversationId).firstOrNull;
    final title = conv?.title ?? '对话记录';
    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln();
    for (final m in chatState.messages) {
      if (m.role == 'user') {
        buf.writeln('## 👤 用户');
      } else {
        buf.writeln('## 🤖 AI');
      }
      buf.writeln();
      buf.writeln(m.content);
      buf.writeln();
    }

    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
    if (dir == null) return;
    try {
      final f = File('$dir/$title.md');
      await f.writeAsString(buf.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${f.path}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Future<void> _exportChatAsTxt() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final conv = ref.read(conversationListProvider).where((c) => c.id == widget.conversationId).firstOrNull;
    final title = conv?.title ?? '对话记录';
    final buf = StringBuffer();
    for (final m in chatState.messages) {
      final role = m.role == 'user' ? '用户' : 'AI';
      buf.writeln('[]');
      buf.writeln(m.content);
      buf.writeln();
    }

    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
    if (dir == null) return;
    try {
      final f = File('$dir/$title.txt');
      await f.writeAsString(buf.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${f.path}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Future<void> _exportSelectedAsMarkdown() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final selected = chatState.messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selected.isEmpty) return;
    final conv = ref.read(conversationListProvider).where((c) => c.id == widget.conversationId).firstOrNull;
    final title = conv?.title ?? '对话记录';
    final buf = StringBuffer();
    buf.writeln('# $title');
    buf.writeln();
    for (final m in selected) {
      final role = m.role == 'user' ? '用户' : 'AI';
      buf.writeln('## $role');
      buf.writeln();
      buf.writeln(m.content);
      buf.writeln();
    }
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
    if (dir == null) return;
    try {
      final f = File('$dir/$title.md');
      await f.writeAsString(buf.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${f.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
    setState(() { _selectedMessageIds.clear(); _multiSelectMode = false; });
  }

  Future<void> _exportSelectedAsTxt() async {
    final chatState = ref.read(chatProvider(widget.conversationId));
    final selected = chatState.messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selected.isEmpty) return;
    final buf = StringBuffer();
    for (final m in selected) {
      final role = m.role == 'user' ? '用户' : 'AI';
      buf.writeln('[]');
      buf.writeln(m.content);
      buf.writeln();
    }
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择保存位置');
    if (dir == null) return;
    try {
      final f = File('$dir/export.txt');
      await f.writeAsString(buf.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: ${f.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
    setState(() { _selectedMessageIds.clear(); _multiSelectMode = false; });
  }
}

class _ModelSelectorChip extends StatelessWidget {
  final AIProviderConfig provider;
  final String currentModel;
  final String? reasoningEffort;
  final void Function(String model, String? effort) onModelChanged;

  const _ModelSelectorChip({
    required this.provider,
    required this.currentModel,
    required this.reasoningEffort,
    required this.onModelChanged,
  });

  static const _effortLabels = {
    'low': '轻松',
    'medium': '适中',
    'high': '深度',
  };

  static const _effortIcons = {
    'low': Icons.flash_on,
    'medium': Icons.balance,
    'high': Icons.psychology,
  };

  void _showSheet(BuildContext context) {
    final theme = Theme.of(context);
    final models = provider.availableModels.isNotEmpty
        ? provider.availableModels
        : [provider.modelName];
    if (!models.contains(currentModel) && currentModel.isNotEmpty) {
      models.insert(0, currentModel);
    }

    String selectedModel = currentModel;
    String? selectedEffort = reasoningEffort;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '切换模型',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      provider.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '模型',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.35,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: models.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final m = models[i];
                      final isSelected = m == selectedModel;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => selectedModel = m);
                          onModelChanged(m, selectedEffort);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.smart_toy_outlined,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '推理深度',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final entry in _effortLabels.entries) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final newEffort = selectedEffort == entry.key ? null : entry.key;
                            setModalState(() => selectedEffort = newEffort);
                            onModelChanged(selectedModel, newEffort);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedEffort == entry.key
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedEffort == entry.key
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                                width: selectedEffort == entry.key ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _effortIcons[entry.key]!,
                                  size: 20,
                                  color: selectedEffort == entry.key
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selectedEffort == entry.key
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selectedEffort == entry.key
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (entry.key != 'high') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelLabel = currentModel.length > 16
        ? '${currentModel.substring(0, 16)}...'
        : currentModel;
    final effortLabel = reasoningEffort != null ? ' · ${_effortLabels[reasoningEffort] ?? reasoningEffort}' : '';

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              '$modelLabel$effortLabel',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
