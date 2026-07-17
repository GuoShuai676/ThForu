import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expert_panel.dart';
import '../models/provider_config.dart';
import '../state/providers.dart';

class ExpertPanelFormDialog extends ConsumerStatefulWidget {
  final ExpertPanel? existing;

  const ExpertPanelFormDialog({super.key, this.existing});

  @override
  ConsumerState<ExpertPanelFormDialog> createState() =>
      _ExpertPanelFormDialogState();
}

class _ExpertPanelFormDialogState extends ConsumerState<ExpertPanelFormDialog> {
  final _nameCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  String? _gatewayProviderId;
  final _selectedExpertIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _promptCtrl.text = e.synthesisPrompt;
      _gatewayProviderId = e.gatewayProviderId;
      _selectedExpertIds.addAll(e.expertProviderIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProviders =
        ref.watch(providerListProvider).cast<AIProviderConfig>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? '编辑兼听面板' : '创建兼听面板'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '面板名称',
              hintText: '如：兼听则明',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('选择兼听专家（至少 2 个）',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          if (allProviders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('请先在「AI 厂商配置」中添加 API',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            )
          else
            ...allProviders.map((p) {
              final isSelected = _selectedExpertIds.contains(p.id);
              final isGateway = _gatewayProviderId == p.id;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: CheckboxListTile(
                  title: Text(p.name),
                  subtitle: Text(p.modelName),
                  secondary: isGateway
                      ? Icon(Icons.gavel,
                          color: theme.colorScheme.primary, size: 20)
                      : null,
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedExpertIds.add(p.id);
                      } else {
                        _selectedExpertIds.remove(p.id);
                        if (_gatewayProviderId == p.id) {
                          _gatewayProviderId = null;
                        }
                      }
                    });
                  },
                ),
              );
            }),
          const SizedBox(height: 24),
          Text('选择网关 API（汇总各方意见）',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          if (allProviders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('没有可用的 API'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _gatewayProviderId,
              decoration: const InputDecoration(
                labelText: '网关 API',
                hintText: '选择一个 API 作为汇总网关',
                border: OutlineInputBorder(),
              ),
              items: allProviders
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.modelName})'),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _gatewayProviderId = v;
                  if (v != null) {
                    _selectedExpertIds.add(v);
                  }
                });
              },
            ),
          const SizedBox(height: 24),
          Text('自定义汇总指令（可选）',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '留空使用默认指令：你是一位兼听则明总结助手...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('网关会收到各方的回答，并进行纠错和综合汇总',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('面板名称不能为空')),
      );
      return;
    }
    if (_selectedExpertIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择 2 个兼听专家')),
      );
      return;
    }
    if (_gatewayProviderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择网关 API')),
      );
      return;
    }

    final panel = ExpertPanel(
      id: widget.existing?.id,
      name: name,
      expertProviderIds: _selectedExpertIds.toList(),
      gatewayProviderId: _gatewayProviderId!,
      synthesisPrompt: _promptCtrl.text.trim(),
    );

    Navigator.pop(context, panel);
  }
}
