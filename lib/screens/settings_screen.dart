import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expert_panel.dart';
import '../models/provider_config.dart';
import '../state/providers.dart';
import '../state/formula_display_notifier.dart';
import '../models/companion_config.dart';
import '../widgets/provider_form_dialog.dart';
import '../widgets/expert_panel_form_dialog.dart';
import '../widgets/persona_form_dialog.dart';
import '../widgets/pixel_companion/hanli_skin.dart';
import '../widgets/pixel_companion/pixel_painter.dart';
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
                            ref.watch(themeProvider).seedColor.toARGB32() ==
                                color.toARGB32();
                        return GestureDetector(
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setSeedColor(color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\u6df1\u8272\u6a21\u5f0f',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('\u8ddf\u968f\u7cfb\u7edf'),
                            icon: Icon(Icons.settings_brightness)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('\u6d45\u8272'),
                            icon: Icon(Icons.light_mode)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('\u6df1\u8272'),
                            icon: Icon(Icons.dark_mode)),
                      ],
                      selected: {ref.watch(themeProvider).themeMode},
                      onSelectionChanged: (sel) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(sel.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildCompanionSection(context, ref, theme),

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
          _buildToolSettingsSection(ref, theme),
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

  Widget _buildToolSettingsSection(WidgetRef ref, ThemeData theme) {
    final settings = ref.watch(toolSettingsProvider);
    final notifier = ref.read(toolSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('工具与权限',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('启用 AI 工具'),
                    subtitle: const Text('允许 AI 自动调用工具完成任务'),
                    value: settings.toolsEnabled,
                    onChanged: (v) => notifier.setToolsEnabled(v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('终端'),
                    subtitle: const Text('执行 shell 命令'),
                    value: settings.terminalEnabled && settings.toolsEnabled,
                    onChanged: settings.toolsEnabled
                        ? (v) => notifier.setTerminalEnabled(v)
                        : null,
                  ),
                  SwitchListTile(
                    title: const Text('联网搜索'),
                    subtitle: const Text('搜索网页获取实时信息'),
                    value: settings.webSearchEnabled && settings.toolsEnabled,
                    onChanged: settings.toolsEnabled
                        ? (v) => notifier.setWebSearchEnabled(v)
                        : null,
                  ),
                  SwitchListTile(
                    title: const Text('记忆'),
                    subtitle: const Text('跨会话记住用户信息'),
                    value: settings.memoryEnabled && settings.toolsEnabled,
                    onChanged: settings.toolsEnabled
                        ? (v) => notifier.setMemoryEnabled(v)
                        : null,
                  ),
                  SwitchListTile(
                    title: const Text('日期时间'),
                    subtitle: const Text('获取当前时间信息'),
                    value: settings.datetimeEnabled && settings.toolsEnabled,
                    onChanged: settings.toolsEnabled
                        ? (v) => notifier.setDatetimeEnabled(v)
                        : null,
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('终端权限'),
                    subtitle: Text(_permLabel(settings.terminalPermission)),
                    trailing: DropdownButton<String>(
                      value: settings.terminalPermission,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'read_only', child: Text('只读')),
                        DropdownMenuItem(
                            value: 'write_sandbox', child: Text('允许写入')),
                        DropdownMenuItem(
                            value: 'delete_sandbox', child: Text('允许删除')),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setTerminalPermission(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _permLabel(String perm) {
    return switch (perm) {
      'read_only' => '只读命令',
      'write_sandbox' => '允许写入沙箱',
      'delete_sandbox' => '允许删除沙箱',
      _ => perm,
    };
  }

  Widget _buildCompanionSection(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final config = ref.watch(companionConfigProvider);
    final notifier = ref.read(companionConfigProvider.notifier);
    const colors = [
      Color(0xFF2F7D57),
      Color(0xFF4F46E5),
      Color(0xFF0EA5E9),
      Color(0xFF7C3AED),
      Color(0xFFB45309),
      Color(0xFFBE123C),
      Color(0xFF374151),
    ];
    const accents = [
      Color(0xFFD6A84F),
      Color(0xFF22D3EE),
      Color(0xFFF97316),
      Color(0xFFA7F3D0),
      Color(0xFFFDE68A),
      Color(0xFFF9A8D4),
      Color(0xFFE5E7EB),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 120,
                    child: CustomPaint(
                      painter: HanLiPainter(
                        mood: PixelMood.idle,
                        breathValue: 0.5,
                        primaryColor: config.primaryColor,
                        accentColor: config.accentColor,
                        skinColor: config.skinColor,
                        hairColor: config.hairColor,
                      ),
                      size: const Size(76, 114),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('助手宠物', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          '在聊天页陪伴、显示状态，并可拖动停靠。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _editCompanionName(context, config.name, ref),
                              icon: const Icon(Icons.badge_outlined),
                              label: Text(config.name),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => notifier.resetHanLi(),
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('恢复韩立'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示宠物'),
                value: config.enabled,
                onChanged: notifier.setEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示名字'),
                value: config.showName,
                onChanged: notifier.setShowName,
              ),
              const SizedBox(height: 8),
              Text('造型', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<CompanionSkin>(
                segments: const [
                  ButtonSegment(
                    value: CompanionSkin.hanLi,
                    label: Text('韩立'),
                    icon: Icon(Icons.self_improvement),
                  ),
                  ButtonSegment(
                    value: CompanionSkin.codex,
                    label: Text('Codex'),
                    icon: Icon(Icons.smart_toy_outlined),
                  ),
                ],
                selected: {config.skin},
                onSelectionChanged: (sel) => notifier.setSkin(sel.first),
              ),
              const SizedBox(height: 16),
              Text('主色', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: colors.map((color) {
                  return _ColorDot(
                    color: color,
                    selected: color.toARGB32() == config.primaryColor,
                    onTap: () => notifier.setPrimaryColor(color.toARGB32()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('点缀色', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: accents.map((color) {
                  return _ColorDot(
                    color: color,
                    selected: color.toARGB32() == config.accentColor,
                    onTap: () => notifier.setAccentColor(color.toARGB32()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('大小', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      min: 56,
                      max: 96,
                      divisions: 8,
                      value: config.size.clamp(56, 96).toDouble(),
                      onChanged: notifier.setSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCompanionName(
      BuildContext context, String currentName, WidgetRef ref) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('宠物名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名字',
            hintText: '例如：韩立',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await ref.read(companionConfigProvider.notifier).setName(result);
    }
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
                  ref.read(formulaDisplayProvider.notifier).setMode(sel.first);
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
                  Icon(Icons.group, size: 18, color: theme.colorScheme.outline),
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

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.onSurface : Colors.white,
              width: selected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
