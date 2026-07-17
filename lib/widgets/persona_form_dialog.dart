import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/persona.dart';
import '../state/providers.dart';
import 'assistant_avatar.dart';

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
    _iconCode = widget.persona?.avatarIcon ?? Icons.smart_toy.codePoint;
    _colorValue = widget.persona?.avatarColor ?? const Color(0xFF6366F1).toARGB32();
  }

  static const _icons = [
    Icons.smart_toy, Icons.psychology, Icons.auto_awesome, Icons.school,
    Icons.science, Icons.face, Icons.person, Icons.work,
    Icons.favorite, Icons.star, Icons.lightbulb, Icons.mic,
    Icons.code, Icons.brush, Icons.music_note, Icons.camera_alt,
    Icons.restaurant, Icons.fitness_center, Icons.flight, Icons.pets,
    Icons.spa, Icons.terrain, Icons.wb_sunny, Icons.nightlight,
    Icons.anchor, Icons.palette, Icons.theater_comedy, Icons.emoji_emotions,
    Icons.shield, Icons.rocket_launch, Icons.diamond, Icons.bolt,
  ];
  static const _colors = [
    Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF06B6D4), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899), Color(0xFF8B5CF6),
    Color(0xFF78716C), Color(0xFF64748B), Color(0xFF14B8A6), Color(0xFFF97316),
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
          Center(
            child: Column(
              children: [
                AssistantAvatar(
                  icon: IconData(_iconCode, fontFamily: 'MaterialIcons'),
                  color: Color(_colorValue),
                  size: 64,
                ),
                const SizedBox(height: 8),
                Text(
                  _nameCtrl.text.isEmpty ? '角色预览' : _nameCtrl.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Color(_colorValue),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '角色名称',
              hintText: '例: 数学老师、编程助手',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: (_) => setState(() {}),
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
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.auto_stories_outlined),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('选择头像', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon.codePoint == _iconCode;
              return GestureDetector(
                onTap: () => setState(() => _iconCode = icon.codePoint),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? Color(_colorValue)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: Color(_colorValue), width: 2)
                        : null,
                  ),
                  child: Icon(icon, color: selected ? Colors.white : null, size: 22),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('选择颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colors.map((color) {
              final selected = color.toARGB32() == _colorValue;
              return GestureDetector(
                onTap: () => setState(() => _colorValue = color.toARGB32()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
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
