import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../state/terminal_state.dart';
import '../services/terminal/terminal_policy.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    _history.add(trimmed);
    _historyIndex = _history.length;
    _controller.clear();
    ref.read(terminalProvider.notifier).runCommand(trimmed);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _historyUp() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _controller.text = _history[_historyIndex];
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  void _historyDown() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _controller.text = _history[_historyIndex];
    } else {
      _historyIndex = _history.length;
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final termState = ref.watch(terminalProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final inputBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final promptColor = isDark ? Colors.greenAccent : Colors.green.shade700;
    final outputColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F);
    final errorColor = isDark ? Colors.redAccent : Colors.red.shade700;
    final modeLabel =
        termState.mode == TerminalMode.fullShell ? 'Full Shell' : 'Sandbox';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                termState.cwd.split(Platform.pathSeparator).last,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: termState.mode == TerminalMode.fullShell
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              modeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: termState.mode == TerminalMode.fullShell
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () => ref.read(terminalProvider.notifier).clear(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: bg,
          child: Column(
            children: [
              if (termState.mode == TerminalMode.sandboxOnly)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.orange.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sandbox mode: built-in commands only. Enable full shell in settings.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: termState.lines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terminal,
                                size: 40, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('ThForu Terminal',
                                style: TextStyle(
                                    color: theme.colorScheme.outline)),
                            Text(termState.platformInfo,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline)),
                            const SizedBox(height: 4),
                            Text('Type "help" for available commands',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: termState.lines.length,
                        itemBuilder: (context, index) {
                          return _buildLine(termState.lines[index], theme,
                              outputColor, errorColor, promptColor);
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  border: Border(
                      top: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3))),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text('\$ ',
                        style: TextStyle(
                            color: promptColor,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(skipTraversal: true),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp)
                              _historyUp();
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) _historyDown();
                          }
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !termState.busy,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Enter command...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: _submit,
                        ),
                      ),
                    ),
                    if (termState.busy)
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: Icon(Icons.send_rounded,
                            color: theme.colorScheme.primary, size: 20),
                        onPressed: () => _submit(_controller.text),
                      ),
                  ],
                ),
              ),
              SafeArea(top: false, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(TerminalLine line, ThemeData theme, Color outputColor,
      Color errorColor, Color promptColor) {
    return GestureDetector(
      onLongPress: () {
        final text = '${line.command}\n${line.stdout}\n${line.stderr}'.trim();
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Copied'), duration: Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${line.cwd.split(Platform.pathSeparator).last} \$ ',
                  style: TextStyle(
                      color: promptColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    line.command,
                    style: TextStyle(
                        color: promptColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${line.duration.inMilliseconds}ms',
                  style: TextStyle(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                      fontSize: 10),
                ),
              ],
            ),
            if (line.blockedReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '[BLOCKED] ${line.blockedReason}',
                  style: TextStyle(
                      color: errorColor, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            if (line.stdout.isNotEmpty && !line.isClear)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line.stdout,
                  style: TextStyle(
                      color: outputColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            if (line.stderr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line.stderr,
                  style: TextStyle(
                      color: errorColor,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            if (line.exitCode != 0 && line.blockedReason == null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '[exit ${line.exitCode}]${line.timedOut ? " (timed out)" : ""}',
                  style: TextStyle(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
