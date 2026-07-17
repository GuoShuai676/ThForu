import 'package:flutter/material.dart';
import '../state/chat_state.dart';

class ToolExecutionWidget extends StatelessWidget {
  final List<ToolExecInfo> executions;

  const ToolExecutionWidget({super.key, required this.executions});

  IconData _iconForTool(String name) {
    return switch (name) {
      'terminal' => Icons.terminal,
      'web_search' => Icons.travel_explore,
      'memory' => Icons.psychology,
      'datetime' => Icons.schedule,
      _ => Icons.extension,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (executions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.build, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '工具调用',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${executions.where((e) => e.status == ToolExecStatus.completed).length}/${executions.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...executions.map((exec) => _buildExecItem(exec, theme)),
        ],
      ),
    );
  }

  Widget _buildExecItem(ToolExecInfo exec, ThemeData theme) {
    final isRunning = exec.status == ToolExecStatus.running;
    final isError = exec.status == ToolExecStatus.failed;
    final color = isError ? theme.colorScheme.error : (isRunning ? theme.colorScheme.primary : theme.colorScheme.outline);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: isRunning
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    size: 16,
                    color: color,
                  ),
          ),
          const SizedBox(width: 6),
          Icon(_iconForTool(exec.name), size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              exec.summary.length > 50 ? '${exec.summary.substring(0, 50)}...' : exec.summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
