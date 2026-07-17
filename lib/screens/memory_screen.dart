import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/memory_dao.dart';
import '../state/providers.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchCtrl = TextEditingController();
  List<MemoryEntry> _memories = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dao = ref.read(memoryDaoProvider);
    final results = _query.isEmpty ? await dao.getAll() : await dao.search(_query);
    if (mounted) {
      setState(() {
        _memories = results;
        _loading = false;
      });
    }
  }

  Future<void> _addMemory() async {
    final keyCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加记忆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: valueCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'Tags (逗号分隔)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (result == true && keyCtrl.text.trim().isNotEmpty && valueCtrl.text.trim().isNotEmpty) {
      final dao = ref.read(memoryDaoProvider);
      final tags = tagsCtrl.text.trim().isEmpty ? <String>[] : tagsCtrl.text.split(',').map((t) => t.trim()).toList();
      await dao.upsert(MemoryEntry(key: keyCtrl.text.trim(), value: valueCtrl.text.trim(), tags: tags));
      _load();
    }
  }

  Future<void> _deleteMemory(MemoryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记忆'),
        content: Text('确定删除 "${entry.key}" ？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true) {
      final dao = ref.read(memoryDaoProvider);
      await dao.delete(entry.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: '添加记忆', onPressed: _addMemory),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索记忆...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _memories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology_outlined, size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('暂无记忆', style: TextStyle(color: theme.colorScheme.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final mem = _memories[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(mem.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(mem.value, maxLines: 3, overflow: TextOverflow.ellipsis),
                                  if (mem.tags.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: mem.tags.map((t) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(t, style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer)),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: '${mem.key}: ${mem.value}'));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                                    onPressed: () => _deleteMemory(mem),
                                  ),
                                ],
                              ),
                              isThreeLine: mem.tags.isNotEmpty || mem.value.length > 40,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
