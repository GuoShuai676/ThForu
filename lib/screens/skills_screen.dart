import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/skill.dart';
import '../state/providers.dart';
import '../widgets/skill_form_dialog.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('技能管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addSkill(context, ref),
          ),
        ],
      ),
      body: skills.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('暂无技能',
                      style: TextStyle(color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text('创建技能让 AI 自动切换专家模式',
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.outline)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      skill.enabled
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      color: skill.enabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    title: Text(skill.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (skill.description.isNotEmpty)
                          Text(skill.description,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (skill.triggerKeywords.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              children: skill.triggerKeywords
                                  .take(5)
                                  .map((k) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(k,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme.colorScheme
                                                    .onPrimaryContainer)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        if (skill.toolAllowlist.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                                'Tools: ${skill.toolAllowlist.join(", ")}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.outline)),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: skill.enabled,
                          onChanged: (v) => ref
                              .read(skillListProvider.notifier)
                              .toggleEnabled(skill.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editSkill(context, ref, skill),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: theme.colorScheme.error),
                          onPressed: () => _confirmDelete(
                              context, ref, skill.id, skill.name),
                        ),
                      ],
                    ),
                    isThreeLine: skill.description.isNotEmpty ||
                        skill.triggerKeywords.isNotEmpty,
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addSkill(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<Skill>(
      context,
      MaterialPageRoute(builder: (_) => const SkillFormDialog()),
    );
    if (result != null) {
      ref.read(skillListProvider.notifier).add(result);
    }
  }

  Future<void> _editSkill(
      BuildContext context, WidgetRef ref, Skill skill) async {
    final result = await Navigator.push<Skill>(
      context,
      MaterialPageRoute(builder: (_) => SkillFormDialog(skill: skill)),
    );
    if (result != null) {
      ref.read(skillListProvider.notifier).update(result);
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定要删除「$name」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(skillListProvider.notifier).remove(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
