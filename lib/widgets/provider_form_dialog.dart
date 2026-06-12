import 'package:flutter/material.dart';
import '../models/provider_config.dart';

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
  bool _supportsVision = false;
  bool _supportsFile = false;
  bool _obscureApiKey = true;
  String _preset = 'custom';
  final _presets = AIProviderConfig.presets;

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
    setState(() => _preset = key);
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
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _baseUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称和 Base URL 不能为空')));
      return;
    }
    String baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    final config = AIProviderConfig(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      baseUrl: baseUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      modelName: _modelCtrl.text.trim(),
      supportsVision: _supportsVision,
      supportsFile: _supportsFile,
      audioEndpoint: _audioCtrl.text.trim().isEmpty ? null : _audioCtrl.text.trim(),
      availableModels: _preset != 'custom'
          ? _presets[_preset]?.availableModels ?? []
          : (widget.existing?.availableModels ?? []),
    );
    Navigator.pop(context, config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? '编辑大模型' : '添加大模型'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: [
            ..._presets.keys.map((k) => ButtonSegment(
                  value: k, label: Text(_presets[k]!.name, style: const TextStyle(fontSize: 12)))),
            const ButtonSegment(value: 'custom', label: Text('自定义', style: TextStyle(fontSize: 12))),
          ],
          selected: {_preset},
          onSelectionChanged: (s) => _applyPreset(s.first),
        ),
        const SizedBox(height: 20),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '显示名称', hintText: '如：DeepSeek V4', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _baseUrlCtrl, decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://api.deepseek.com/v1', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _apiKeyCtrl, obscureText: _obscureApiKey,
            decoration: InputDecoration(labelText: 'API Key', hintText: 'sk-...', border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey)))),
        const SizedBox(height: 16),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _modelCtrl.text),
          optionsBuilder: (v) {
            final models = _preset != 'custom' ? _presets[_preset]?.availableModels ?? <String>[] : <String>[];
            if (v.text.isEmpty) return models;
            return models.where((m) => m.toLowerCase().contains(v.text.toLowerCase()));
          },
          onSelected: (value) => _modelCtrl.text = value,
          fieldViewBuilder: (context, ctrl, focus, submit) {
            ctrl.addListener(() => _modelCtrl.text = ctrl.text);
            return TextField(controller: ctrl, focusNode: focus, decoration: const InputDecoration(labelText: '模型名称', hintText: 'deepseek-chat', border: OutlineInputBorder()));
          },
        ),
        const SizedBox(height: 16),
        TextField(controller: _audioCtrl, decoration: const InputDecoration(labelText: '音频转录端点（可选）', hintText: '留空则使用 baseUrl/audio/transcriptions', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        SwitchListTile(title: const Text('支持图片识别'), subtitle: const Text('模型是否支持 Vision API'), value: _supportsVision, onChanged: (v) => setState(() => _supportsVision = v)),
        SwitchListTile(title: const Text('支持文件发送'), subtitle: const Text('模型是否支持文件上传'), value: _supportsFile, onChanged: (v) => setState(() => _supportsFile = v)),
      ]),
    );
  }
}
