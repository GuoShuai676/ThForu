import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/message.dart';
import '../models/provider_config.dart';
import '../models/expert_panel.dart';
import '../db/message_dao.dart';
import '../db/conversation_dao.dart';
import '../services/ai_service.dart';
import '../services/expert_mode_service.dart';
import '../services/deep_search_service.dart';
import 'chat_state.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final String conversationId;
  final MessageDao _messageDao;
  final ConversationDao _conversationDao;
  int _activeRunId = 0;
  DateTime _lastUiUpdate = DateTime.now();

  ChatNotifier(this.conversationId, this._messageDao, this._conversationDao)
      : super(const ChatState()) {
    loadMessages();
  }

  Future<void> loadMessages() async {
    final msgs = await _messageDao.getByConversation(conversationId);
    state = ChatState(
      messages: msgs,
      isStreaming: state.isStreaming,
      expertPhase: state.expertPhase,
      expertStatuses: state.expertStatuses,
    );
  }

  // ---------------------------------------------------------------------------
  // Normal (single-model) chat
  // ---------------------------------------------------------------------------
  // Max past messages carried as context (≈6 exchanges).
  // Follow-ups keep just the recent thread, not the full history.
  static const int _maxContextMessages = 12;

  static List<Message> _trimHistory(List<Message> history) {
    if (history.length <= _maxContextMessages) return history;
    final keep = <Message>[];
    if (history.first.role == 'system') keep.add(history.first);
    final start = history.length - _maxContextMessages;
    keep.addAll(history.skip(start));
    return keep;
  }

  Future<void> sendMessage({
    required AIProviderConfig providerConfig,
    required String text,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
    String? replyToId,
    String? replyPreview,
  }) async {
    if (text.trim().isEmpty && (imagePaths == null || imagePaths.isEmpty) && filePath == null) {
      return;
    }

    // Cancel the previous stream.  The partial response is KEPT in the
    // conversation so the new request can synthesise everything together.
    _activeRunId++;
    final myRunId = _activeRunId;

    // If there was a running assistant message, persist whatever it
    // received so far and leave it in the message list.
    if (state.isStreaming) {
      final msgs = state.messages.toList();
      // The last message is the streaming assistant; its partial content
      // was already saved to DB chunk-by-chunk, so we just mark the
      // phase as over.
      state = ChatState(messages: msgs, isStreaming: false);
    }

    WakelockPlus.enable();

    // Auto-title
    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null && conv.title == 'New Chat') {
        final title = text.trim().length > 30
            ? '${text.trim().substring(0, 30)}...'
            : text.trim();
        await _conversationDao.updateTitle(conversationId, title);
      }
    } catch (_) {}

    // Insert user message
    final userMsg = Message(
      conversationId: conversationId,
      role: 'user',
      content: text,
      imagePaths: imagePaths?.isNotEmpty == true ? imagePaths : null,
      filePath: filePath,
      fileName: fileName,
      metadata: replyToId != null ? {
        'replyToId': replyToId,
        'replyPreview': replyPreview,
      } : null,
    );
    await _messageDao.insert(userMsg);

    // Insert empty assistant placeholder
    final assistantMsg = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
    );
    await _messageDao.insert(assistantMsg);

    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
    state = ChatState(
      messages: [...state.messages, userMsg, assistantMsg],
      isStreaming: true,
    );

    // Build history — keep only the most recent messages as context.
    final history = _trimHistory(
        state.messages.where((m) => m.id != assistantMsg.id).toList());

    // Inject persona system prompt
    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv?.personaId != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('personas');
        if (raw != null) {
          final list = (jsonDecode(raw) as List)
              .cast<Map<String, dynamic>>();
          final personaMap = list.cast<Map<String, dynamic>?>()
              .firstWhere((p) => p!['id'] == conv!.personaId,
                  orElse: () => null);
          if (personaMap != null) {
            history.insert(0, Message(
              conversationId: conversationId,
              role: 'system',
              content: personaMap['system_prompt'] as String,
            ));
          }
        }
      }
    } catch (_) {}
    if (replyToId != null && replyPreview != null && replyPreview!.isNotEmpty) {
      history.insert(0, Message(
        conversationId: conversationId,
        role: 'system',
        content: '用户正在追问以下内容：「$replyPreview」。请结合上下文回答。',
      ));
    }

    final aiService = AiService(providerConfig);

    try {
      String fullContent = '';
      DateTime lastDbWrite = DateTime.now();
      await for (final chunk in aiService.streamChat(
        history: history,
        newUserMessage: text,
        imagePaths: imagePaths,
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) {
          await _messageDao.updateContent(assistantMsg.id, fullContent);
          WakelockPlus.disable();
          return;
        }
        // Strip invalid UTF-16 surrogates
        final clean = StringBuffer();
        for (var i = 0; i < chunk.length; i++) {
          final c = chunk.codeUnitAt(i);
          if (c < 0xD800 || c > 0xDFFF) clean.writeCharCode(c);
        }
        fullContent += clean.toString();

        // DB write: max every 2 seconds (not every chunk)
        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(assistantMsg.id, fullContent);
        }

        // UI update: max every 200ms for smooth streaming
        if (now.difference(_lastUiUpdate).inMilliseconds > 200) {
          _lastUiUpdate = now;
          try {
            final updated = state.messages.map((m) {
              return m.id == assistantMsg.id ? m.copyWith(content: fullContent) : m;
            }).toList();
            if (_activeRunId != myRunId) return;
            state = ChatState(messages: updated, isStreaming: true);
          } catch (_) {}
        }
      }

      if (_activeRunId != myRunId) return;
      try {
        final finalMessages = state.messages.map((m) {
          return m.id == assistantMsg.id ? m.copyWith(content: fullContent) : m;
        }).toList();
        state = ChatState(messages: finalMessages, isStreaming: false);
      } catch (_) {}
    } on AiException catch (e) {
      if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
      await _messageDao.updateContent(assistantMsg.id, '错误: ${e.message}');
      try {
        final updated = state.messages.map((m) {
          return m.id == assistantMsg.id
              ? m.copyWith(content: '错误: ${e.message}')
              : m;
        }).toList();
        state = ChatState(
          messages: updated,
          isStreaming: false,
          errorMessage: e.message,
        );
      } catch (_) {}
    } catch (e) {
      if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
      await _messageDao.updateContent(assistantMsg.id, '未知错误: $e');
      try {
        final updated = state.messages.map((m) {
          return m.id == assistantMsg.id ? m.copyWith(content: '未知错误: $e') : m;
        }).toList();
        state = ChatState(
          messages: updated,
          isStreaming: false,
          errorMessage: e.toString(),
        );
      } catch (_) {}
    }

    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null) {
        conv.updatedAt = DateTime.now();
        await _conversationDao.update(conv);
      }
    } catch (_) {}

    WakelockPlus.disable();
  }

  // ---------------------------------------------------------------------------
  // Deep search mode
  // ---------------------------------------------------------------------------

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
        final title = '深度搜索: ${text.trim().length > 25 ? '${text.trim().substring(0, 25)}...' : text.trim()}';
        await _conversationDao.updateTitle(conversationId, title);
      }
    } catch (_) {}

    final userMsg = Message(
      conversationId: conversationId,
      role: 'user',
      content: '🔍 $text',
    );
    await _messageDao.insert(userMsg);

    final assistantMsg = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      metadata: {'type': 'deep_search', 'query': text},
    );
    await _messageDao.insert(assistantMsg);

    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
    state = ChatState(messages: [...state.messages, userMsg, assistantMsg], isStreaming: true);

    String fullContent = '';
    DateTime lastDbWrite = DateTime.now();
    int phaseIndex = 0;
    const phases = ['🔍 正在拆解问题...', '🌐 正在搜索...', '📄 正在读取网页...', '🤖 AI 正在分析...'];

    try {
      await for (final result in DeepSearchService.search(
        query: text,
        config: providerConfig,
        onProgress: (progress) {
          final phaseIdx = DeepSearchPhase.values.indexOf(progress.phase);
          if (phaseIdx >= 0 && phaseIdx < phases.length && phaseIdx != phaseIndex) {
            phaseIndex = phaseIdx;
          }
        },
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) break;
        fullContent = result.detailedReport;
        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(assistantMsg.id, fullContent);
        }
        if (now.difference(_lastUiUpdate).inMilliseconds > 200) {
          _lastUiUpdate = now;
          try {
            final updated = state.messages.map((m) {
              return m.id == assistantMsg.id ? m.copyWith(content: fullContent) : m;
            }).toList();
            state = ChatState(messages: updated, isStreaming: true);
          } catch (_) {}
        }
      }

      if (_activeRunId != myRunId) return;
      await _messageDao.updateContent(assistantMsg.id, fullContent);
      try {
        final updated = state.messages.map((m) {
          return m.id == assistantMsg.id ? m.copyWith(content: fullContent) : m;
        }).toList();
        state = ChatState(messages: updated, isStreaming: false);
      } catch (_) {}
    } catch (e) {
      fullContent = '深度搜索失败: $e';
      await _messageDao.updateContent(assistantMsg.id, fullContent);
      try {
        final updated = state.messages.map((m) {
          return m.id == assistantMsg.id ? m.copyWith(content: fullContent) : m;
        }).toList();
        state = ChatState(messages: updated, isStreaming: false);
      } catch (_) {}
    }

    WakelockPlus.disable();
  }

  // ---------------------------------------------------------------------------
  // Expert mode
  // ---------------------------------------------------------------------------

  Future<void> sendExpertMessage({
    required ExpertPanel panel,
    required List<AIProviderConfig> expertConfigs,
    required AIProviderConfig gatewayConfig,
    required String text,
    List<String>? imagePaths,
    String? filePath,
    String? fileName,
  }) async {
    if (text.trim().isEmpty && (imagePaths == null || imagePaths.isEmpty) && filePath == null) {
      return;
    }

    // Cancel the previous run.  Completed / partial expert responses are
    // KEPT in the message list so the next synthesis has full context.
    _activeRunId++;
    final myRunId = _activeRunId;

    if (state.isStreaming) {
      // Don't remove any messages — just mark streaming as done.
      // Partial content was already saved to DB chunk-by-chunk.
      state = ChatState(
        messages: state.messages,
        isStreaming: false,
        expertPhase: ExpertPhase.none,
      );
    }

    WakelockPlus.enable();

    // Auto-title
    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null && conv.title == 'New Chat') {
        final title = text.trim().length > 30
            ? '${text.trim().substring(0, 30)}...'
            : text.trim();
        await _conversationDao.updateTitle(conversationId, title);
      }
    } catch (_) {}

    // Insert user message
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

    // Insert placeholder messages for each expert
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

    // Build initial expert statuses
    final statuses = <String, ExpertStatus>{};
    for (final config in expertConfigs) {
      statuses[config.id] = ExpertStatus(
        providerId: config.id,
        providerName: config.name,
      );
    }

    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.querying,
      expertStatuses: statuses,
    );

    // Build history — keep only the most recent messages as context.
    final history = _trimHistory(state.messages
        .where((m) => !expertPlaceholders.containsKey(m.id) || m.role == 'user')
        .toList());

    // Query all experts in parallel
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

    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }

    // Update placeholder messages with expert responses
    allMessages = state.messages.toList();
    for (final entry in expertResults.entries) {
      final placeholder = expertPlaceholders[entry.key];
      if (placeholder == null) continue;
      final idx = allMessages.indexWhere((m) => m.id == placeholder.id);
      if (idx >= 0) {
        allMessages[idx] = placeholder.copyWith(content: entry.value);
        await _messageDao.updateContent(placeholder.id, entry.value);
      }
    }

    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.synthesizing,
      expertStatuses: state.expertStatuses,
    );

    // Check if all experts failed
    final hasSuccess = expertResults.values.any(
        (v) => !v.startsWith('错误:') && !v.startsWith('未知错误:'));
    if (!hasSuccess) {
      if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
      state = ChatState(
        messages: allMessages,
        isStreaming: false,
        expertPhase: ExpertPhase.none,
        errorMessage: '所有兼听请求失败，请检查 API 配置',
      );
      WakelockPlus.disable();
      return;
    }

    // Build synthesis prompt
    final configMap = <String, AIProviderConfig>{};
    for (final c in expertConfigs) {
      configMap[c.id] = c;
    }

    final synthesisPrompt = ExpertModeService.buildSynthesisPrompt(
      userQuestion: text,
      expertResponses: expertResults,
      configMap: configMap,
      customPrompt: panel.synthesisPrompt.isNotEmpty ? panel.synthesisPrompt : null,
    );

    // Insert gateway placeholder
    final gatewayPlaceholder = Message(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      metadata: {'type': 'gateway_synthesis'},
    );
    await _messageDao.insert(gatewayPlaceholder);
    allMessages = [...state.messages, gatewayPlaceholder];
    if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
    state = ChatState(
      messages: allMessages,
      isStreaming: true,
      expertPhase: ExpertPhase.synthesizing,
      expertStatuses: state.expertStatuses,
    );

    // Build gateway history — keep only the most recent messages as context.
    final gatewayHistory = _trimHistory(state.messages
        .where((m) => m.id != gatewayPlaceholder.id &&
            (m.metadata == null ||
                m.metadata!['type'] != 'expert_response'))
        .toList());

    // Add a system message for the gateway
    final systemMsg = Message(
      conversationId: conversationId,
      role: 'system',
      content: panel.synthesisPrompt.isNotEmpty
          ? panel.synthesisPrompt
          : '你是一位兼听则明总结助手。以下是多位 AI 对同一个问题的回答。请仔细分析所有回答，找出其中的共同点和分歧，纠正明显的错误，然后给出一个全面、准确、综合的最终答案。',
    );
    gatewayHistory.insert(0, systemMsg);

    final gatewayService = AiService(gatewayConfig);

    try {
      String fullContent = '';
      DateTime lastDbWrite = DateTime.now();
      await for (final chunk in gatewayService.streamChat(
        history: gatewayHistory,
        newUserMessage: synthesisPrompt,
        isCancelled: () => _activeRunId != myRunId,
      )) {
        if (_activeRunId != myRunId) {
          await _messageDao.updateContent(gatewayPlaceholder.id, fullContent);
          WakelockPlus.disable();
          return;
        }
        fullContent += chunk;

        // DB write: max every 2 seconds
        final now = DateTime.now();
        if (now.difference(lastDbWrite).inMilliseconds > 2000) {
          lastDbWrite = now;
          await _messageDao.updateContent(gatewayPlaceholder.id, fullContent);
        }

        // UI update: max every 200ms
        if (now.difference(_lastUiUpdate).inMilliseconds > 200) {
          _lastUiUpdate = now;
          try {
            final updated = state.messages.map((m) {
              return m.id == gatewayPlaceholder.id
                  ? m.copyWith(content: fullContent)
                  : m;
            }).toList();
            if (_activeRunId != myRunId) return;
            state = ChatState(
              messages: updated,
              isStreaming: true,
              expertPhase: ExpertPhase.synthesizing,
              expertStatuses: state.expertStatuses,
            );
          } catch (_) {}
        }
      }

      if (_activeRunId != myRunId) return;
      try {
        final finalMessages = state.messages.map((m) {
          return m.id == gatewayPlaceholder.id
              ? m.copyWith(content: fullContent)
              : m;
        }).toList();
        state = ChatState(
          messages: finalMessages,
          isStreaming: false,
          expertPhase: ExpertPhase.none,
        );
      } catch (_) {}
    } on AiException catch (e) {
      if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
      await _messageDao.updateContent(gatewayPlaceholder.id, '综合失败: ${e.message}');
      try {
        final updated = state.messages.map((m) {
          return m.id == gatewayPlaceholder.id
              ? m.copyWith(content: '综合失败: ${e.message}')
              : m;
        }).toList();
        state = ChatState(
          messages: updated,
          isStreaming: false,
          expertPhase: ExpertPhase.none,
          errorMessage: '网关综合失败: ${e.message}',
        );
      } catch (_) {}
    } catch (e) {
      if (_activeRunId != myRunId) { WakelockPlus.disable(); return; }
      await _messageDao.updateContent(gatewayPlaceholder.id, '综合失败: $e');
      try {
        final updated = state.messages.map((m) {
          return m.id == gatewayPlaceholder.id
              ? m.copyWith(content: '综合失败: $e')
              : m;
        }).toList();
        state = ChatState(
          messages: updated,
          isStreaming: false,
          expertPhase: ExpertPhase.none,
          errorMessage: '网关综合失败: $e',
        );
      } catch (_) {}
    }

    try {
      final conv = await _conversationDao.getById(conversationId);
      if (conv != null) {
        conv.updatedAt = DateTime.now();
        await _conversationDao.update(conv);
      }
    } catch (_) {}

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
    state = ChatState(messages: [...state.messages, msg]);
    return msg.id;
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> deleteMessage(String messageId) async {
    await _messageDao.deleteById(conversationId, messageId);
    final updated = state.messages.where((m) => m.id != messageId).toList();
    state = ChatState(messages: updated);
  }

  Future<void> toggleFavorite(String messageId) async {
    await _messageDao.toggleFavorite(conversationId, messageId);
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isFavorite: !m.isFavorite);
      }
      return m;
    }).toList();
    state = ChatState(messages: updated);
  }
}
