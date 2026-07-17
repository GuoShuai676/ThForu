import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/skill.dart';

class SkillFormDialog extends ConsumerStatefulWidget {
  final Skill? skill;
  const SkillFormDialog({super.key, this.skill});

  @override
  ConsumerState<SkillFormDialog> createState() => _SkillFormDialogState();
}

class _SkillFormDialogState extends ConsumerState<SkillFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _keywordsCtrl;
  late final TextEditingController _toolsCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.skill?.name ?? '');
    _descCtrl = TextEditingController(text: widget.skill?.description ?? '');
    _promptCtrl = TextEditingController(text: widget.skill?.systemPrompt ?? '');
    _keywordsCtrl = TextEditingController(
        text: widget.skill?.triggerKeywords.join(', ') ?? '');
    _toolsCtrl = TextEditingController(
        text: widget.skill?.toolAllowlist.join(', ') ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _keywordsCtrl.dispose();
    _toolsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入技能名称')));
      return;
    }

    final keywords = _keywordsCtrl.text.trim().isEmpty
        ? <String>[]
        : _keywordsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    final tools = _toolsCtrl.text.trim().isEmpty
        ? <String>[]
        : _toolsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    final skill = Skill(
      id: widget.skill?.id,
      name: name,
      description: _descCtrl.text.trim(),
      systemPrompt: _promptCtrl.text.trim(),
      triggerKeywords: keywords,
      toolAllowlist: tools,
      enabled: widget.skill?.enabled ?? true,
    );

    Navigator.pop(context, skill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.skill != null ? '编辑技能' : '新建技能'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '技能名称',
              hintText: '例：代码审查、翻译助手',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: '描述',
              hintText: '简要说明这个技能做什么',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '系统提示词',
              hintText: '你是...请按照...回答',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsCtrl,
            decoration: const InputDecoration(
              labelText: '触发关键词',
              hintText: '代码, review, 审查（逗号分隔，自动匹配）',
              border: OutlineInputBorder(),
              helperText: '用户消息包含这些词时自动激活此技能',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _toolsCtrl,
            decoration: const InputDecoration(
              labelText: '可用工具',
              hintText: 'terminal, web_search, memory（逗号分隔，留空=全部）',
              border: OutlineInputBorder(),
              helperText: '限制此技能可使用的工具，留空表示使用全部可用工具',
            ),
          ),
        ],
      ),
    );
  }
}
