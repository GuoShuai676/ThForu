import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expert_panel.dart';
import '../models/provider_config.dart';
import '../state/providers.dart';
import '../state/formula_display_notifier.dart';
import '../widgets/provider_form_dialog.dart';
import '../widgets/expert_panel_form_dialog.dart';
import '../widgets/persona_form_dialog.dart';
import '../models/persona.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _seedColors = [
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.brown,
    Colors.blueGrey,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(providerListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // -- 外观 --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('外观',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('主题颜色', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _seedColors.map((color) {
                        final isSelected =
                            ref.watch(themeProvider).seedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () =>
                              ref.read(themeProvider.notifier).setSeedColor(color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // -- AI 大模型配置 --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('AI 大模型配置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          if (providers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.smart_toy_outlined,
                        size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('还没有配置 AI 大模型',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 8),
                    Text('点击下方按钮添加 DeepSeek、Qwen、OpenAI 或自定义 API',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ...providers.map((p) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.smart_toy,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.modelName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.supportsVision)
                        Icon(Icons.image,
                            size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final result = await Navigator.push<dynamic>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProviderFormDialog(existing: p),
                              ),
                            );
                            if (result != null) {
                              ref
                                  .read(providerListProvider.notifier)
                                  .update(result as dynamic);
                            }
                          } else if (action == 'delete') {
                            _confirmDelete(context, ref, p.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () async {
                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProviderFormDialog()),
                );
                if (result != null) {
                  ref
                      .read(providerListProvider.notifier)
                      .add(result as dynamic);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('添加 AI 大模型'),
            ),
          ),
          const SizedBox(height: 32),
          // -- 角色预设 --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('角色预设',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          _buildPersonaSection(context, ref, theme),
          const SizedBox(height: 32),
          // -- 兼听则明配置 --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('兼听则明配置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          _buildExpertPanelSection(context, ref, theme),
          const SizedBox(height: 32),
          // -- 显示设置 --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('显示设置',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          _buildFormulaDisplaySetting(ref, theme),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('关于',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('1.2.0'),
            leading: Icon(Icons.info_outline),
          ),
          const ListTile(
            title: Text('支持的大模型'),
            subtitle: Text('DeepSeek / Qwen3 / OpenAI / Xiaomi MiMo / 自定义'),
            leading: Icon(Icons.checklist),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除厂商'),
        content: const Text('确定要删除这个 AI 大模型配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(providerListProvider.notifier).remove(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaSection(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final personas = ref.watch(personaListProvider);
    return Column(
      children: [
        if (personas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('还没有角色预设，点击下方按钮创建',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
        ...personas.map((p) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(p.avatarColor),
                child: Icon(IconData(p.avatarIcon, fontFamily: 'MaterialIcons'),
                    color: Colors.white, size: 20),
              ),
              title: Text(p.name),
              subtitle: Text(
                p.systemPrompt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PersonaFormDialog(persona: p)),
                    );
                  } else if (v == 'delete') {
                    ref.read(personaListProvider.notifier).remove(p.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonaFormDialog()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('新建角色'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaDisplaySetting(WidgetRef ref, ThemeData theme) {
    final mode = ref.watch(formulaDisplayProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('公式渲染', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '关闭后显示原始 LaTeX 源码，公式渲染出问题时可以临时关闭',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              SegmentedButton<FormulaDisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: FormulaDisplayMode.off,
                    label: Text('关闭'),
                    icon: Icon(Icons.code),
                  ),
                  ButtonSegment(
                    value: FormulaDisplayMode.scroll,
                    label: Text('滑动'),
                    icon: Icon(Icons.swipe),
                  ),
                  ButtonSegment(
                    value: FormulaDisplayMode.scale,
                    label: Text('缩放'),
                    icon: Icon(Icons.fit_screen),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (sel) {
                  ref
                      .read(formulaDisplayProvider.notifier)
                      .setMode(sel.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpertPanelSection(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final panels = ref.watch(expertPanelListProvider);
    final providers = ref.watch(providerListProvider);

    String? resolveProviderName(String providerId) {
      try {
        final p = providers.firstWhere((p) => p.id == providerId);
        return p.name as String;
      } catch (_) {
        return '未知';
      }
    }

    if (panels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text('还没有创建兼听面板',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Text('兼听则明会将问题同时发送给多个 AI，然后由网关汇总答案',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  if (providers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先添加 AI 大模型')),
                    );
                    return;
                  }
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExpertPanelFormDialog()),
                  );
                  if (result != null) {
                    ref
                        .read(expertPanelListProvider.notifier)
                        .add(result as ExpertPanel);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('创建兼听面板'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...panels.map((panel) {
          final gatewayName = resolveProviderName(panel.gatewayProviderId);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: Icon(Icons.psychology,
                    color: theme.colorScheme.onTertiaryContainer),
              ),
              title: Text(panel.name),
              subtitle: Text(
                  '${panel.expertProviderIds.length} 位兼听 · 网关: $gatewayName'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group,
                      size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        final result = await Navigator.push<dynamic>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ExpertPanelFormDialog(existing: panel),
                          ),
                        );
                        if (result != null) {
                          ref
                              .read(expertPanelListProvider.notifier)
                              .update(result as ExpertPanel);
                        }
                      } else if (action == 'delete') {
                        _confirmDeletePanel(context, ref, panel.id, panel.name);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(
                          value: 'delete',
                          child:
                              Text('删除', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () async {
              if (providers.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先添加 AI 大模型')),
                );
                return;
              }
              final result = await Navigator.push<dynamic>(
                context,
                MaterialPageRoute(
                    builder: (_) => const ExpertPanelFormDialog()),
              );
              if (result != null) {
                ref
                    .read(expertPanelListProvider.notifier)
                    .add(result as ExpertPanel);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('创建兼听面板'),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePanel(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除兼听面板'),
        content: Text('确定要删除「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(expertPanelListProvider.notifier).remove(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
