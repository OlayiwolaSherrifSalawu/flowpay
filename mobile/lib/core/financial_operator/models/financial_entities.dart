import '../../beneficiaries/beneficiary_model.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import 'financial_intent_types.dart';

/// Entity Knowledge State
/// Enforces the core invariant: Critical financial fields should never silently
/// transition from UNKNOWN to KNOWN through an AI guess or hallucination.
enum EntityKnowledgeState {
  known,
  unknown,
  ambiguous,
  inferred,
  requiresConfirmation;

  bool get isKnown => this == EntityKnowledgeState.known;
  bool get isUnknown => this == EntityKnowledgeState.unknown;
  bool get isAmbiguous => this == EntityKnowledgeState.ambiguous;
  bool get isResolvable => isKnown || isAmbiguous;
}

/// Person / Counterparty Entity
class PersonEntity {
  final String rawInput;
  final Beneficiary? resolvedBeneficiary;
  final List<Beneficiary> candidates;
  final EntityKnowledgeState knowledgeState;
  final String? aliasMatched;

  const PersonEntity({
    required this.rawInput,
    this.resolvedBeneficiary,
    this.candidates = const [],
    this.knowledgeState = EntityKnowledgeState.unknown,
    this.aliasMatched,
  });

  PersonEntity copyWith({
    String? rawInput,
    Beneficiary? resolvedBeneficiary,
    List<Beneficiary>? candidates,
    EntityKnowledgeState? knowledgeState,
    String? aliasMatched,
  }) {
    return PersonEntity(
      rawInput: rawInput ?? this.rawInput,
      resolvedBeneficiary: resolvedBeneficiary ?? this.resolvedBeneficiary,
      candidates: candidates ?? this.candidates,
      knowledgeState: knowledgeState ?? this.knowledgeState,
      aliasMatched: aliasMatched ?? this.aliasMatched,
    );
  }

  String get displayName {
    if (resolvedBeneficiary != null) {
      if (resolvedBeneficiary!.nickname.isNotEmpty &&
          resolvedBeneficiary!.nickname.toLowerCase() !=
              resolvedBeneficiary!.legalName.toLowerCase()) {
        return '${resolvedBeneficiary!.legalName} (${resolvedBeneficiary!.nickname})';
      }
      return resolvedBeneficiary!.legalName;
    }
    return rawInput;
  }
}

/// Destination category
enum DestinationType {
  wallet,
  reserve,
  beneficiary,
  bill,
  externalAccount,
  unspecified;
}

/// Wallet / Reserve / Financial Destination Entity
class DestinationEntity {
  final DestinationType type;
  final String rawInput;
  final String? resolvedWalletId;
  final String? resolvedWalletName;
  final Currency? resolvedCurrency;
  final EntityKnowledgeState knowledgeState;

  const DestinationEntity({
    this.type = DestinationType.unspecified,
    required this.rawInput,
    this.resolvedWalletId,
    this.resolvedWalletName,
    this.resolvedCurrency,
    this.knowledgeState = EntityKnowledgeState.unknown,
  });

  DestinationEntity copyWith({
    DestinationType? type,
    String? rawInput,
    String? resolvedWalletId,
    String? resolvedWalletName,
    Currency? resolvedCurrency,
    EntityKnowledgeState? knowledgeState,
  }) {
    return DestinationEntity(
      type: type ?? this.type,
      rawInput: rawInput ?? this.rawInput,
      resolvedWalletId: resolvedWalletId ?? this.resolvedWalletId,
      resolvedWalletName: resolvedWalletName ?? this.resolvedWalletName,
      resolvedCurrency: resolvedCurrency ?? this.resolvedCurrency,
      knowledgeState: knowledgeState ?? this.knowledgeState,
    );
  }

  String get displayName => resolvedWalletName ?? rawInput;
}

/// Amount specification type
enum AmountType {
  fixed,
  percentage,
  half,
  remainder,
  unspecified;
}

/// Amount & Currency Entity
class AmountEntity {
  final String rawInput;
  final AmountType type;
  final Money? fixedAmount;
  final double? percentage; // e.g. 30.0 for 30%
  final Currency currency;
  final Money? resolvedAmount;
  final EntityKnowledgeState knowledgeState;

