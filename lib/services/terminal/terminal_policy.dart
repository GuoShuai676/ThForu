import 'dart:async';

enum TerminalMode { fullShell, sandboxOnly }

enum TerminalPermission { readOnly, writeSandbox, deleteSandbox }

class TerminalPolicy {
  final TerminalMode mode;
  final Set<TerminalPermission> permissions;
  final List<String> blockedPatterns;

  const TerminalPolicy({
    this.mode = TerminalMode.sandboxOnly,
    this.permissions = const {},
    this.blockedPatterns = const [
      'rm -rf /',
      'rm -rf /*',
      'del /s /q C:\\',
      'del /s /q C:\\Windows',
      'del /s /q C:\\Program Files',
      'format C:',
      'format D:',
      'mkfs',
      'dd if=',
    ],
  });

  bool get canWrite =>
      permissions.contains(TerminalPermission.writeSandbox) ||
      permissions.contains(TerminalPermission.deleteSandbox);

  bool get canDelete => permissions.contains(TerminalPermission.deleteSandbox);

  bool isBlocked(String command) {
    final lower = command.toLowerCase().trim();
    for (final pattern in blockedPatterns) {
      if (lower.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }

  TerminalPolicy copyWith({
    TerminalMode? mode,
    Set<TerminalPermission>? permissions,
    List<String>? blockedPatterns,
  }) {
    return TerminalPolicy(
      mode: mode ?? this.mode,
      permissions: permissions ?? this.permissions,
      blockedPatterns: blockedPatterns ?? this.blockedPatterns,
    );
  }
}
