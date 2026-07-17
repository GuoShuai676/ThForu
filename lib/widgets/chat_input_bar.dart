import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ai_service.dart';
import '../state/providers.dart';
import 'image_preview_sheet.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final Future<void> Function({
    required String text,
    List<String>? imagePaths,
    List<String>? filePaths,
    List<String>? fileNames,
    bool? deepSearch,
    bool? useTools,
  }) onSend;
  final VoidCallback? onMessageSent;
  final bool supportsVision;
  final bool supportsFile;
  final String? hintText;
  final String? prefillText;
  final String? followUpContent;
  final VoidCallback? onCancelFollowUp;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onMessageSent,
    this.supportsVision = false,
    this.supportsFile = false,
    this.hintText,
    this.prefillText,
    this.followUpContent,
    this.onCancelFollowUp,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _selectedImages = [];
  final List<String> _selectedFilePaths = [];
  final List<String> _selectedFileNames = [];
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSending = false;
  bool _deepSearch = false;
  bool _useTools = false;
  late final AnimationController _attachAnimCtrl;

  @override
  void initState() {
    super.initState();
    _attachAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefillText != null &&
        widget.prefillText != oldWidget.prefillText) {
      _textController.text = widget.prefillText!;
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _attachAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty && _selectedFilePaths.isEmpty)
      return;

    final imagePaths =
        _selectedImages.isNotEmpty ? List<String>.from(_selectedImages) : null;
    final filePaths = _selectedFilePaths.isNotEmpty
        ? List<String>.from(_selectedFilePaths)
        : null;
    final fileNames = _selectedFileNames.isNotEmpty
        ? List<String>.from(_selectedFileNames)
        : null;

    setState(() => _isSending = true);
    try {
      await widget.onSend(
        text: text,
        imagePaths: imagePaths,
        filePaths: filePaths,
        fileNames: fileNames,
        deepSearch: _deepSearch,
        useTools: _useTools,
      );

      if (!mounted) return;
      _textController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedFilePaths.clear();
        _selectedFileNames.clear();
      });
      widget.onMessageSent?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          setState(() => _selectedImages.addAll(paths));
          _attachAnimCtrl.forward(from: 0.0);
        }
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    final imageService = ref.read(imageServiceProvider);
    final path = await imageService.pickFromCamera();
    if (path != null) {
      setState(() => _selectedImages.add(path));
      _attachAnimCtrl.forward(from: 0.0);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final file in result.files) {
            if (file.path != null) {
              _selectedFilePaths.add(file.path!);
              _selectedFileNames.add(file.name);
            }
          }
        });
        _attachAnimCtrl.forward(from: 0.0);
      }
    } catch (_) {}
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip,
      'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' => Icons.audio_file,
      'mp4' || 'avi' || 'mkv' || 'mov' || 'wmv' => Icons.video_file,
      'txt' || 'md' || 'log' => Icons.article,
      'py' ||
      'js' ||
      'ts' ||
      'dart' ||
      'java' ||
      'c' ||
      'cpp' ||
      'h' =>
        Icons.code,
      'json' || 'xml' || 'yaml' || 'yml' || 'toml' => Icons.data_object,
      'html' || 'css' || 'htm' => Icons.language,
      _ => Icons.insert_drive_file,
    };
  }

  Color _colorForFile(String name, ThemeData theme) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Colors.red,
      'doc' || 'docx' => Colors.blue,
      'xls' || 'xlsx' || 'csv' => Colors.green,
      'ppt' || 'pptx' => Colors.orange,
      'zip' || 'rar' || '7z' => Colors.brown,
      'mp3' || 'wav' || 'flac' => Colors.purple,
      'mp4' || 'avi' || 'mkv' => Colors.deepPurple,
      'py' || 'js' || 'ts' || 'dart' => Colors.teal,
      'jpg' || 'jpeg' || 'png' || 'gif' => Colors.pink,
      _ => theme.colorScheme.primary,
    };
  }

  Future<void> _startRecording() async {
    final audioService = ref.read(audioServiceProvider);
    final hasPermission = await audioService.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要录音权限')),
        );
      }
      return;
    }
    setState(() => _isRecording = true);
    await audioService.startRecording();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    final audioService = ref.read(audioServiceProvider);
    final path = await audioService.stopRecording();
    if (path == null) return;

    setState(() => _isTranscribing = true);

    final providers = ref.read(providerListProvider);
    if (providers.isEmpty) {
      setState(() => _isTranscribing = false);
      return;
    }
    final aiService = AiService(providers.first);
    try {
      final text = await aiService.transcribeAudio(path);
      _textController.text += text;
    } on AiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音转录失败: $e')),
        );
      }
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  void _showImagePreview() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ImagePreviewSheet(
        images: _selectedImages,
        onRemove: (index) {
          setState(() => _selectedImages.removeAt(index));
          if (_selectedImages.isEmpty) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.followUpContent != null &&
              widget.followUpContent!.isNotEmpty)
            _buildFollowUpBar(theme),
          if (_selectedImages.isNotEmpty) _buildImagePreview(theme),
          if (_selectedFilePaths.isNotEmpty) _buildFileCard(theme),
          _buildToggleRow(theme),
          _buildInputRow(theme),
        ],
      ),
    );
  }

  Widget _buildFollowUpBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.followUpContent!.length > 30
                  ? '${widget.followUpContent!.substring(0, 30)}...'
                  : widget.followUpContent!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onCancelFollowUp,
            child:
                Icon(Icons.close, size: 18, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return Container(
      height: 82,
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: _showImagePreview,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_selectedImages[index]),
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      if (index == 0 && _selectedImages.length > 1)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${_selectedImages.length - 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: AnimatedBuilder(
        animation: _attachAnimCtrl,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_attachAnimCtrl.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${_selectedFilePaths.length} 个文件',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedFilePaths.clear();
                      _selectedFileNames.clear();
                    }),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 14, color: theme.colorScheme.outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_selectedFilePaths.length, (i) {
                final name = i < _selectedFileNames.length
                    ? _selectedFileNames[i]
                    : 'file';
                final icon = _iconForFile(name);
                final color = _colorForFile(name, theme);
                int? fileSize;
                try {
                  fileSize = File(_selectedFilePaths[i]).lengthSync();
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ),
                      if (fileSize != null)
                        Text(
                          _formatFileSize(fileSize),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline, fontSize: 10),
                        ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedFilePaths.removeAt(i);
                          _selectedFileNames.removeAt(i);
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.close,
                              size: 16, color: theme.colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          _buildModeChip(
            theme,
            icon: Icons.explore_outlined,
            label: '深度搜索',
            active: _deepSearch,
            onTap: () => setState(() => _deepSearch = !_deepSearch),
          ),
          const SizedBox(width: 8),
          _buildModeChip(
            theme,
            icon: Icons.construction_outlined,
            label: '工具',
            active: _useTools,
            onTap: () => setState(() => _useTools = !_useTools),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.supportsFile)
            IconButton(
              icon: Icon(
                Icons.attach_file,
                color: _selectedFilePaths.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              tooltip: '添加文件',
              onPressed: _pickFile,
              iconSize: 22,
            ),
          if (widget.supportsVision)
            IconButton(
              icon: Icon(
                Icons.image_outlined,
                color: _selectedImages.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              tooltip: '添加图片',
              onPressed: () => _showImageSourceSheet(),
              iconSize: 22,
            ),
          IconButton(
            icon: _isTranscribing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color:
                        _isRecording ? Colors.red : theme.colorScheme.outline,
                  ),
            tooltip: '语音输入',
            onPressed: _isRecording ? _stopRecording : _startRecording,
            iconSize: 22,
          ),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessage();
                }
              },
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      _isRecording ? '正在录音...' : widget.hintText ?? '输入消息...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.outline.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                enabled: !_isRecording,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: (!_isSending &&
                    (_textController.text.trim().isNotEmpty ||
                        _selectedImages.isNotEmpty ||
                        _selectedFilePaths.isNotEmpty))
                ? _sendMessage
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (!_isSending &&
                        (_textController.text.trim().isNotEmpty ||
                            _selectedImages.isNotEmpty ||
                            _selectedFilePaths.isNotEmpty))
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              child: _isSending
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: (_textController.text.trim().isNotEmpty ||
                              _selectedImages.isNotEmpty ||
                              _selectedFilePaths.isNotEmpty)
                          ? Colors.white
                          : theme.colorScheme.outline.withValues(alpha: 0.5),
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
          ],
        ),
      ),
    );
  }
}
