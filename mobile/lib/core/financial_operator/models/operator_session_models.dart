import 'financial_entities.dart';
import 'financial_plan_models.dart';

enum OperatorSessionStatus {
  idle,
  interpreting,
  waitingForClarification,
  readyForReview,
  approved,
  executing,
  completed,
  rejected,
  error;

  bool get isWaitingForClarification =>
      this == OperatorSessionStatus.waitingForClarification;
  bool get isReadyForReview => this == OperatorSessionStatus.readyForReview;
  bool get isExecuting => this == OperatorSessionStatus.executing;
  bool get isCompleted => this == OperatorSessionStatus.completed;
  bool get isTerminal =>
      this == OperatorSessionStatus.completed ||
      this == OperatorSessionStatus.rejected ||
      this == OperatorSessionStatus.error;
}

class ClarificationOptionData {
  final String id;
  final String label;
  final String? subtitle;
  final String value;

  const ClarificationOptionData({
    required this.id,
    required this.label,
    this.subtitle,
    required this.value,
  });
}

class ClarificationPrompt {
  final String id;
  final String targetActionId;
  final String field; // 'recipient', 'destination', 'amount'
  final String question;
  final String description;
  final List<ClarificationOptionData> options;
  final List<PersonEntity> disambiguationCandidates;

  const ClarificationPrompt({
    required this.id,
    required this.targetActionId,
    required this.field,
    required this.question,
    this.description = '',
    this.options = const [],
    this.disambiguationCandidates = const [],
  });
}

class OperatorMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final ClarificationPrompt? clarification;
  final FinancialPlan? plan;
  final Map<String, dynamic>? executionReceipt;
  final bool isError;

  const OperatorMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.clarification,
    this.plan,
    this.executionReceipt,
    this.isError = false,
  });

  factory OperatorMessage.user(String text) {
    return OperatorMessage(
      id: 'msg_u_${DateTime.now().microsecondsSinceEpoch}',
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );
  }

  factory OperatorMessage.operator(
    String text, {
    ClarificationPrompt? clarification,
    FinancialPlan? plan,
    Map<String, dynamic>? executionReceipt,
    bool isError = false,
  }) {
    return OperatorMessage(
      id: 'msg_ai_${DateTime.now().microsecondsSinceEpoch}',
      isUser: false,
      text: text,
      timestamp: DateTime.now(),
      clarification: clarification,
      plan: plan,
      executionReceipt: executionReceipt,
      isError: isError,
    );
  }
}

class OperatorSession {
  final String sessionId;
  final OperatorSessionStatus status;
  final List<OperatorMessage> messages;
  final StructuredIntent? activeIntent;
  final FinancialPlan? activePlan;
  final ClarificationPrompt? pendingClarification;

  const OperatorSession({
    required this.sessionId,
    this.status = OperatorSessionStatus.idle,
    this.messages = const [],
    this.activeIntent,
    this.activePlan,
    this.pendingClarification,
  });

  OperatorSession copyWith({
    String? sessionId,
    OperatorSessionStatus? status,
    List<OperatorMessage>? messages,
    StructuredIntent? activeIntent,
    FinancialPlan? activePlan,
    ClarificationPrompt? pendingClarification,
    bool clearPendingClarification = false,
  }) {
    return OperatorSession(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      activeIntent: activeIntent ?? this.activeIntent,
      activePlan: activePlan ?? this.activePlan,
      pendingClarification: clearPendingClarification
          ? null
          : (pendingClarification ?? this.pendingClarification),
    );
  }
}
