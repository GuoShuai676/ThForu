import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/persona.dart';
import '../state/providers.dart';

class PersonaFormDialog extends ConsumerStatefulWidget {
  final Persona? persona;
  const PersonaFormDialog({super.key, this.persona});

  @override
  ConsumerState<PersonaFormDialog> createState() => _PersonaFormDialogState();
}

class _PersonaFormDialogState extends ConsumerState<PersonaFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _promptCtrl;
  late int _iconCode;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.persona?.name ?? '');
    _promptCtrl = TextEditingController(text: widget.persona?.systemPrompt ?? '');
    _iconCode = widget.persona?.avatarIcon ?? Icons.person.codePoint;
    _colorValue = widget.persona?.avatarColor ?? Colors.indigo.toARGB32();
  }

  static const _icons = [
    Icons.person, Icons.school, Icons.work, Icons.science,
    Icons.psychology, Icons.auto_awesome, Icons.smart_toy,
    Icons.face, Icons.favorite, Icons.star, Icons.lightbulb,
    Icons.mic, Icons.code, Icons.brush, Icons.music_note,
  ];
  static const _colors = [
    Colors.indigo, Colors.blue, Colors.teal, Colors.green,
    Colors.orange, Colors.red, Colors.pink, Colors.purple,
    Colors.brown, Colors.blueGrey,
  ];

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final prompt = _promptCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入角色名称')),
      );
      return;
    }
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入身份预设提示词')),
      );
      return;
    }
    final persona = Persona(
      id: widget.persona?.id,
      name: name,
      systemPrompt: prompt,
      avatarIcon: _iconCode,
      avatarColor: _colorValue,
    );
    if (widget.persona != null) {
      ref.read(personaListProvider.notifier).update(persona);
    } else {
      ref.read(personaListProvider.notifier).add(persona);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.persona != null ? '编辑角色' : '新建角色'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '角色名称',
              hintText: '例: 数学老师、编程助手',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '身份预设提示词',
              hintText: '例: 你是一位耐心的数学老师，用简单易懂的语言解释概念...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('选择头像', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon.codePoint == _iconCode;
              return GestureDetector(
                onTap: () => setState(() => _iconCode = icon.codePoint),
                child: CircleAvatar(
                  backgroundColor: selected
                      ? Color(_colorValue)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(icon, color: selected ? Colors.white : null),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('选择颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((color) {
              final selected = color.toARGB32() == _colorValue;
              return GestureDetector(
                onTap: () => setState(() => _colorValue = color.toARGB32()),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
