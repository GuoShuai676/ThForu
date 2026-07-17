import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/chat_state.dart';

class ToolExecutionWidget extends StatefulWidget {
  final List<ToolExecInfo> executions;

  const ToolExecutionWidget({super.key, required this.executions});

  @override
  State<ToolExecutionWidget> createState() => _ToolExecutionWidgetState();
}

class _ToolExecutionWidgetState extends State<ToolExecutionWidget> {
  final Set<String> _expanded = {};

  IconData _iconForTool(String name) {
    return switch (name) {
      'terminal' => Icons.terminal,
      'web_search' => Icons.travel_explore,
      'memory' => Icons.psychology,
      'datetime' => Icons.schedule,
      'system' => Icons.info_outline,
      _ => Icons.extension,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.executions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final completed = widget.executions
        .where((e) => e.status == ToolExecStatus.completed)
        .length;
    final failed = widget.executions
        .where((e) => e.status == ToolExecStatus.failed)
        .length;
    final running = widget.executions
        .where((e) => e.status == ToolExecStatus.running)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.build, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Tools',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (running > 0)
                Text('$running running',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary, fontSize: 10)),
              Text('$completed/${widget.executions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline, fontSize: 10)),
              if (failed > 0) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning, size: 12, color: theme.colorScheme.error)
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...widget.executions.map((exec) => _buildExecItem(exec, theme)),
        ],
      ),
    );
  }

  Widget _buildExecItem(ToolExecInfo exec, ThemeData theme) {
    final isRunning = exec.status == ToolExecStatus.running;
    final isError = exec.status == ToolExecStatus.failed;
    final color = isError
        ? theme.colorScheme.error
        : (isRunning ? theme.colorScheme.primary : theme.colorScheme.outline);
    final isExpanded = _expanded.contains(exec.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: exec.output != null
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expanded.remove(exec.id);
                    } else {
                      _expanded.add(exec.id);
                    }
                  });
                }
              : null,
          child: Padding(
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color))
                      : Icon(
                          isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 16,
                          color: color),
                ),
                const SizedBox(width: 6),
                Icon(_iconForTool(exec.name), size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    exec.summary.length > 60
                        ? '${exec.summary.substring(0, 60)}...'
                        : exec.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: color, fontFamily: 'monospace', fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (exec.output != null)
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
        if (isExpanded && exec.output != null)
          Container(
            margin: const EdgeInsets.only(left: 26, bottom: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Output',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 10)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: exec.output!));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied'),
                                duration: Duration(seconds: 1)));
                      },
                      child: Icon(Icons.copy,
                          size: 12, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  exec.output!,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace', fontSize: 10, height: 1.4),
                  maxLines: 20,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        if (isError && exec.output != null && !isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text(
              exec.output!.length > 80
                  ? '${exec.output!.substring(0, 80)}...'
                  : exec.output!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}
