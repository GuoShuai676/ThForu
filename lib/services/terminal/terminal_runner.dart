import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'terminal_policy.dart';

class TerminalResult {
  final String command;
  final String cwd;
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? blockedReason;

  Duration get duration => endedAt.difference(startedAt);

  TerminalResult({
    required this.command,
    required this.cwd,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = 0,
    this.timedOut = false,
    required this.startedAt,
    required this.endedAt,
    this.blockedReason,
  });

  bool get isSuccess => exitCode == 0 && !timedOut && blockedReason == null;
}

class TerminalRunner {
  String _cwd;
  TerminalPolicy _policy;
  Process? _shell;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  Completer<String>? _outputCompleter;
  String _pendingStdout = '';
  String _pendingStderr = '';
  bool _shellReady = false;

  TerminalRunner({
    String? cwd,
    TerminalPolicy policy = const TerminalPolicy(),
  })  : _cwd = cwd ?? '',
        _policy = policy;

  String get cwd => _cwd;
  TerminalMode get mode => _policy.mode;
  TerminalPolicy get policy => _policy;

  static Future<TerminalRunner> create({
    TerminalPolicy policy = const TerminalPolicy(),
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final runner = TerminalRunner(cwd: docsDir.path, policy: policy);
    if (policy.mode == TerminalMode.fullShell) {
      await runner._startShell();
    }
    return runner;
  }

  Future<void> _startShell() async {
    try {
      if (Platform.isWindows) {
        _shell = await Process.start('cmd', [], workingDirectory: _cwd);
      } else if (Platform.isAndroid) {
        if (File('/system/bin/sh').existsSync()) {
          _shell =
              await Process.start('/system/bin/sh', [], workingDirectory: _cwd);
        } else {
          return;
        }
      } else if (Platform.isIOS) {
        return;
      } else {
        _shell = await Process.start('/bin/sh', [], workingDirectory: _cwd);
      }
      _stdoutSub = _shell!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        _pendingStdout += data;
        _outputCompleter?.complete(_pendingStdout);
      });
      _stderrSub = _shell!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        _pendingStderr += data;
      });
      _shellReady = true;
    } catch (_) {
      _shellReady = false;
    }
  }

  Future<void> updatePolicy(TerminalPolicy newPolicy) async {
    final oldMode = _policy.mode;
    _policy = newPolicy;
    if (newPolicy.mode != oldMode) {
      await dispose();
      if (newPolicy.mode == TerminalMode.fullShell) {
        await _startShell();
      }
    }
  }

  Future<TerminalResult> run(String command,
      {Duration timeout = const Duration(seconds: 30)}) async {
    final startedAt = DateTime.now();
    final trimmed = command.trim();

    if (_policy.isBlocked(trimmed)) {
      return TerminalResult(
        command: trimmed,
        cwd: _cwd,
        stderr: 'Blocked: command matches dangerous pattern',
        exitCode: 1,
        startedAt: startedAt,
        endedAt: DateTime.now(),
        blockedReason: 'Dangerous command blocked by policy',
      );
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts.first;
    final args = parts.skip(1).toList();

    if (_policy.mode == TerminalMode.sandboxOnly || !_shellReady) {
      return _runBuiltin(cmd, args, trimmed, startedAt, timeout);
    }

    final builtinResult = _tryBuiltin(cmd, args, trimmed, startedAt);
    if (builtinResult != null) return builtinResult;

    return _runShell(trimmed, startedAt, timeout);
  }

  TerminalResult? _tryBuiltin(
      String cmd, List<String> args, String fullCmd, DateTime startedAt) {
    switch (cmd) {
      case 'cd':
        return _builtinCd(args, fullCmd, startedAt);
      case 'pwd':
        return TerminalResult(
            command: fullCmd,
            cwd: _cwd,
            stdout: _cwd,
            startedAt: startedAt,
            endedAt: DateTime.now());
      case 'clear':
      case 'cls':
        return TerminalResult(
            command: fullCmd,
            cwd: _cwd,
            stdout: '__CLEAR__',
            startedAt: startedAt,
            endedAt: DateTime.now());
      case 'mkdir':
        return _builtinMkdir(args, fullCmd, startedAt);
      case 'touch':
        return _builtinTouch(args, fullCmd, startedAt);
      case 'write':
        return _builtinWrite(args, fullCmd, startedAt, append: false);
      case 'append':
        return _builtinWrite(args, fullCmd, startedAt, append: true);
      case 'rm':
      case 'del':
        return _builtinRm(args, fullCmd, startedAt);
      case 'cat':
      case 'type':
        return _builtinCat(args, fullCmd, startedAt);
      case 'ls':
      case 'dir':
        return _builtinLs(args, fullCmd, startedAt);
      default:
        return null;
    }
  }

  Future<TerminalResult> _runBuiltin(String cmd, List<String> args,
      String fullCmd, DateTime startedAt, Duration timeout) async {
    final builtin = _tryBuiltin(cmd, args, fullCmd, startedAt);
    if (builtin != null) return builtin;
    if (_policy.mode == TerminalMode.sandboxOnly) {
      return TerminalResult(
        command: fullCmd,
        cwd: _cwd,
        stderr:
            'Command "$cmd" not available in sandbox mode. Available: cd, pwd, ls, cat, mkdir, touch, write, append, rm, clear',
        exitCode: 127,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      );
    }
    return _runShell(fullCmd, startedAt, timeout);
  }

  TerminalResult _builtinCd(
      List<String> args, String fullCmd, DateTime startedAt) {
    String target;
    if (args.isEmpty) {
      target = Directory(_cwd).parent.path;
    } else {
      target = _resolvePath(args.first);
    }
    if (Directory(target).existsSync()) {
      _cwd = target;
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: _cwd,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    return TerminalResult(
        command: fullCmd,
        cwd: _cwd,
        stderr: 'cd: no such directory: ${args.isEmpty ? ".." : args.first}',
        exitCode: 1,
        startedAt: startedAt,
        endedAt: DateTime.now());
  }

  TerminalResult _builtinMkdir(
      List<String> args, String fullCmd, DateTime startedAt) {
    if (args.isEmpty) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'mkdir: missing operand',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    try {
      Directory(_resolvePath(args.first)).createSync(recursive: true);
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: 'Created: ${args.first}',
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'mkdir: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  TerminalResult _builtinTouch(
      List<String> args, String fullCmd, DateTime startedAt) {
    if (args.isEmpty) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'touch: missing operand',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    try {
      File(_resolvePath(args.first)).createSync(recursive: true);
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: 'Created: ${args.first}',
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'touch: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  TerminalResult _builtinWrite(
      List<String> args, String fullCmd, DateTime startedAt,
      {required bool append}) {
    if (args.length < 2) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr:
              '${append ? "append" : "write"}: usage: ${append ? "append" : "write"} <file> <content>',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    if (!_policy.canWrite) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'Write not allowed in current permission mode',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    try {
      final path = _resolvePath(args.first);
      final content = args.skip(1).join(' ');
      File(path).writeAsStringSync(content,
          mode: append ? FileMode.append : FileMode.write);
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: '${append ? "Appended" : "Written"}: ${args.first}',
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: '${append ? "append" : "write"}: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  TerminalResult _builtinRm(
      List<String> args, String fullCmd, DateTime startedAt) {
    if (args.isEmpty) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'rm: missing operand',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    if (!_policy.canDelete) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'Delete not allowed in current permission mode',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    try {
      final path = _resolvePath(args.first);
      if (Directory(path).existsSync()) {
        Directory(path).deleteSync(recursive: true);
      } else if (File(path).existsSync()) {
        File(path).deleteSync();
      } else {
        return TerminalResult(
            command: fullCmd,
            cwd: _cwd,
            stderr: 'rm: not found: ${args.first}',
            exitCode: 1,
            startedAt: startedAt,
            endedAt: DateTime.now());
      }
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: 'Deleted: ${args.first}',
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'rm: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  TerminalResult _builtinCat(
      List<String> args, String fullCmd, DateTime startedAt) {
    if (args.isEmpty) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'cat: missing operand',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
    try {
      final content = File(_resolvePath(args.first)).readAsStringSync();
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: content,
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'cat: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  TerminalResult _builtinLs(
      List<String> args, String fullCmd, DateTime startedAt) {
    try {
      final target = args.isEmpty ? _cwd : _resolvePath(args.first);
      final entities = Directory(target).listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      final buf = StringBuffer();
      for (final e in entities) {
        final name = e.path.split(Platform.pathSeparator).last;
        final isDir = e is Directory;
        final size = e is File ? e.lengthSync() : 0;
        buf.writeln(
            '${isDir ? "[DIR]  " : "       "} $name${!isDir && size > 0 ? "  ($size bytes)" : ""}');
      }
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stdout: buf.toString().trimRight(),
          startedAt: startedAt,
          endedAt: DateTime.now());
    } catch (e) {
      return TerminalResult(
          command: fullCmd,
          cwd: _cwd,
          stderr: 'ls: $e',
          exitCode: 1,
          startedAt: startedAt,
          endedAt: DateTime.now());
    }
  }

  Future<TerminalResult> _runShell(
      String command, DateTime startedAt, Duration timeout) async {
    if (_shellReady && _shell != null) {
      _pendingStdout = '';
      _pendingStderr = '';
      _outputCompleter = Completer<String>();
      _shell!.stdin.writeln(command);
      try {
        await _outputCompleter!.future.timeout(timeout);
        await Future.delayed(const Duration(milliseconds: 200));
        return TerminalResult(
          command: command,
          cwd: _cwd,
          stdout: _pendingStdout.trimRight(),
          stderr: _pendingStderr.trimRight(),
          exitCode: 0,
          startedAt: startedAt,
          endedAt: DateTime.now(),
        );
      } on TimeoutException {
        return TerminalResult(
          command: command,
          cwd: _cwd,
          stdout: _pendingStdout.trimRight(),
          stderr: 'Command timed out after ${timeout.inSeconds}s',
          exitCode: 124,
          timedOut: true,
          startedAt: startedAt,
          endedAt: DateTime.now(),
        );
      }
    }

    try {
      ProcessResult result;
      if (Platform.isWindows) {
        result =
            await Process.run('cmd', ['/c', command], workingDirectory: _cwd)
                .timeout(timeout);
      } else {
        result = await Process.run('/bin/sh', ['-c', command],
                workingDirectory: _cwd)
            .timeout(timeout);
      }
      return TerminalResult(
        command: command,
        cwd: _cwd,
        stdout: (result.stdout as String).trimRight(),
        stderr: (result.stderr as String).trimRight(),
        exitCode: result.exitCode,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      );
    } on TimeoutException {
      return TerminalResult(
        command: command,
        cwd: _cwd,
        stderr: 'Command timed out after ${timeout.inSeconds}s',
        exitCode: 124,
        timedOut: true,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      );
    } catch (e) {
      return TerminalResult(
        command: command,
        cwd: _cwd,
        stderr: 'Error: $e',
        exitCode: 1,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      );
    }
  }

  String _resolvePath(String path) {
    if (path.startsWith('~')) {
      return _cwd + path.substring(1);
    }
    if (path.startsWith('/') || (path.length > 1 && path[1] == ':')) {
      return path;
    }
    if (path == '..') {
      return Directory(_cwd).parent.path;
    }
    return '$_cwd${Platform.pathSeparator}$path';
  }

  Future<void> dispose() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _shell?.kill();
    _shell = null;
    _shellReady = false;
  }
}
