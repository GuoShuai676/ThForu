import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// SVG viewer widget with thumbnail, fullscreen view, and download.
class SvgBlock extends StatefulWidget {
  final String svgString;
  const SvgBlock({super.key, required this.svgString});

  @override
  State<SvgBlock> createState() => _SvgBlockState();
}

class _SvgBlockState extends State<SvgBlock> {
  Size? _svgSize;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _inspectSvg();
  }

  Future<void> _inspectSvg() async {
    try {
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(widget.svgString),
        null,
      );
      final svgSize = pictureInfo.size;
      pictureInfo.picture.dispose();
      if (svgSize.width <= 0 || svgSize.height <= 0) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      if (mounted) setState(() => _svgSize = svgSize);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SvgViewer(svgString: widget.svgString),
      ),
    );
  }

  Future<void> _downloadSvg() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (Platform.isAndroid) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, 'svg_$timestamp.svg'));
        await file.writeAsString(widget.svgString);
        // Use MediaStore to save to gallery
        final result = await MethodChannel('com.example.ai_chat/media')
            .invokeMethod('saveToGallery', {
          'path': file.path,
          'name': 'svg_$timestamp.svg',
          'mimeType': 'image/svg+xml',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result == true ? '已保存到相册' : '保存失败')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仅支持 Android 保存到相册')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome,
                  size: 13,
                  color: _failed
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary),
              const SizedBox(width: 5),
              Text(_failed ? 'SVG 解析失败' : 'SVG 图片',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: _failed
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)),
              if (_svgSize != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _openFullscreen,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('放大',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            if (_svgSize != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final aspect = (_svgSize!.width / _svgSize!.height)
                      .clamp(0.25, 4.0)
                      .toDouble();
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.of(context).size.width * 0.8;
                  final height =
                      (availableWidth / aspect).clamp(120.0, 360.0).toDouble();
                  return GestureDetector(
                    onTap: _openFullscreen,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        height: height,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: SvgPicture.string(
                          widget.svgString,
                          fit: BoxFit.contain,
                          width: availableWidth,
                          height: height,
                        ),
                      ),
                    ),
                  );
                },
              )
            else if (_failed)
              _sourceView(theme)
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sourceView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          widget.svgString,
          maxLines: 15,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

/// Fullscreen SVG viewer — renders at screen resolution, pinch-to-zoom.
class _SvgViewer extends StatelessWidget {
  final String svgString;
  const _SvgViewer({required this.svgString});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SVG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
              maxScale: 12.0,
              minScale: 0.2,
              boundaryMargin: const EdgeInsets.all(160),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SvgPicture.string(
                svgString,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
