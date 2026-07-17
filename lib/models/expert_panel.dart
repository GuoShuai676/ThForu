import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ExpertPanel {
  final String id;
  final String name;
  final List<String> expertProviderIds;
  final String gatewayProviderId;
  final String synthesisPrompt;

  ExpertPanel({
    String? id,
    required this.name,
    required this.expertProviderIds,
    required this.gatewayProviderId,
    this.synthesisPrompt = '',
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'expert_provider_ids': expertProviderIds,
        'gateway_provider_id': gatewayProviderId,
        'synthesis_prompt': synthesisPrompt,
      };

  factory ExpertPanel.fromJson(Map<String, dynamic> json) {
    return ExpertPanel(
      id: json['id'] as String,
      name: json['name'] as String,
      expertProviderIds: (json['expert_provider_ids'] as List).cast<String>(),
      gatewayProviderId: json['gateway_provider_id'] as String,
      synthesisPrompt: json['synthesis_prompt'] as String? ?? '',
    );
  }

  ExpertPanel copyWith({
    String? name,
    List<String>? expertProviderIds,
    String? gatewayProviderId,
    String? synthesisPrompt,
  }) {
    return ExpertPanel(
      id: id,
      name: name ?? this.name,
      expertProviderIds: expertProviderIds ?? this.expertProviderIds,
      gatewayProviderId: gatewayProviderId ?? this.gatewayProviderId,
      synthesisPrompt: synthesisPrompt ?? this.synthesisPrompt,
    );
  }
}
