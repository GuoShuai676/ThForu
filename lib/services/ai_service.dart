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
    bool Function()? isCancelled,
  }) async* {
    final messages = <Map<String, dynamic>>[];

    // Strip images from history if current request has no images —
    // some models reject ANY image content in the conversation.
    final hasCurrentImages = imagePaths != null && imagePaths.isNotEmpty;
    for (final msg in history) {
      if (!hasCurrentImages && msg.hasImages) {
        // Send text-only version of this history message
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

    final body = {
      'model': config.modelName,
      'messages': messages,
      'stream': true,
    };

    try {
      final response = await _dio.post(
        config.chatEndpoint,
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
          validateStatus: (s) => s! < 500,
        ),
      );

      if (response.statusCode == 404) {
        final bytes = <int>[];
        await for (final chunk in response.data.stream) {
          bytes.addAll(chunk);
        }
        throw AiException('404: ${utf8.decode(bytes)}');
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
        // Retry without stream — some providers don't support SSE
        yield* _nonStreamingChat(history, newUserMessage, imagePaths, isCancelled);
        return;
      }
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout => '连接超时，请检查网络后重试',
        DioExceptionType.receiveTimeout => '响应超时（120s），请重试',
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
    bool Function()? isCancelled,
  ) async* {
    final hasCur = imagePaths != null && imagePaths.isNotEmpty;
    final messages = <Map<String, dynamic>>[];
    for (final msg in history) {
      if (!hasCur && msg.hasImages) {
        messages.add({'role': msg.role, 'content': msg.content.isEmpty ? '[图片]' : msg.content});
      } else {
        messages.add(msg.toOpenAIMessage());
      }
    }
    final userMsg = Message(
      conversationId: '', role: 'user',
      content: newUserMessage, imagePaths: imagePaths,
    );
    messages.add(userMsg.toOpenAIMessage());

    final resp = await _dio.post(
      config.chatEndpoint,
      data: {'model': config.modelName, 'messages': messages, 'stream': false},
      options: Options(headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      }),
    );
    final content = resp.data['choices']?[0]?['message']?['content'] as String?;
    if (content != null) yield content;
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
