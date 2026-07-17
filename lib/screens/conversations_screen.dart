import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expert_panel.dart';
import '../models/provider_config.dart';
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
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

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
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _query = q;
      _isSearching = true;
    });
    _searchMessages(q);
  }

  Future<void> _searchMessages(String q) async {
    final dao = ref.read(messageDaoProvider);
    final conversations = ref.read(conversationListProvider);
    final results = <Map<String, dynamic>>[];

    // Search conversations by title first (fast)
    for (final conv in conversations) {
      if (conv.title.toLowerCase().contains(q)) {
        results.add({
          'conversationId': conv.id,
          'conversationTitle': conv.title,
          'messageId': '',
          'content': conv.title,
          'role': 'title',
          'createdAt': conv.updatedAt,
        });
      }
    }

    // Search messages (limit to avoid lag)
    int count = 0;
    for (final conv in conversations) {
      if (count >= 20) break; // Limit total results
      try {
        final messages = await dao.getByConversation(conv.id);
        for (final msg in messages.reversed) { // Search from newest
          if (count >= 20) break;
          if (msg.content.toLowerCase().contains(q)) {
            results.add({
              'conversationId': conv.id,
              'conversationTitle': conv.title,
              'messageId': msg.id,
              'content': msg.content,
              'role': msg.role,
              'createdAt': msg.createdAt,
            });
            count++;
          }
        }
      } catch (_) {}
    }

    results.sort((a, b) =>
        (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    if (mounted && _query == q) {
      setState(() {
        _searchResults = results;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ThForu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: '收藏',
            onPressed: () => Navigator.pushNamed(context, '/favorites'),
          ),
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
                hintText: '搜索消息内容...',
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
          if (_query.isNotEmpty)
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text('没有找到匹配的消息',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final r = _searchResults[index];
                            final content = r['content'] as String;
                            final convTitle = r['conversationTitle'] as String;
                            final role = r['role'] as String;
                            final convId = r['conversationId'] as String;

                            // Build snippet around match
                            final lowerContent = content.toLowerCase();
                            final matchPos = lowerContent.indexOf(_query);
                            String snippet;
                            if (matchPos >= 0) {
                              final start = (matchPos - 30).clamp(0, content.length);
                              final end = (matchPos + _query.length + 60)
                                  .clamp(0, content.length);
                              snippet = (start > 0 ? '…' : '') +
                                  content.substring(start, end).replaceAll('\n', ' ') +
                                  (end < content.length ? '…' : '');
                            } else {
                              snippet = content.replaceAll('\n', ' ').substring(
                                  0, 100.clamp(0, content.length));
                              if (content.length > 100) snippet += '…';
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              final convId = r['conversationId'] as String;
                              final msgId = r['messageId'] as String;
                              Navigator.pushNamed(context, '/chat',
                                  arguments: {'conversationId': convId, 'messageId': msgId});
                            },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: role == 'user'
                                            ? theme.colorScheme.primaryContainer
                                            : theme.colorScheme.tertiaryContainer,
                                        child: Icon(
                                          role == 'user' ? Icons.person : Icons.smart_toy,
                                          size: 16,
                                          color: role == 'user'
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.tertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  convTitle,
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.outline,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  role == 'user' ? '你' : 'AI',
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              snippet,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall,
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
            )
          else
            Expanded(
              child: sorted.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final conv = sorted[index];
                        final provider = providers.cast<dynamic>().firstWhere(
                              (p) => p.id == conv.providerConfigId,
                              orElse: () => null,
                            );
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
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return _ModelPickerDialog(providers: providers);
        },
      );

      if (selected != null) {
        final providerConfig = selected['provider'] as AIProviderConfig;
        final modelName = selected['model'] as String;
        final conv = await ref.read(conversationListProvider.notifier).create(
              providerConfigId: providerConfig.id,
              modelName: modelName,
              personaId: personaId,
            );
        if (mounted) {
          Navigator.pushNamed(context, '/chat', arguments: conv.id);
        }
      }
    } else {
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

class _ModelPickerDialog extends StatefulWidget {
  final List providers;
  const _ModelPickerDialog({required this.providers});

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  AIProviderConfig? _selectedProvider;
  String? _selectedModel;
  final _customModelCtrl = TextEditingController();
  bool _useCustomModel = false;

  @override
  void dispose() {
    _customModelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedProvider == null) {
      return SimpleDialog(
        title: const Text('选择 AI 提供商'),
        children: widget.providers.map<Widget>((p) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _selectedProvider = p;
                final models = p.availableModels;
                if (models.isNotEmpty) {
                  _selectedModel = models.first;
                } else {
                  _selectedModel = p.modelName;
                  _customModelCtrl.text = p.modelName;
                }
              });
            },
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: Text(p.name),
              subtitle: Text(p.modelName),
            ),
          );
        }).toList(),
      );
    }

    final provider = _selectedProvider!;
    final models = provider.availableModels.isNotEmpty
        ? provider.availableModels
        : [provider.modelName];

    return AlertDialog(
      title: Text('${provider.name} - 选择模型'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (models.length > 1 || models.first.isNotEmpty) ...[
              Text('可用模型', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (ctx, i) {
                    final model = models[i];
                    final isSelected = !_useCustomModel && _selectedModel == model;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? theme.colorScheme.primary : null,
                        size: 20,
                      ),
                      title: Text(model, style: TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _selectedModel = model;
                          _useCustomModel = false;
                        });
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 16),
            ],
            Row(
              children: [
                Checkbox(
                  value: _useCustomModel,
                  onChanged: (v) {
                    setState(() {
                      _useCustomModel = v ?? false;
                      if (_useCustomModel && _customModelCtrl.text.isEmpty) {
                        _customModelCtrl.text = _selectedModel ?? '';
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                const Text('自定义模型名称'),
              ],
            ),
            if (_useCustomModel)
              TextField(
                controller: _customModelCtrl,
                decoration: const InputDecoration(
                  hintText: '输入模型名称',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _selectedModel = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedModel != null && _selectedModel!.isNotEmpty
              ? () => Navigator.pop(context, {
                  'provider': provider,
                  'model': _useCustomModel ? _customModelCtrl.text.trim() : _selectedModel,
                })
              : null,
          child: const Text('开始对话'),
        ),
      ],
    );
  }
}
