import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AIProviderConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String modelName;
  final bool supportsVision;
  final bool supportsFile;
  final String? audioEndpoint;
  final List<String> availableModels;

  AIProviderConfig({
    String? id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.supportsVision = false,
    this.supportsFile = false,
    this.audioEndpoint,
    this.availableModels = const [],
  }) : id = id ?? _uuid.v4();

  String get chatEndpoint => '$baseUrl/chat/completions';
  String get transcriptionEndpoint =>
      audioEndpoint ?? '$baseUrl/audio/transcriptions';

  AIProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? modelName,
    bool? supportsVision,
    bool? supportsFile,
    String? audioEndpoint,
    List<String>? availableModels,
  }) {
    return AIProviderConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsFile: supportsFile ?? this.supportsFile,
      audioEndpoint: audioEndpoint ?? this.audioEndpoint,
      availableModels: availableModels ?? this.availableModels,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'modelName': modelName,
        'supportsVision': supportsVision,
        'supportsFile': supportsFile,
        'audioEndpoint': audioEndpoint,
        'availableModels': availableModels,
      };

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String,
      modelName: json['modelName'] as String,
      supportsVision: json['supportsVision'] as bool? ?? false,
      supportsFile: json['supportsFile'] as bool? ?? false,
      audioEndpoint: json['audioEndpoint'] as String?,
      availableModels: (json['availableModels'] as List?)?.cast<String>() ?? [],
    );
  }

  static final Map<String, AIProviderConfig> presets = {
    'deepseek': AIProviderConfig(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      apiKey: '',
      modelName: 'deepseek-chat',
      supportsVision: false,
      availableModels: ['deepseek-chat', 'deepseek-reasoner'],
    ),
    'qwen': AIProviderConfig(
      name: 'Qwen3 Max',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: '',
      modelName: 'qwen3-max',
      supportsVision: true,
      availableModels: ['qwen3-max', 'qwen3-plus', 'qwen3-vl-max', 'qwen3-vl-plus', 'qwen3-coder'],
    ),
    'openai': AIProviderConfig(
      name: 'OpenAI GPT-4.1',
      baseUrl: 'https://api.openai.com/v1',
      apiKey: '',
      modelName: 'gpt-4.1',
      supportsVision: true,
      availableModels: ['gpt-4.1', 'gpt-4.1-mini', 'gpt-4o', 'o4-mini', 'o3'],
    ),
    'mimo': AIProviderConfig(
      name: 'Xiaomi MiMo',
      baseUrl: 'https://api.xiaomimimo.com/v1',
      apiKey: '',
      modelName: 'mimo-v2.5',
      supportsVision: true,
      supportsFile: true,
      availableModels: ['mimo-v2.5', 'mimo-v2-omni'],
    ),
  };
}
