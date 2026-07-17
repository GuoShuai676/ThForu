import 'package:flutter/material.dart';
import '../models/provider_config.dart';
import '../services/ai_service.dart';

class ProviderFormDialog extends StatefulWidget {
  final AIProviderConfig? existing;
  const ProviderFormDialog({super.key, this.existing});
  @override
  State<ProviderFormDialog> createState() => _ProviderFormDialogState();
}

class _ProviderFormDialogState extends State<ProviderFormDialog> {
  final _nameCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _audioCtrl = TextEditingController();
  final _chatEndpointCtrl = TextEditingController();
  bool _supportsVision = false;
  bool _supportsFile = false;
  bool _obscureApiKey = true;
  String _preset = 'custom';
  final _presets = AIProviderConfig.presets;
  final Map<String, TextEditingController> _headerKeys = {};
  final Map<String, TextEditingController> _headerValues = {};
  final List<String> _headerOrder = [];
  bool _showAdvanced = false;
  bool _testing = false;
  String? _testResult;
  Color? _testColor;
  bool _fetchingModels = false;
  List<String>? _fetchedModels;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _baseUrlCtrl.addListener(_onFieldChanged);
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _baseUrlCtrl.text = e.baseUrl;
      _apiKeyCtrl.text = e.apiKey;
      _modelCtrl.text = e.modelName;
      _supportsVision = e.supportsVision;
      _supportsFile = e.supportsFile;
      _audioCtrl.text = e.audioEndpoint ?? '';
      _chatEndpointCtrl.text = e.customChatEndpoint ?? '';
      for (final entry in e.customHeaders.entries) {
        _headerOrder.add(entry.key);
        _headerKeys[entry.key] = TextEditingController(text: entry.key);
        _headerValues[entry.key] = TextEditingController(text: entry.value);
      }
      _detectPreset();
    }
  }

  void _onFieldChanged() => _detectPreset();
  void _detectPreset() {
    for (final key in _presets.keys) {
      if (_baseUrlCtrl.text == _presets[key]!.baseUrl) {
        if (_preset != key) setState(() => _preset = key);
        return;
      }
    }
    if (_preset != 'custom') setState(() => _preset = 'custom');
  }

  void _applyPreset(String key) {
    setState(() {
      _preset = key;
      _fetchedModels = null;
      _fetchError = null;
    });
    if (key == 'custom') return;
    final p = _presets[key]!;
    _baseUrlCtrl.text = p.baseUrl;
    _nameCtrl.text = p.name;
    _modelCtrl.text = p.modelName;
    _supportsVision = p.supportsVision;
    _supportsFile = p.supportsFile;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _audioCtrl.dispose();
    _chatEndpointCtrl.dispose();
    for (final ctrl in _headerKeys.values) {
      ctrl.dispose();
    }
    for (final ctrl in _headerValues.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addHeader() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _headerOrder.add(id);
      _headerKeys[id] = TextEditingController();
      _headerValues[id] = TextEditingController();
    });
  }

  void _removeHeader(String id) {
    setState(() {
      _headerOrder.remove(id);
      _headerKeys[id]?.dispose();
      _headerValues[id]?.dispose();
      _headerKeys.remove(id);
      _headerValues.remove(id);
    });
  }

  Map<String, String> _collectHeaders() {
    final headers = <String, String>{};
    for (final id in _headerOrder) {
      final key = _headerKeys[id]?.text.trim() ?? '';
      final value = _headerValues[id]?.text.trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) {
        headers[key] = value;
      }
    }
    return headers;
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _baseUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称和 Base URL 不能为空')));
      return;
    }
    String baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    final chatEp = _chatEndpointCtrl.text.trim();
    final config = AIProviderConfig(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      baseUrl: baseUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      modelName: _modelCtrl.text.trim(),
      supportsVision: _supportsVision,
      supportsFile: _supportsFile,
      audioEndpoint: _audioCtrl.text.trim().isEmpty ? null : _audioCtrl.text.trim(),
      customChatEndpoint: chatEp.isEmpty ? null : chatEp,
      customHeaders: _collectHeaders(),
      availableModels: _preset != 'custom'
          ? _presets[_preset]?.availableModels ?? []
          : (widget.existing?.availableModels ?? []),
    );
    Navigator.pop(context, config);
  }

  Future<void> _testConnection() async {
    if (_baseUrlCtrl.text.trim().isEmpty || _apiKeyCtrl.text.trim().isEmpty) {
      setState(() {
        _testResult = '请先填写 Base URL 和 API Key';
        _testColor = Colors.orange;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      String baseUrl = _baseUrlCtrl.text.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      final testConfig = AIProviderConfig(
        name: _nameCtrl.text.trim(),
        baseUrl: baseUrl,
        apiKey: _apiKeyCtrl.text.trim(),
        modelName: _modelCtrl.text.trim(),
        customChatEndpoint: _chatEndpointCtrl.text.trim().isEmpty ? null : _chatEndpointCtrl.text.trim(),
        customHeaders: _collectHeaders(),
      );
      final service = AiService(testConfig);
      final result = await service.testConnection();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = result;
        _testColor = result == '连接成功' ? Colors.green : Colors.red;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '测试失败: $e';
        _testColor = Colors.red;
      });
    }
  }

  Future<void> _fetchModels() async {
    if (_baseUrlCtrl.text.trim().isEmpty || _apiKeyCtrl.text.trim().isEmpty) {
      setState(() {
        _fetchError = '请先填写 Base URL 和 API Key';
      });
      return;
    }
    setState(() {
      _fetchingModels = true;
      _fetchedModels = null;
      _fetchError = null;
    });
    try {
      String baseUrl = _baseUrlCtrl.text.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      final testConfig = AIProviderConfig(
        name: _nameCtrl.text.trim(),
        baseUrl: baseUrl,
        apiKey: _apiKeyCtrl.text.trim(),
        modelName: _modelCtrl.text.trim(),
        customChatEndpoint: _chatEndpointCtrl.text.trim().isEmpty ? null : _chatEndpointCtrl.text.trim(),
        customHeaders: _collectHeaders(),
      );
      final service = AiService(testConfig);
      final models = await service.fetchModels();
      if (!mounted) return;
      setState(() {
        _fetchingModels = false;
        if (models.isNotEmpty) {
          _fetchedModels = models;
        } else {
          _fetchError = '未获取到模型列表（该接口可能不支持）';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingModels = false;
        _fetchError = '获取失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? '编辑大模型' : '添加大模型'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _buildPresetSelector(theme),
        const SizedBox(height: 20),
        _buildSectionTitle('基本信息', theme),
        const SizedBox(height: 8),
        _buildNameField(theme),
        const SizedBox(height: 12),
        _buildBaseUrlField(theme),
        const SizedBox(height: 12),
        _buildApiKeyField(theme),
        const SizedBox(height: 12),
        _buildModelField(theme),
        const SizedBox(height: 20),
        _buildAdvancedSection(theme),
        const SizedBox(height: 20),
        _buildCapabilitySection(theme),
      ]),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presets.keys.map((k) {
              final selected = _preset == k;
              return GestureDetector(
                onTap: () => _applyPreset(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _presets[k]!.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _applyPreset('custom'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _preset == 'custom'
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _preset == 'custom'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: _preset == 'custom' ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 14, color: _preset == 'custom' ? theme.colorScheme.primary : null),
                    const SizedBox(width: 4),
                    Text(
                      '自定义',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _preset == 'custom' ? FontWeight.w600 : FontWeight.w400,
                        color: _preset == 'custom'
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return TextField(
      controller: _nameCtrl,
      decoration: InputDecoration(
        labelText: '显示名称',
        hintText: '如：DeepSeek V4',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.label_outline, size: 20),
      ),
    );
  }

  Widget _buildBaseUrlField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _baseUrlCtrl,
          decoration: InputDecoration(
            labelText: 'Base URL',
            hintText: 'https://api.example.com/v1',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link, size: 20),
            helperText: 'API 的基础地址，不含 /chat/completions',
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField(ThemeData theme) {
    return TextField(
      controller: _apiKeyCtrl,
      obscureText: _obscureApiKey,
      decoration: InputDecoration(
        labelText: 'API Key',
        hintText: 'sk-...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.key, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
        ),
      ),
    );
  }

  Widget _buildModelField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _modelCtrl.text),
          optionsBuilder: (v) {
            List<String> models;
            if (_fetchedModels != null) {
              models = _fetchedModels!;
            } else if (_preset != 'custom') {
              models = _presets[_preset]?.availableModels ?? <String>[];
            } else {
              models = widget.existing?.availableModels ?? <String>[];
            }
            if (v.text.isEmpty) return models;
            return models.where((m) => m.toLowerCase().contains(v.text.toLowerCase()));
          },
          onSelected: (value) => _modelCtrl.text = value,
          fieldViewBuilder: (context, ctrl, focus, submit) {
            ctrl.addListener(() => _modelCtrl.text = ctrl.text);
            return TextField(
              controller: ctrl,
              focusNode: focus,
              decoration: InputDecoration(
                labelText: '模型名称',
                hintText: 'deepseek-chat',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.smart_toy_outlined, size: 20),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _fetchingModels ? null : _fetchModels,
                icon: _fetchingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text(_fetchingModels ? '获取中...' : '从服务器获取模型列表'),
              ),
            ),
          ],
        ),
        if (_fetchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _fetchError!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ),
        if (_fetchedModels != null && _fetchedModels!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _fetchedModels!.take(20).map((m) {
                return GestureDetector(
                  onTap: () => _modelCtrl.text = m,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _modelCtrl.text == m
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _modelCtrl.text == m
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 11,
                        color: _modelCtrl.text == m
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancedSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '高级设置',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '（中转站/自定义端点/请求头）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildAdvancedContent(theme),
          crossFadeState: _showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildAdvancedContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _chatEndpointCtrl,
          decoration: InputDecoration(
            labelText: '自定义 Chat Endpoint（可选）',
            hintText: '完整 URL，如 https://relay.example.com/v1/chat/completions',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.http, size: 20),
            helperText: '留空则自动使用 Base URL + /chat/completions',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _audioCtrl,
          decoration: InputDecoration(
            labelText: '音频转录端点（可选）',
            hintText: '留空则使用 baseUrl/audio/transcriptions',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.record_voice_over, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        _buildHeadersEditor(theme),
        const SizedBox(height: 16),
        _buildConnectionTest(theme),
      ],
    );
  }

  Widget _buildHeadersEditor(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '自定义请求头',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '（中转站可能需要额外 Header）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addHeader,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (_headerOrder.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                '未添加自定义请求头',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          )
        else
          ..._headerOrder.map((id) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _headerKeys[id],
                      decoration: InputDecoration(
                        hintText: 'Header 名称',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(':'),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _headerValues[id],
                      decoration: InputDecoration(
                        hintText: '值',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.error),
                    onPressed: () => _removeHeader(id),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildConnectionTest(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.wifi_tethering,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
            label: Text(_testing ? '测试中...' : '测试连接'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  _testColor == Colors.green ? Icons.check_circle : Icons.error,
                  size: 18,
                  color: _testColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _testColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCapabilitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('能力设置', theme),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('支持图片识别'),
          subtitle: const Text('模型是否支持 Vision API'),
          value: _supportsVision,
          onChanged: (v) => setState(() => _supportsVision = v),
        ),
        SwitchListTile(
          title: const Text('支持文件发送'),
          subtitle: const Text('模型是否支持文件上传'),
          value: _supportsFile,
          onChanged: (v) => setState(() => _supportsFile = v),
        ),
      ],
    );
  }
}
