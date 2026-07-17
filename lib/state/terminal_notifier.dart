import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/terminal/terminal_runner.dart';
import '../services/terminal/terminal_policy.dart';
import 'terminal_state.dart';

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalRunner? _runner;

  TerminalNotifier()
      : super(TerminalState(
          platformInfo:
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        ));

  Future<void> init({TerminalPolicy policy = const TerminalPolicy()}) async {
    _runner = await TerminalRunner.create(policy: policy);
    state = state.copyWith(
      cwd: _runner!.cwd,
      mode: _runner!.mode,
    );
  }

  Future<void> updatePolicy(TerminalPolicy policy) async {
    await _runner?.updatePolicy(policy);
    state = state.copyWith(mode: policy.mode);
  }

  Future<void> runCommand(String command) async {
    if (_runner == null) return;
    state = state.copyWith(busy: true);

    final result = await _runner!.run(command);

    if (result.stdout == '__CLEAR__') {
      state = state.copyWith(
        lines: [],
        cwd: _runner!.cwd,
        busy: false,
      );
      return;
    }

    final line = TerminalLine(
      command: result.command,
      cwd: result.cwd,
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
      timedOut: result.timedOut,
      duration: result.duration,
      blockedReason: result.blockedReason,
    );

    state = state.copyWith(
      lines: [...state.lines, line],
      cwd: _runner!.cwd,
      busy: false,
    );
  }

  void clear() {
    state = state.copyWith(lines: []);
  }

  @override
  void dispose() {
    _runner?.dispose();
    super.dispose();
  }
}
