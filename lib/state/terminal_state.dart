import '../services/terminal/terminal_runner.dart';
import '../services/terminal/terminal_policy.dart';

class TerminalLine {
  final String command;
  final String cwd;
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  final Duration duration;
  final String? blockedReason;

  const TerminalLine({
    required this.command,
    required this.cwd,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = 0,
    this.timedOut = false,
    this.duration = Duration.zero,
    this.blockedReason,
  });

  bool get isClear => stdout == '__CLEAR__';
}

class TerminalState {
  final List<TerminalLine> lines;
  final String cwd;
  final TerminalMode mode;
  final bool busy;
  final String platformInfo;

  const TerminalState({
    this.lines = const [],
    this.cwd = '',
    this.mode = TerminalMode.sandboxOnly,
    this.busy = false,
    this.platformInfo = '',
  });

  TerminalState copyWith({
    List<TerminalLine>? lines,
    String? cwd,
    TerminalMode? mode,
    bool? busy,
    String? platformInfo,
  }) {
    return TerminalState(
      lines: lines ?? this.lines,
      cwd: cwd ?? this.cwd,
      mode: mode ?? this.mode,
      busy: busy ?? this.busy,
      platformInfo: platformInfo ?? this.platformInfo,
    );
  }
}
