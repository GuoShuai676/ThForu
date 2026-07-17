import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/provider_config.dart';
import '../models/message.dart';

class AiService {
  final AIProviderConfig config;
  final Dio _dio;

  AiService(this.config)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ));

  Stream<String> streamChat({
    required List<Message> history,
    required String newUserMessage,
    List<String>? imagePaths,
    String? overrideModel,
    String? reasoningEffort,
    bool Function()? isCancelled,
  }) async* {
    final messages = <Map<String, dynamic>>[];

    final hasCurrentImages = imagePaths != null && imagePaths.isNotEmpty;
    for (final msg in history) {
      if (!hasCurrentImages && msg.hasImages) {
        messages.add({
          'role': msg.role,
          'content': msg.content.isEmpty ? '[图片]' : msg.content,
        });
      } else {
        messages.add(msg.toOpenAIMessage());
      }
    }

    final userMsg = Message(
      conversationId: '',
      role: 'user',
      content: newUserMessage,
      imagePaths: imagePaths,
    );
    messages.add(userMsg.toOpenAIMessage());

    final model = overrideModel ?? config.modelName;
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
    };

    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      body['reasoning_effort'] = reasoningEffort;
    }

    try {
      final response = await _dio.post(
        config.chatEndpoint,
        data: body,
        options: Options(
          headers: config.allHeaders,
          responseType: ResponseType.stream,
          validateStatus: (s) => s! < 500,
        ),
      );

      if (response.statusCode == 404) {
        try {
          await response.data.stream.drain<void>();
        } catch (_) {}
        yield* _nonStreamingChat(history, newUserMessage, imagePaths,
            overrideModel, reasoningEffort, isCancelled);
        return;
      }
      if (response.statusCode != 200) {
        throw AiException('HTTP ${response.statusCode}');
      }

      final bodyStream = response.data.stream.cast<List<int>>();
      final lines =
          bodyStream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in lines) {
        if (isCancelled != null && isCancelled()) return;
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null) yield delta;
          } catch (_) {}
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        yield* _nonStreamingChat(history, newUserMessage, imagePaths,
            overrideModel, reasoningEffort, isCancelled);
        return;
      }
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时，请检查网络后重试',
        DioExceptionType.receiveTimeout => '响应超时（5min），请重试',
        DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
        DioExceptionType.cancel => '请求已取消',
        _ => switch (e.response?.statusCode) {
            401 => 'API Key 无效',
            429 => '请求太频繁，请稍后再试',
            _ => '请求失败(${e.response?.statusCode}): ${e.message}',
          },
      };
      throw AiException(msg);
    }
  }

  Stream<String> _nonStreamingChat(
    List<Message> history,
    String newUserMessage,
    List<String>? imagePaths,
    String? overrideModel,
    String? reasoningEffort,
    bool Function()? isCancelled,
  ) async* {
    final hasCur = imagePaths != null && imagePaths.isNotEmpty;
    final messages = <Map<String, dynamic>>[];
    for (final msg in history) {
      if (!hasCur && msg.hasImages) {
        messages.add({
          'role': msg.role,
          'content': msg.content.isEmpty ? '[图片]' : msg.content
        });
      } else {
        messages.add(msg.toOpenAIMessage());
      }
    }
    final userMsg = Message(
      conversationId: '',
      role: 'user',
      content: newUserMessage,
      imagePaths: imagePaths,
    );
    messages.add(userMsg.toOpenAIMessage());

    final model = overrideModel ?? config.modelName;
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': false,
    };
    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      body['reasoning_effort'] = reasoningEffort;
    }

    try {
      final resp = await _dio.post(
        config.chatEndpoint,
        data: body,
        options: Options(headers: config.allHeaders),
      );
      final content =
          resp.data['choices']?[0]?['message']?['content'] as String?;
      if (content != null) yield content;
    } on DioException catch (e) {
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时，请检查网络后重试',
        DioExceptionType.receiveTimeout => '响应超时，请重试',
        DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
        DioExceptionType.cancel => '请求已取消',
        _ => switch (e.response?.statusCode) {
            401 => 'API Key 无效',
            429 => '请求太频繁，请稍后再试',
            404 => '接口地址不存在 (404)，请检查 BaseURL / Endpoint 配置',
            _ => '请求失败(${e.response?.statusCode})',
          },
      };
      throw AiException(msg);
    }
  }

  Future<({String? content, List<Map<String, dynamic>>? toolCalls})>
      chatWithTools({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    String? overrideModel,
  }) async {
    final model = (overrideModel != null && overrideModel.isNotEmpty)
        ? overrideModel
        : config.modelName;
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
    };

    try {
      final resp = await _dio.post(
        config.chatEndpoint,
        data: body,
        options: Options(
          headers: config.allHeaders,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      if (resp.statusCode == 400 || resp.statusCode == 422) {
        throw AiException('该模型/接口不支持工具调用 (HTTP ${resp.statusCode})');
      }

      final choice = resp.data['choices']?[0]?['message'];
      if (choice == null) throw AiException('Empty response from API');

      final content = choice['content'] as String?;
      final toolCallsRaw = choice['tool_calls'] as List?;

      List<Map<String, dynamic>>? toolCalls;
      if (toolCallsRaw != null && toolCallsRaw.isNotEmpty) {
        toolCalls = toolCallsRaw.cast<Map<String, dynamic>>();
      }

      return (content: content, toolCalls: toolCalls);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
        throw AiException('该模型/接口不支持工具调用 (HTTP ${e.response?.statusCode})');
      }
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时',
        DioExceptionType.receiveTimeout => '响应超时',
        DioExceptionType.connectionError => '网络连接失败',
        DioExceptionType.cancel => '请求已取消',
        _ => switch (e.response?.statusCode) {
            401 => 'API Key 无效',
            429 => '请求太频繁',
            _ => '请求失败(${e.response?.statusCode}): ${e.message}',
          },
      };
      throw AiException(msg);
    }
  }

  Future<List<String>> fetchModels() async {
    try {
      final resp = await _dio.get(
        config.modelsEndpoint,
        options: Options(headers: config.allHeaders),
      );
      final data = resp.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final models = (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => m['id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();
        return models;
      }
      return [];
    } on DioException catch (e) {
      throw AiException('获取模型列表失败: ${e.message}');
    } catch (e) {
      throw AiException('获取模型列表失败: $e');
    }
  }

  Future<String> testConnection() async {
    try {
      final resp = await _dio.post(
        config.chatEndpoint,
        data: {
          'model': config.modelName,
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
          'max_tokens': 5,
          'stream': false,
        },
        options: Options(
          headers: config.allHeaders,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      if (resp.statusCode != null && resp.statusCode! < 300) {
        return '连接成功';
      }
      return '连接失败: HTTP ${resp.statusCode}';
    } on DioException catch (e) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时',
        DioExceptionType.connectionError => '无法连接到服务器',
        _ => switch (e.response?.statusCode) {
            401 => '认证失败：API Key 无效',
            403 => '访问被拒绝',
            404 => '接口不存在 (404)，请检查 URL 配置',
            429 => '请求过于频繁',
            _ => '连接失败: ${e.message}',
          },
      };
    } catch (e) {
      return '连接失败: $e';
    }
  }

  Future<String> transcribeAudio(String filePath) async {
    throw AiException('音频转录功能暂未实现');
  }
}

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}
