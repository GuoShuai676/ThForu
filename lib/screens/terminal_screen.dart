import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_TermLine> _lines = [];
  bool _running = false;
  String _cwd = '';

  @override
  void initState() {
    super.initState();
    _cwd = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '~';
    _lines.add(_TermLine.output('ThForu Terminal v1.0'));
    _lines.add(_TermLine.output('Type commands to execute. Long-press output to copy.'));
    _lines.add(_TermLine.output(''));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) return;
    setState(() {
      _lines.add(_TermLine.input('\$ $command', _cwd));
      _running = true;
    });
    _scrollToBottom();

    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run('cmd', ['/c', command], workingDirectory: home);
      } else {
        result = await Process.run('/bin/sh', ['-c', command], workingDirectory: home);
      }

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (stdout.isNotEmpty) {
        setState(() => _lines.add(_TermLine.output(stdout)));
      }
      if (stderr.isNotEmpty) {
        setState(() => _lines.add(_TermLine.error(stderr)));
      }
      setState(() => _lines.add(_TermLine.output('[exit ${result.exitCode}]')));
    } catch (e) {
      setState(() => _lines.add(_TermLine.error('Error: $e')));
    }

    setState(() => _running = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final inputBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final promptColor = isDark ? Colors.greenAccent : Colors.green.shade700;
    final outputColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F);
    final errorColor = isDark ? Colors.redAccent : Colors.red.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () => setState(() {
              _lines.clear();
              _lines.add(_TermLine.output(''));
            }),
          ),
        ],
      ),
      body: Container(
        color: bg,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  Color color;
                  FontWeight weight;
                  if (line.type == _LineType.input) {
                    color = promptColor;
                    weight = FontWeight.w600;
                  } else if (line.type == _LineType.error) {
                    color = errorColor;
                    weight = FontWeight.w400;
                  } else {
                    color = outputColor;
                    weight = FontWeight.w400;
                  }
                  return GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: line.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        line.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: color,
                          fontWeight: weight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('\$ ', style: TextStyle(color: promptColor, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_running,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Enter command...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (cmd) {
                        _executeCommand(cmd);
                        _controller.clear();
                      },
                    ),
                  ),
                  if (_running)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary, size: 20),
                      onPressed: () {
                        _executeCommand(_controller.text);
                        _controller.clear();
                      },
                    ),
                ],
              ),
            ),
            SafeArea(top: false, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

enum _LineType { input, output, error }

class _TermLine {
  final String text;
  final _LineType type;
  final String? cwd;

  _TermLine(this.text, this.type, {this.cwd});
  factory _TermLine.input(String text, String cwd) => _TermLine(text, _LineType.input, cwd: cwd);
  factory _TermLine.output(String text) => _TermLine(text, _LineType.output);
  factory _TermLine.error(String text) => _TermLine(text, _LineType.error);
}
