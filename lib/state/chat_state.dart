import '../models/message.dart';

enum ExpertPhase { none, querying, synthesizing }

enum ExpertStatusState { pending, streaming, completed, failed }

class ExpertStatus {
  final String providerId;
  final String providerName;
  final ExpertStatusState state;
  final String? errorMessage;

  const ExpertStatus({
    required this.providerId,
    required this.providerName,
    this.state = ExpertStatusState.pending,
    this.errorMessage,
  });

  ExpertStatus copyWith({
    ExpertStatusState? state,
    String? errorMessage,
  }) {
    return ExpertStatus(
      providerId: providerId,
      providerName: providerName,
      state: state ?? this.state,
      errorMessage: errorMessage,
    );
  }
}

class ChatState {
  final List<Message> messages;
  final bool isStreaming;
  final String? errorMessage;
  final ExpertPhase expertPhase;
  final Map<String, ExpertStatus> expertStatuses;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.errorMessage,
    this.expertPhase = ExpertPhase.none,
    this.expertStatuses = const {},
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isStreaming,
    String? errorMessage,
    ExpertPhase? expertPhase,
    Map<String, ExpertStatus>? expertStatuses,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage,
      expertPhase: expertPhase ?? this.expertPhase,
      expertStatuses: expertStatuses ?? this.expertStatuses,
    );
  }
}
