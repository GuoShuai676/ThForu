import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/conversation_dao.dart';
import '../db/message_dao.dart';
import '../services/image_service.dart';
import '../services/audio_service.dart';
import '../models/provider_config.dart';
import '../models/expert_panel.dart';
import '../models/persona.dart';
import 'provider_list_notifier.dart';
import 'expert_panel_list_notifier.dart';
import 'conversation_list_notifier.dart';
import 'chat_notifier.dart';
import 'chat_state.dart';
import 'theme_notifier.dart';
import 'formula_display_notifier.dart';
import 'persona_list_notifier.dart';

final routeObserver = RouteObserver<ModalRoute>();

final conversationDaoProvider = Provider<ConversationDao>((ref) {
  return ConversationDao();
});

final messageDaoProvider = Provider<MessageDao>((ref) {
  return MessageDao();
});

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final providerListProvider =
    StateNotifierProvider<ProviderListNotifier, List>((ref) {
  return ProviderListNotifier();
});

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, List>((ref) {
  final dao = ref.watch(conversationDaoProvider);
  return ConversationListNotifier(dao);
});

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, conversationId) {
    final messageDao = ref.watch(messageDaoProvider);
    final conversationDao = ref.watch(conversationDaoProvider);
    ref.keepAlive();
    return ChatNotifier(conversationId, messageDao, conversationDao);
  },
);

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier();
});

final expertPanelListProvider =
    StateNotifierProvider<ExpertPanelListNotifier, List<ExpertPanel>>((ref) {
  return ExpertPanelListNotifier();
});

final resolvedExpertPanelProvider =
    Provider.family<({List<AIProviderConfig> experts, AIProviderConfig gateway})?,
        String?>((ref, panelId) {
  if (panelId == null) return null;
  final panels = ref.watch(expertPanelListProvider);
  final providers = ref.watch(providerListProvider);
  try {
    final panel = panels.firstWhere((p) => p.id == panelId);
    final providerList = providers;
    final experts = panel.expertProviderIds
        .map((id) {
          try {
            return providerList
                .cast<AIProviderConfig?>()
                .firstWhere((p) => p!.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<AIProviderConfig>()
        .toList();
    AIProviderConfig? gateway;
    try {
      gateway = providerList
          .cast<AIProviderConfig?>()
          .firstWhere((p) => p!.id == panel.gatewayProviderId);
    } catch (_) {
      gateway = null;
    }
    if (gateway == null) return null;
    return (experts: experts, gateway: gateway);
  } catch (_) {
    return null;
  }
});

final formulaDisplayProvider =
    StateNotifierProvider<FormulaDisplayNotifier, FormulaDisplayMode>((ref) {
  return FormulaDisplayNotifier();
});

final personaListProvider =
    StateNotifierProvider<PersonaListNotifier, List<Persona>>((ref) {
  return PersonaListNotifier();
});

