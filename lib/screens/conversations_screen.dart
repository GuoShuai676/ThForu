import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expert_panel.dart';
import '../state/providers.dart';
import '../widgets/conversation_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Set<String> _contentMatchIds = {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q == _query) return;
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _contentMatchIds = {};
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });
    if (q.isNotEmpty) {
      _searchContent(q);
    }
  }

  Future<void> _searchContent(String q) async {
    final dao = ref.read(messageDaoProvider);
    final ids = await dao.searchConversationIds(q);
    if (mounted && _query == q) {
      setState(() {
        _contentMatchIds = ids;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationListProvider);
    final providers = ref.watch(providerListProvider);
    final theme = Theme.of(context);

    final sorted = [...conversations]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final filtered = _query.isEmpty
        ? sorted
        : sorted.where((c) {
            if (c.title.toLowerCase().contains(_query)) return true;
            return _contentMatchIds.contains(c.id);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ThForu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索会话（标题或内容）...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSearching)
                            const SizedBox(
                                width: 20, height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                            },
                          ),
                        ],
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          if (filtered.isEmpty && _query.isNotEmpty)
            Expanded(
              child: Center(
                child: Text('没有找到匹配的会话',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            )
          else if (conversations.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('还没有会话',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 8),
                    Text('点击右下角按钮开始聊天',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final conv = filtered[index];
                  final provider = providers.cast<dynamic>().firstWhere(
                        (p) => p.id == conv.providerConfigId,
                        orElse: () => null,
                      );
                  // Resolve expert panel name
                  String? expertPanelName;
                  if (conv.expertPanelId != null) {
                    final panels = ref.watch(expertPanelListProvider);
                    try {
                      expertPanelName = panels
                          .firstWhere((p) => p.id == conv.expertPanelId)
                          .name;
                    } catch (_) {}
                  }
                  return ConversationTile(
                    conversation: conv,
                    providerName: provider?.name,
                    isExpertMode: conv.expertPanelId != null,
                    expertPanelName: expertPanelName,
                    onTap: () {
                      Navigator.pushNamed(context, '/chat',
                          arguments: conv.id);
                    },
                    onDelete: () {
                      ref
                          .read(conversationListProvider.notifier)
                          .remove(conv.id);
                    },
                    onRename: (newTitle) {
                      ref
                          .read(conversationListProvider.notifier)
                          .updateTitle(conv.id, newTitle);
                    },
                    onTogglePin: () {
                      ref
                          .read(conversationListProvider.notifier)
                          .togglePin(conv.id);
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startNewChat(providers),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _startNewChat(List providers) async {
    if (providers.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('没有配置 AI 大模型'),
          content:
              const Text('请先去设置中添加一个 AI 大模型（如 DeepSeek、OpenAI）。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/settings');
              },
              child: const Text('去设置'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      return;
    }

    // Ask user to choose mode: normal or expert
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择模式'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'normal'),
            child: const ListTile(
              leading: Icon(Icons.chat),
              title: Text('普通模式'),
              subtitle: Text('使用单个 AI 模型回答'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'expert'),
            child: const ListTile(
              leading: Icon(Icons.psychology, color: Colors.purple),
              title: Text('兼听则明'),
              subtitle: Text('多个 AI 同时回答，网关汇总纠错'),
            ),
          ),
        ],
      ),
    );

    if (mode == null || !mounted) return;

    // Normal mode: optionally pick a persona first
    String? personaId;
    if (mode == 'normal') {
      final personas = ref.read(personaListProvider);
      if (personas.isNotEmpty && mounted) {
        personaId = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('选择角色（可选）'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, null),
                child: const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('无角色'),
                  subtitle: Text('直接使用 AI 默认风格'),
                ),
              ),
              ...personas.map((p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, p.id),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(p.avatarColor),
                        child: Icon(
                            IconData(p.avatarIcon,
                                fontFamily: 'MaterialIcons'),
                            color: Colors.white,
                            size: 20),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        p.systemPrompt.length > 40
                            ? '${p.systemPrompt.substring(0, 40)}...'
                            : p.systemPrompt,
                      ),
                    ),
                  )),
            ],
          ),
        );
      }
    }

    if (mode == 'normal') {
      final selected = await showDialog<dynamic>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择 AI 模型'),
          children: providers.map<Widget>((p) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: ListTile(
                leading: const Icon(Icons.smart_toy),
                title: Text(p.name),
                subtitle: Text(p.modelName),
              ),
            );
          }).toList(),
        ),
      );

      if (selected != null) {
        final conv = await ref.read(conversationListProvider.notifier).create(
              providerConfigId: selected.id,
              modelName: selected.modelName,
              personaId: personaId,
            );
        if (mounted) {
          Navigator.pushNamed(context, '/chat', arguments: conv.id);
        }
      }
    } else {
      // Expert mode
      final panels = ref.read(expertPanelListProvider);
      if (panels.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('没有兼听面板'),
              content: const Text('请先去设置中创建一个兼听面板。'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/settings');
                  },
                  child: const Text('去设置'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final selectedPanel = await showDialog<ExpertPanel>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择兼听面板'),
          children: panels.map<Widget>((panel) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, panel),
              child: ListTile(
                leading: const Icon(Icons.psychology, color: Colors.purple),
                title: Text(panel.name),
                subtitle: Text('${panel.expertProviderIds.length} 位兼听'),
              ),
            );
          }).toList(),
        ),
      );

      if (selectedPanel != null) {
        final conv =
            await ref.read(conversationListProvider.notifier).create(
                  providerConfigId: selectedPanel.gatewayProviderId,
                  modelName: 'expert',
                  expertPanelId: selectedPanel.id,
                );
        if (mounted) {
          Navigator.pushNamed(context, '/chat', arguments: conv.id);
        }
      }
    }
  }
}
