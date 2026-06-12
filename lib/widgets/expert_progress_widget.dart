import 'package:flutter/material.dart';
import '../state/chat_state.dart';

class ExpertProgressWidget extends StatelessWidget {
  final ExpertPhase phase;
  final Map<String, ExpertStatus> statuses;

  const ExpertProgressWidget({
    super.key,
    required this.phase,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                phase == ExpertPhase.querying
                    ? Icons.psychology
                    : Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                phase == ExpertPhase.querying ? '正在请教各方...' : '正在综合各方意见...',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          if (phase == ExpertPhase.querying && statuses.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...statuses.entries.map((entry) {
              final status = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    _StatusIcon(state: status.state, theme: theme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.providerName,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      _statusText(status.state),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    if (status.errorMessage != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          status.errorMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _statusText(ExpertStatusState state) {
    switch (state) {
      case ExpertStatusState.pending:
        return '等待中';
      case ExpertStatusState.streaming:
        return '回复中...';
      case ExpertStatusState.completed:
        return '已完成';
      case ExpertStatusState.failed:
        return '失败';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final ExpertStatusState state;
  final ThemeData theme;

  const _StatusIcon({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ExpertStatusState.pending:
        return Icon(Icons.circle_outlined,
            size: 12, color: theme.colorScheme.outline);
      case ExpertStatusState.streaming:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        );
      case ExpertStatusState.completed:
        return const Icon(Icons.check_circle, size: 12, color: Colors.green);
      case ExpertStatusState.failed:
        return const Icon(Icons.error, size: 12, color: Colors.red);
    }
  }
}