  const AmountEntity({
    required this.rawInput,
    this.type = AmountType.fixed,
    this.fixedAmount,
    this.percentage,
    this.currency = Currency.usd,
    this.resolvedAmount,
    this.knowledgeState = EntityKnowledgeState.known,
  });

  AmountEntity copyWith({
    String? rawInput,
    AmountType? type,
    Money? fixedAmount,
    double? percentage,
    Currency? currency,
    Money? resolvedAmount,
    EntityKnowledgeState? knowledgeState,
  }) {
    return AmountEntity(
      rawInput: rawInput ?? this.rawInput,
      type: type ?? this.type,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      percentage: percentage ?? this.percentage,
      currency: currency ?? this.currency,
      resolvedAmount: resolvedAmount ?? this.resolvedAmount,
      knowledgeState: knowledgeState ?? this.knowledgeState,
    );
  }

  String get formattedDisplay {
    if (resolvedAmount != null) {
      return resolvedAmount!.toFormattedString();
    }
    if (fixedAmount != null) {
      return fixedAmount!.toFormattedString();
    }
    if (type == AmountType.percentage && percentage != null) {
      return '${percentage!.toStringAsFixed(0)}%';
    }
    if (type == AmountType.half) {
      return 'Half (50%)';
    }
    if (type == AmountType.remainder) {
      return 'Remaining balance';
    }
    return rawInput;
  }
}

/// A parsed action inside a user financial request
class ActionIntent {
  final String id;
  final FinancialIntentType intentType;
  final PersonEntity? person;
  final DestinationEntity? destination;
  final AmountEntity amount;
  final String? purpose;
  final String description;

  const ActionIntent({
    required this.id,
    required this.intentType,
    this.person,
    this.destination,
    required this.amount,
    this.purpose,
    required this.description,
  });

  ActionIntent copyWith({
    String? id,
    FinancialIntentType? intentType,
    PersonEntity? person,
    DestinationEntity? destination,
    AmountEntity? amount,
    String? purpose,
    String? description,
  }) {
    return ActionIntent(
      id: id ?? this.id,
      intentType: intentType ?? this.intentType,
      person: person ?? this.person,
      destination: destination ?? this.destination,
      amount: amount ?? this.amount,
      purpose: purpose ?? this.purpose,
      description: description ?? this.description,
    );
  }

  List<String> get missingFields {
    final list = <String>[];
    if (intentType == FinancialIntentType.sendMoney ||
        intentType == FinancialIntentType.payBeneficiary) {
      if (person == null ||
          person!.knowledgeState != EntityKnowledgeState.known) {
        list.add('recipient');
      }
    }
    if (intentType == FinancialIntentType.createReserve ||
        intentType == FinancialIntentType.updateReserve ||
        purpose == 'tax') {
      if (destination == null ||
          destination!.knowledgeState != EntityKnowledgeState.known) {
        list.add('destination');
      }
    }
    if (amount.knowledgeState != EntityKnowledgeState.known &&
        amount.type == AmountType.unspecified) {
      list.add('amount');
    }
    return list;
  }

  bool get isComplete => missingFields.isEmpty;
}

/// Structured Financial Intent resulting from parsing & entity extraction
class StructuredIntent {
  final String id;
  final FinancialIntentType primaryIntent;
  final String originalPrompt;
  final List<ActionIntent> actions;
  final AmountEntity? incomingAmount;
  final double confidenceScore;

  const StructuredIntent({
    required this.id,
    required this.primaryIntent,
    required this.originalPrompt,
    required this.actions,
    this.incomingAmount,
    this.confidenceScore = 1.0,
  });

  StructuredIntent copyWith({
    String? id,
    FinancialIntentType? primaryIntent,
    String? originalPrompt,
    List<ActionIntent>? actions,
    AmountEntity? incomingAmount,
    double? confidenceScore,
  }) {
    return StructuredIntent(
      id: id ?? this.id,
      primaryIntent: primaryIntent ?? this.primaryIntent,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      actions: actions ?? this.actions,
      incomingAmount: incomingAmount ?? this.incomingAmount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }

  List<String> get allMissingFields {
    final fields = <String>{};
    for (final action in actions) {
      fields.addAll(action.missingFields);
    }
    return fields.toList();
  }

  bool get isReadyForPlanning => allMissingFields.isEmpty && actions.isNotEmpty;
}
