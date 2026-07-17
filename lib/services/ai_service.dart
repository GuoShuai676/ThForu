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

  bool _supportsReasoningEffort(String model) {
    final lower = model.toLowerCase();
    return lower.contains('reasoner') ||
        RegExp(r'^o[134](?:-|$)').hasMatch(lower) ||
        lower.startsWith('gpt-5');
  }

  void _addReasoningEffort(
    Map<String, dynamic> body,
    String model,
    String? reasoningEffort,
  ) {
    if (reasoningEffort != null &&
        reasoningEffort.isNotEmpty &&
        _supportsReasoningEffort(model)) {
      body['reasoning_effort'] = reasoningEffort;
    }
  }

  String _extractErrorBody(dynamic data) {
    try {
      if (data == null) return '';
      if (data is ResponseBody) return '';
      if (data is Map) {
        final err = data['error'];
        if (err is Map && err['message'] != null) {
          return err['message'].toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
      final text = data.toString();
      return text.length > 600 ? '${text.substring(0, 600)}...' : text;
    } catch (_) {
      return '';
    }
  }

  String _formatHttpError(int? statusCode, dynamic data, String fallback) {
    final detail = _extractErrorBody(data);
    final suffix = detail.isNotEmpty ? ': $detail' : '';
    return switch (statusCode) {
      400 => '请求参数错误，请检查模型、附件、推理参数或工具能力$suffix',
      401 => '认证失败：API Key 无效或 Authorization 请求头不正确$suffix',
      403 => '访问被拒绝，请检查 API 权限$suffix',
      404 => '接口地址不存在，请检查 BaseURL / Endpoint 配置$suffix',
      422 => '请求格式不被该接口支持$suffix',
      429 => '请求太频繁，请稍后再试$suffix',
      _ => '$fallback${statusCode != null ? "(HTTP $statusCode)" : ""}$suffix',
    };
  }
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

    _addReasoningEffort(body, model, reasoningEffort);

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
        final errorText = await response.data.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .join();
        throw AiException(
          _formatHttpError(response.statusCode, errorText, '请求失败'),
        );
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
        DioExceptionType.receiveTimeout => '响应超时，请重试',
        DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
        DioExceptionType.cancel => '请求已取消',
        _ => _formatHttpError(e.response?.statusCode, e.response?.data, '请求失败'),
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
    _addReasoningEffort(body, model, reasoningEffort);

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
        _ => _formatHttpError(e.response?.statusCode, e.response?.data, '请求失败'),
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
        throw AiException(_formatHttpError(
          e.response?.statusCode,
          e.response?.data,
          '该模型或接口不支持工具调用',
        ));
      }
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时',
        DioExceptionType.receiveTimeout => '响应超时',
        DioExceptionType.connectionError => '网络连接失败',
        DioExceptionType.cancel => '请求已取消',
        _ => _formatHttpError(e.response?.statusCode, e.response?.data, '请求失败'),
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
        return (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => m['id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw AiException(
        _formatHttpError(e.response?.statusCode, e.response?.data, '获取模型列表失败'),
      );
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
      return _formatHttpError(resp.statusCode, resp.data, '连接失败');
    } on DioException catch (e) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时',
        DioExceptionType.connectionError => '无法连接到服务器',
        DioExceptionType.receiveTimeout => '响应超时',
        DioExceptionType.cancel => '请求已取消',
        _ => _formatHttpError(e.response?.statusCode, e.response?.data, '连接失败'),
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
