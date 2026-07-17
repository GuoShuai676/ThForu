import '../models/provider_config.dart';
import '../models/message.dart';
import '../state/chat_state.dart';
import 'ai_service.dart';

class ExpertModeService {
  static Future<Map<String, String>> queryAllExperts({
    required List<AIProviderConfig> expertConfigs,
    required List<Message> history,
    required String userQuestion,
    List<String>? imagePaths,
    required void Function(String providerId, ExpertStatus status)
        onStatusChanged,
    required bool Function() isCancelled,
  }) async {
    final results = <String, String>{};

    final futures = expertConfigs.map((config) async {
      onStatusChanged(
        config.id,
        ExpertStatus(
          providerId: config.id,
          providerName: config.name,
          state: ExpertStatusState.streaming,
        ),
      );

      final service = AiService(config);
      final buf = StringBuffer();
      try {
        await for (final chunk in service.streamChat(
          history: history,
          newUserMessage: userQuestion,
          imagePaths: imagePaths,
          isCancelled: isCancelled,
        )) {
          if (isCancelled()) return;
          buf.write(chunk);
        }
        results[config.id] = buf.toString();
        onStatusChanged(
          config.id,
          ExpertStatus(
            providerId: config.id,
            providerName: config.name,
            state: ExpertStatusState.completed,
          ),
        );
      } on AiException catch (e) {
        results[config.id] = '错误: ${e.message}';
        onStatusChanged(
          config.id,
          ExpertStatus(
            providerId: config.id,
            providerName: config.name,
            state: ExpertStatusState.failed,
            errorMessage: e.message,
          ),
        );
      } catch (e) {
        results[config.id] = '未知错误: $e';
        onStatusChanged(
          config.id,
          ExpertStatus(
            providerId: config.id,
            providerName: config.name,
            state: ExpertStatusState.failed,
            errorMessage: e.toString(),
          ),
        );
      }
    }).toList();

    await Future.wait(futures.map((f) => f.timeout(
      const Duration(seconds: 120),
      onTimeout: () {},
    )));
    return results;
  }

  static String buildSynthesisPrompt({
    required String userQuestion,
    required Map<String, String> expertResponses,
    required Map<String, AIProviderConfig> configMap,
    String? customPrompt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('用户问题：');
    buffer.writeln(userQuestion);
    buffer.writeln();
    buffer.writeln('各方回答：');
    for (final entry in expertResponses.entries) {
      final config = configMap[entry.key];
      final name = config?.name ?? entry.key;
      final model = config?.modelName ?? 'unknown';
      buffer.writeln('---');
      buffer.writeln('$name（$model）：');
      buffer.writeln(entry.value);
      buffer.writeln('---');
      buffer.writeln();
    }
    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln(customPrompt);
    } else {
      buffer.writeln('请提供你的综合分析：');
    }
    return buffer.toString();
  }
}
