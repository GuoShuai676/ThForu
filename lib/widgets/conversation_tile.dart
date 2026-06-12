import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String? providerName;
  final String? lastMessage;
  final bool isExpertMode;
  final String? expertPanelName;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRename;
  final VoidCallback? onTogglePin;

  const ConversationTile({
    super.key,
    required this.conversation,
    this.providerName,
    this.lastMessage,
    this.isExpertMode = false,
    this.expertPanelName,
    required this.onTap,
    this.onDelete,
    this.onRename,
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('MM/dd HH:mm').format(conversation.updatedAt);

    return Slidable(
      key: Key(conversation.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '重命名',
          ),
          SlidableAction(
            onPressed: (_) => onTogglePin?.call(),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: conversation.isPinned ? '取消置顶' : '置顶',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showRenameDialog(context),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conversation.isPinned)
              Icon(Icons.push_pin, size: 14, color: theme.colorScheme.primary),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.chat_bubble_outline,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
          ],
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              if (isExpertMode && expertPanelName != null)
                WidgetSpan(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '兼听·$expertPanelName',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (providerName != null && !isExpertMode)
                TextSpan(
                  text: providerName,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary, fontSize: 11),
                ),
              if ((providerName != null || (isExpertMode && expertPanelName != null)) &&
                  lastMessage != null)
                const TextSpan(text: '  '),
              if (lastMessage != null)
                TextSpan(
                  text: lastMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(timeStr, style: theme.textTheme.labelSmall),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              onDelete?.call();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                onRename?.call(newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
