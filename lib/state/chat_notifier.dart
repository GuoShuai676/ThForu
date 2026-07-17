import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/message.dart';
import '../models/provider_config.dart';
import '../models/expert_panel.dart';
import '../db/message_dao.dart';
import '../db/conversation_dao.dart';
import '../db/memory_dao.dart';
import '../services/ai_service.dart';
import '../services/expert_mode_service.dart';
import '../services/deep_search_service.dart';
import '../tools/tool_registry.dart';
import '../tools/tool_executor.dart';
import '../tools/tool_definition.dart';
import '../services/skill_matcher.dart';
import '../models/skill.dart';
import 'chat_state.dart';
import '../services/token_counter.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;
  final MessageDao _messageDao;
  final ConversationDao _conversationDao;
  final MemoryDao _memoryDao;
  final ToolRegistry _toolRegistry;
  final ToolExecutor _toolExecutor;
  int _activeRunId = 0;
  DateTime _lastUiUpdate = DateTime.now();

  ChatNotifier(this.conversationId, this._messageDao, this._conversationDao,
      this._memoryDao, this._toolRegistry, this._toolExecutor)
      : super(const ChatState()) {
    loadMessages();
  }

  Future<void> loadMessages() async {
    // Never overwrite state while a send/stream is in progress —
    // the DB may contain only partial content from the last 2 s flush.
    if (_activeRunId != 0) return;
    final msgs = await _messageDao.getByConversation(conversationId);
    // Double-check after the await — a stream may have started while we
    // were waiting for the DB query.
    if (_activeRunId != 0) return;
    state = ChatState(
      messages: msgs,
      isStreaming: state.isStreaming,
      expertPhase: state.expertPhase,
      expertStatuses: state.expertStatuses,
      toolExecutions: const [],
    );
  }

  static const int _maxContextTokens = 4000;

  static List<Message> _trimHistory(List<Message> history) {
    final keep = <Message>[];
    int tokens = 0;
    if (history.isNotEmpty && history.first.role == 'system') {
      keep.add(history.first);
      tokens += TokenCounter.estimateTokens(history.first.content);
    }
    for (int i = history.length - 1; i >= 0; i--) {
      final msg = history[i];
      if (msg.role == 'system' && i == 0) continue;
      final msgTokens = TokenCounter.estimateTokens(msg.content);
      if (tokens + msgTokens > _maxContextTokens) break;
      tokens += msgTokens;
      final insertPos =
          (keep.isEmpty || (keep.length == 1 && keep.first.role == 'system'))
              ? keep.length
              : 0;
      keep.insert(insertPos, msg);
    }
    return keep;
  }

  Future<void> _autoTitle(String text) async {
    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null && conv.title == 'New Chat') {
        final title = text.trim().length > 30
            ? '${text.trim().substring(0, 30)}...'
            : text.trim();
        await _conversationDao.updateTitle(conversationId, title);
      }
    } catch (_) {}
  }

  Future<void> _updateConversationTime() async {
    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null) {
        conv.updatedAt = DateTime.now();
        await _conversationDao.update(conv);
      }
    } catch (_) {}
  }

  List<Message> _updateMessageInState(String msgId, String content) {
    return state.messages.map((m) {
      return m.id == msgId ? m.copyWith(content: content) : m;
    }).toList();
  }

  Future<void> sendMessage({
    required AIProviderConfig providerConfig,
    required String text,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
    List<String>? filePaths,
    List<String>? fileNames,
    String? replyToId,
    String? replyPreview,
    String? overrideModel,
    String? reasoningEffort,
    bool useTools = false,
    Skill? selectedSkill,
    List<Skill> allSkills = const [],
  }) async {
    final modelName = (overrideModel != null && overrideModel.isNotEmpty)
        ? overrideModel
        : providerConfig.modelName;
    final missingConfig = <String>[];
    if (providerConfig.baseUrl.trim().isEmpty) missingConfig.add('BaseURL');
    final hasCustomAuthHeader = providerConfig.customHeaders.entries.any((e) {
      final key = e.key.toLowerCase();
      return e.value.trim().isNotEmpty &&
          (key == 'authorization' || key == 'api-key' || key == 'x-api-key');
    });
    if (providerConfig.apiKey.trim().isEmpty && !hasCustomAuthHeader) {
      missingConfig.add('API Key 或自定义鉴权请求头');
    }
    if (modelName.trim().isEmpty) missingConfig.add('模型名称');
    if (missingConfig.isNotEmpty) {
      state = state.copyWith(
        errorMessage: 'API 配置不完整：请补全 ${missingConfig.join('、')}',
      );
      return;
    }

    final effectiveFilePaths =
        filePaths ?? (filePath != null ? [filePath] : null);
    final effectiveFileNames =
        fileNames ?? (fileName != null ? [fileName] : null);
    if (text.trim().isEmpty &&
        (imagePaths == null || imagePaths.isEmpty) &&
        (effectiveFilePaths == null || effectiveFilePaths.isEmpty)) {
      return;
    }

    _activeRunId++;
    final myRunId = _activeRunId;

    if (state.isStreaming) {
      final msgs = state.messages.toList();
      state = ChatState(messages: msgs, isStreaming: false);
    }

    WakelockPlus.enable();
    await _autoTitle(text);

    final userMsg = Message(
      conversationId: conversationId,
      role: 'user',
      content: text,
      imagePaths: imagePaths?.isNotEmpty == true ? imagePaths : null,
      filePaths: effectiveFilePaths,
      fileNames: effectiveFileNames,
      filePath: effectiveFilePaths != null && effectiveFilePaths.length == 1
          ? effectiveFilePaths.first
          : null,
      fileName: effectiveFileNames != null && effectiveFileNames.length == 1
          ? effectiveFileNames.first
          : null,
      metadata: replyToId != null
          ? {
              'replyToId': replyToId,
              'replyPreview': replyPreview,
            }
          : null,
    );
    await _messageDao.insert(userMsg);

    final assistantMsg = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
    );
    await _messageDao.insert(assistantMsg);

    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }
    state = ChatState(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
    );

    final history = _trimHistory(state.messages
        .where((m) => m.id != assistantMsg.id && m.id != userMsg.id)
        .toList());

    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv?.personaId != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('personas');
        if (raw != null) {
          final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          final personaMap = list.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p!['id'] == conv!.personaId,
              orElse: () => null);
          if (personaMap != null) {
            history.insert(
                0,
                Message(
                  conversationId: conversationId,
                  role: 'system',
                  content: personaMap['system_prompt'] as String,
                ));
          }
        }
      }
    } catch (_) {}

    try {
      final relevantMemories = await _memoryDao.getRelevant(text, limit: 5);
      if (relevantMemories.isNotEmpty) {
        final memBuf = StringBuffer('以下是你对用户的记忆，请在回答时参考：\n');
        for (final m in relevantMemories) {
          memBuf.writeln('- ${m.key}: ${m.value}');
        }
        history.insert(
            0,
            Message(
              conversationId: conversationId,
              role: 'system',
              content: memBuf.toString(),
            ));
      }
    } catch (_) {}

    if (replyToId != null && replyPreview != null && replyPreview.isNotEmpty) {
      history.insert(
          0,
          Message(
            conversationId: conversationId,
            role: 'system',
            content: '用户正在追问以下内容：「$replyPreview」。请结合上下文回答。',
          ));
    }
    final matchedSkill =
        SkillMatcher.match(text, allSkills, manualSelection: selectedSkill);
    if (matchedSkill != null && matchedSkill.systemPrompt.isNotEmpty) {
      history.insert(
          0,
          Message(
            conversationId: conversationId,
            role: 'system',
            content: matchedSkill.systemPrompt,
          ));
    }

    final aiService = AiService(providerConfig);
    final effectiveModel = modelName;

    bool toolsExecuted = false;
    String? toolFinalContent;
    List<Message> streamHistory = history;

    final allowedToolNames =
        SkillMatcher.effectiveTools(_toolRegistry.enabledToolNames, matchedSkill);
    final openAiTools = _toolRegistry.openAiToolsFor(allowedToolNames);

    if (useTools && openAiTools.isNotEmpty) {
      final openAiMessages = <Map<String, dynamic>>[];
      for (final msg in history) {
        if (msg.role == 'system' ||
            msg.role == 'user' ||
            msg.role == 'assistant') {
          openAiMessages.add(msg.toOpenAIMessage());
        }
      }
      openAiMessages.add(Message(
              conversationId: '',
              role: 'user',
              content: text,
              imagePaths: imagePaths)
          .toOpenAIMessage());

      for (int round = 0; round < 5; round++) {
        if (_activeRunId != myRunId) {
          WakelockPlus.disable();
          return;
        }

        try {
          final toolResult = await aiService.chatWithTools(
            messages: openAiMessages,
            tools: openAiTools,
            overrideModel: effectiveModel,
          );

          if (toolResult.toolCalls == null || toolResult.toolCalls!.isEmpty) {
            if (toolResult.content != null && toolResult.content!.isNotEmpty) {
              toolFinalContent = toolResult.content;
              openAiMessages
                  .add({'role': 'assistant', 'content': toolResult.content});
            }
            break;
          }

          toolsExecuted = true;
          openAiMessages.add({
            'role': 'assistant',
            'content':
                toolResult.content?.isEmpty == true ? null : toolResult.content,
            'tool_calls': toolResult.toolCalls,
          });

          for (final tc in toolResult.toolCalls!) {
            if (_activeRunId != myRunId) {
              WakelockPlus.disable();
              return;
            }
            final tcId = tc['id'] as String;
            final funcName = tc['function']?['name'] as String? ?? 'unknown';
            Map<String, dynamic> args = {};
            try {
              args = jsonDecode(tc['function']?['arguments'] as String? ?? '{}')
                  as Map<String, dynamic>;
            } catch (_) {}

            String summary = funcName;
            if (funcName == 'terminal')
              summary = args['command'] as String? ?? funcName;
            else if (funcName == 'web_search')
              summary = args['query'] as String? ?? funcName;
            else if (funcName == 'memory')
              summary =
                  '${args['action']}: ${args['key'] ?? args['query'] ?? ''}';

            state = state.copyWith(
              toolExecutions: [
                ...state.toolExecutions,
                ToolExecInfo(id: tcId, name: funcName, summary: summary)
              ],
              isStreaming: true,
            );

            ToolResult result;
            try {
              result = await _toolExecutor
                  .execute(ToolCall(id: tcId, name: funcName, arguments: args));
            } catch (e) {
              result = ToolResult(
                  toolCallId: tcId,
                  name: funcName,
                  output: 'Tool execution error: $e',
                  isError: true);
            }

            final updatedExecs = List<ToolExecInfo>.from(state.toolExecutions);
            final idx = updatedExecs.indexWhere((e) => e.id == tcId);
            if (idx >= 0) {
              updatedExecs[idx] = updatedExecs[idx].copyWith(
                status: result.isError
                    ? ToolExecStatus.failed
                    : ToolExecStatus.completed,
                output: result.output.length > 500
                    ? '${result.output.substring(0, 500)}...'
                    : result.output,
              );
            }
            state = state.copyWith(toolExecutions: updatedExecs);

            openAiMessages.add({
              'role': 'tool',
              'tool_call_id': tcId,
              'name': funcName,
              'content': result.output,
            });

            streamHistory.add(Message(
              conversationId: conversationId,
              role: 'tool',
              content: result.output,
              toolCallId: tcId,
            ));
          }
        } on AiException catch (e) {
          if (_activeRunId != myRunId) {
            WakelockPlus.disable();
            return;
          }
          if (toolsExecuted) {
            toolFinalContent = '工具已执行，但生成最终回答失败：${e.message}';
          }
          state = state.copyWith(
            toolExecutions: [
              ...state.toolExecutions,
              ToolExecInfo(
                id: 'error_$round',
                name: 'system',
                summary: '工具调用失败',
                status: ToolExecStatus.failed,
                output: e.message,
              )
            ],
          );
          break;
        } catch (e) {
          if (toolsExecuted) {
            toolFinalContent = '工具已执行，但生成最终回答失败：$e';
          }
          break;
        }
      }
    }

    try {
      if (toolsExecuted) {
        final content = toolFinalContent?.trim().isNotEmpty == true
            ? toolFinalContent!.trim()
            : '工具已执行，但模型没有返回最终回答。请查看上方工具结果。';
        await _messageDao.updateContent(conversationId, assistantMsg.id, content);
        state = state.copyWith(
          messages: _updateMessageInState(assistantMsg.id, content),
          isStreaming: false,
        );
        await _updateConversationTime();
        WakelockPlus.disable();
        if (_activeRunId == myRunId) {
          state = state.copyWith(toolExecutions: const []);
        }
        return;
      }

      final fullBuf = StringBuffer();
      DateTime lastDbWrite = DateTime.now();
      await for (final chunk in aiService.streamChat(
        history: streamHistory,
        newUserMessage: toolsExecuted ? '' : text,
        imagePaths: imagePaths,
        overrideModel: effectiveModel,
        reasoningEffort: reasoningEffort,
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) {
          await _messageDao.updateContent(
              conversationId, assistantMsg.id, fullBuf.toString());
          WakelockPlus.disable();
          return;
        }
        fullBuf.write(chunk);

        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(
              conversationId, assistantMsg.id, fullBuf.toString());
        }

        if (now.difference(_lastUiUpdate).inMilliseconds > 80) {
          _lastUiUpdate = now;
          final content = fullBuf.toString();
          if (_activeRunId != myRunId) return;
          state = state.copyWith(
            messages: _updateMessageInState(assistantMsg.id, content),
            isStreaming: true,
          );
        }
      }

      if (_activeRunId != myRunId) return;
      final content = fullBuf.toString();
      state = state.copyWith(
        messages: _updateMessageInState(assistantMsg.id, content),
        isStreaming: false,
      );
    } on AiException catch (e) {
      if (_activeRunId != myRunId) {
        WakelockPlus.disable();
        return;
      }
      await _messageDao.updateContent(
          conversationId, assistantMsg.id, '错误：${e.message}');
      state = state.copyWith(
        messages: _updateMessageInState(assistantMsg.id, '错误：${e.message}'),
        isStreaming: false,
        errorMessage: e.message,
        toolExecutions: const [],
      );
    } catch (e) {
      if (_activeRunId != myRunId) {
        WakelockPlus.disable();
        return;
      }
      await _messageDao.updateContent(
          conversationId, assistantMsg.id, '未知错误：$e');
      state = state.copyWith(
        messages: _updateMessageInState(assistantMsg.id, '未知错误：$e'),
        isStreaming: false,
        errorMessage: e.toString(),
        toolExecutions: const [],
      );
    }

    await _updateConversationTime();
    WakelockPlus.disable();
    if (_activeRunId == myRunId) {
      state = state.copyWith(toolExecutions: const []);
    }
  }

  Future<void> sendDeepSearchMessage({
    required AIProviderConfig providerConfig,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    _activeRunId++;
    final myRunId = _activeRunId;

    if (state.isStreaming) {
      final msgs = state.messages.toList();
      state = ChatState(messages: msgs, isStreaming: false);
    }

    WakelockPlus.enable();

    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null && conv.title == 'New Chat') {
        final title =
            '深度搜索: ${text.trim().length > 25 ? '${text.trim().substring(0, 25)}...' : text.trim()}';
        await _conversationDao.updateTitle(conversationId, title);
      }
    } catch (_) {}

    final userMsg = Message(
      conversationId: conversationId,
      role: 'user',
      content: '[深度搜索] $text',
    );
    await _messageDao.insert(userMsg);

    final assistantMsg = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      metadata: {'type': 'deep_search', 'query': text},
    );
    await _messageDao.insert(assistantMsg);

    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }
    state = ChatState(
        messages: [...state.messages, userMsg, assistantMsg],
        isStreaming: true);

    final fullBuf = StringBuffer();
    DateTime lastDbWrite = DateTime.now();

    try {
      await for (final result in DeepSearchService.search(
        query: text,
        config: providerConfig,
        onProgress: (progress) {},
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) break;
        fullBuf.clear();
        fullBuf.write(result.detailedReport);
        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(
              conversationId, assistantMsg.id, fullBuf.toString());
        }
        if (now.difference(_lastUiUpdate).inMilliseconds > 80) {
          _lastUiUpdate = now;
          final content = fullBuf.toString();
          state = state.copyWith(
            messages: _updateMessageInState(assistantMsg.id, content),
            isStreaming: true,
          );
        }
      }

      if (_activeRunId != myRunId) return;
      await _messageDao.updateContent(
          conversationId, assistantMsg.id, fullBuf.toString());
      final content = fullBuf.toString();
      state = state.copyWith(
        messages: _updateMessageInState(assistantMsg.id, content),
        isStreaming: false,
      );
    } catch (e) {
      final errContent = '深度搜索失败: $e';
      await _messageDao.updateContent(
          conversationId, assistantMsg.id, errContent);
      state = state.copyWith(
        messages: _updateMessageInState(assistantMsg.id, errContent),
        isStreaming: false,
      );
    }

    WakelockPlus.disable();
  }

  Future<void> sendExpertMessage({
    required ExpertPanel panel,
    required List<AIProviderConfig> expertConfigs,
    required AIProviderConfig gatewayConfig,
    required String text,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
  }) async {
    if (text.trim().isEmpty &&
        (imagePaths == null || imagePaths.isEmpty) &&
        filePath == null) {
      return;
    }

    _activeRunId++;
    final myRunId = _activeRunId;

    if (state.isStreaming) {
      state = ChatState(
        messages: state.messages,
        isStreaming: false,
        expertPhase: ExpertPhase.none,
      );
    }

    WakelockPlus.enable();
    await _autoTitle(text);

    final userMsg = Message(
      conversationId: conversationId,
      role: 'user',
      content: text,
      imagePaths: imagePaths?.isNotEmpty == true ? imagePaths : null,
      filePath: filePath,
      fileName: fileName,
    );
    await _messageDao.insert(userMsg);
    var allMessages = [...state.messages, userMsg];

    final expertPlaceholders = <String, Message>{};
    for (final config in expertConfigs) {
      final placeholder = Message(
        conversationId: conversationId,
        role: 'assistant',
        content: '',
        metadata: {
          'type': 'expert_response',
          'providerId': config.id,
          'providerName': config.name,
        },
      );
      await _messageDao.insert(placeholder);
      expertPlaceholders[config.id] = placeholder;
      allMessages.add(placeholder);
    }

    final statuses = <String, ExpertStatus>{};
    for (final config in expertConfigs) {
      statuses[config.id] = ExpertStatus(
        providerId: config.id,
        providerName: config.name,
      );
    }

    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.querying,
      expertStatuses: statuses,
    );

    final history = _trimHistory(state.messages
        .where(
            (m) => m.id != userMsg.id && !expertPlaceholders.containsKey(m.id))
        .toList());

    final expertResults = await ExpertModeService.queryAllExperts(
      expertConfigs: expertConfigs,
      history: history,
      userQuestion: text,
      imagePaths: imagePaths,
      onStatusChanged: (providerId, status) {
        if (_activeRunId != myRunId) return;
        final updated = Map<String, ExpertStatus>.from(state.expertStatuses);
        updated[providerId] = status;
        state = state.copyWith(expertStatuses: updated);
      },
      isCancelled: () => _activeRunId != myRunId,
    );

    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }

    allMessages = state.messages.toList();
    for (final entry in expertResults.entries) {
      final placeholder = expertPlaceholders[entry.key];
      if (placeholder == null) continue;
      final idx = allMessages.indexWhere((m) => m.id == placeholder.id);
      if (idx >= 0) {
        allMessages[idx] = placeholder.copyWith(content: entry.value);
        await _messageDao.updateContent(
            conversationId, placeholder.id, entry.value);
      }
    }

    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.synthesizing,
      expertStatuses: state.expertStatuses,
    );

    final hasSuccess = expertResults.values
        .any((v) => !v.startsWith('错误:') && !v.startsWith('未知错误:'));
    if (!hasSuccess) {
      if (_activeRunId != myRunId) {
        WakelockPlus.disable();
        return;
      }
      state = ChatState(
        messages: allMessages,
        isStreaming: false,
        expertPhase: ExpertPhase.none,
        errorMessage: '所有兼听请求失败，请检查 API 配置',
      );
      WakelockPlus.disable();
      return;
    }

    final configMap = <String, AIProviderConfig>{};
    for (final c in expertConfigs) {
      configMap[c.id] = c;
    }

    final synthesisPrompt = ExpertModeService.buildSynthesisPrompt(
      userQuestion: text,
      expertResponses: expertResults,
      configMap: configMap,
      customPrompt:
          panel.synthesisPrompt.isNotEmpty ? panel.synthesisPrompt : null,
    );

    final gatewayPlaceholder = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      metadata: {'type': 'gateway_synthesis'},
    );
    await _messageDao.insert(gatewayPlaceholder);
    allMessages = [...state.messages, gatewayPlaceholder];
    if (_activeRunId != myRunId) {
      WakelockPlus.disable();
      return;
    }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.synthesizing,
      expertStatuses: state.expertStatuses,
    );

    final gatewayHistory = _trimHistory(state.messages
        .where((m) =>
            m.id != gatewayPlaceholder.id &&
            (m.metadata == null || m.metadata!['type'] != 'expert_response'))
        .toList());

    final systemMsg = Message(
      conversationId: conversationId,
      role: 'system',
      content: panel.synthesisPrompt.isNotEmpty
          ? panel.synthesisPrompt
          : '你是一位兼听则明的总结助手。以下是多位 AI 对同一个问题的回答。请仔细分析所有回答，找出共同点和分歧，纠正明显错误，然后给出一个全面、准确、综合的最终答案。',
    );
    gatewayHistory.insert(0, systemMsg);

    final gatewayService = AiService(gatewayConfig);

    try {
      final fullBuf = StringBuffer();
      DateTime lastDbWrite = DateTime.now();
      await for (final chunk in gatewayService.streamChat(
        history: gatewayHistory,
        newUserMessage: synthesisPrompt,
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) {
          await _messageDao.updateContent(
              conversationId, gatewayPlaceholder.id, fullBuf.toString());
          WakelockPlus.disable();
          return;
        }
        fullBuf.write(chunk);

        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(
              conversationId, gatewayPlaceholder.id, fullBuf.toString());
        }

        if (now.difference(_lastUiUpdate).inMilliseconds > 80) {
          _lastUiUpdate = now;
          try {
            final content = fullBuf.toString();
            if (_activeRunId != myRunId) return;
            state = ChatState(
              messages: _updateMessageInState(gatewayPlaceholder.id, content),
              isStreaming: true,
              expertPhase: ExpertPhase.synthesizing,
              expertStatuses: state.expertStatuses,
            );
          } catch (_) {}
        }
      }

      if (_activeRunId != myRunId) return;
      try {
        final content = fullBuf.toString();
        state = ChatState(
          messages: _updateMessageInState(gatewayPlaceholder.id, content),
          isStreaming: false,
          expertPhase: ExpertPhase.none,
        );
      } catch (_) {}
    } on AiException catch (e) {
      if (_activeRunId != myRunId) {
        WakelockPlus.disable();
        return;
      }
      await _messageDao.updateContent(
          conversationId, gatewayPlaceholder.id, '综合失败: ${e.message}');
      try {
        state = ChatState(
          messages: _updateMessageInState(
              gatewayPlaceholder.id, '综合失败: ${e.message}'),
          isStreaming: false,
          expertPhase: ExpertPhase.none,
          errorMessage: '网关综合失败: ${e.message}',
        );
      } catch (_) {}
    } catch (e) {
      if (_activeRunId != myRunId) {
        WakelockPlus.disable();
        return;
      }
      await _messageDao.updateContent(
          conversationId, gatewayPlaceholder.id, '综合失败: $e');
      try {
        state = ChatState(
          messages: _updateMessageInState(gatewayPlaceholder.id, '综合失败: $e'),
          isStreaming: false,
          expertPhase: ExpertPhase.none,
          errorMessage: '网关综合失败: $e',
        );
      } catch (_) {}
    }

    await _updateConversationTime();
    WakelockPlus.disable();
  }

  Future<String> addImageMessage(List<String> imagePaths) async {
    final msg = Message(
      conversationId: conversationId,
      role: 'user',
      content: '',
      imagePaths: imagePaths,
    );
    await _messageDao.insert(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
    return msg.id;
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> deleteMessage(String messageId) async {
    await _messageDao.deleteById(conversationId, messageId);
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> toggleFavorite(String messageId) async {
    await _messageDao.toggleFavorite(conversationId, messageId);
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isFavorite: !m.isFavorite);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> regenerateLastResponse({
    required AIProviderConfig providerConfig,
    String? overrideModel,
    String? reasoningEffort,
  }) async {
    final msgs = state.messages;
    if (msgs.isEmpty || state.isStreaming) return;

    String? lastUserText;
    List<String>? lastUserImages;
    int lastUserIdx = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].role == 'user') {
        lastUserText = msgs[i].content;
        lastUserImages = msgs[i].imagePaths;
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserText == null && lastUserImages == null) return;

    final toDelete = msgs.sublist(lastUserIdx + 1);
    for (final m in toDelete) {
      await _messageDao.deleteById(conversationId, m.id);
    }
    state = state.copyWith(messages: msgs.sublist(0, lastUserIdx + 1));

    await sendMessage(
      providerConfig: providerConfig,
      text: lastUserText ?? '',
      imagePaths: lastUserImages,
      overrideModel: overrideModel,
      reasoningEffort: reasoningEffort,
    );
  }

  Future<void> editAndResend({
    required AIProviderConfig providerConfig,
    required String messageId,
    required String newText,
    String? overrideModel,
    String? reasoningEffort,
  }) async {
    if (state.isStreaming) return;
    final msgs = state.messages;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    final toDelete = msgs.sublist(idx);
    for (final m in toDelete) {
      await _messageDao.deleteById(conversationId, m.id);
    }
    state = state.copyWith(messages: msgs.sublist(0, idx));

    await sendMessage(
      providerConfig: providerConfig,
      text: newText,
      overrideModel: overrideModel,
      reasoningEffort: reasoningEffort,
    );
  }
}
