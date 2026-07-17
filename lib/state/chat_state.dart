import '../models/message.dart';

enum ExpertPhase { none, querying, synthesizing }

enum ExpertStatusState { pending, streaming, completed, failed }

enum ToolExecStatus { running, completed, failed }

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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ToolExecInfo {
  final String id;
  final String name;
  final String summary;
  final ToolExecStatus status;
  final String? output;

  const ToolExecInfo({
    required this.id,
    required this.name,
    required this.summary,
    this.status = ToolExecStatus.running,
    this.output,
  });

  ToolExecInfo copyWith({
    String? summary,
    ToolExecStatus? status,
    String? output,
  }) {
    return ToolExecInfo(
      id: id,
      name: name,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      output: output ?? this.output,
    );
  }
}

class ChatState {
  final List<Message> messages;
  final bool isStreaming;
  final String? errorMessage;
  final ExpertPhase expertPhase;
  final Map<String, ExpertStatus> expertStatuses;
  final List<ToolExecInfo> toolExecutions;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.errorMessage,
    this.expertPhase = ExpertPhase.none,
    this.expertStatuses = const {},
    this.toolExecutions = const [],
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isStreaming,
    String? errorMessage,
    ExpertPhase? expertPhase,
    Map<String, ExpertStatus>? expertStatuses,
    List<ToolExecInfo>? toolExecutions,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage,
      expertPhase: expertPhase ?? this.expertPhase,
      expertStatuses: expertStatuses ?? this.expertStatuses,
      toolExecutions: toolExecutions ?? this.toolExecutions,
    );
  }
}
