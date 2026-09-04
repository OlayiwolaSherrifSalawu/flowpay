import '../money/currency.dart';
import '../money/money.dart';

class VirtualCardModel {
  final String id;
  final String cardName;
  final String cardColor;
  final Currency currency;
  final String status; // ACTIVE, BLOCKED, RESERVED, pending, etc.
  final String last4;
  final String maskedPan;
  final String expirationDate;
  final String? cvv;
  final String? cardHolderName;
  final Money? monthlySpendLimit;
  final Money? balance;
  final bool isReserved;
  final String? proposalId;
  final String? proposalStatus;
  final String? hashToSign;

  const VirtualCardModel({
    required this.id,
    required this.cardName,
    required this.cardColor,
    required this.currency,
    required this.status,
    required this.last4,
    required this.maskedPan,
    required this.expirationDate,
    this.cvv,
    this.cardHolderName,
    this.monthlySpendLimit,
    this.balance,
    this.isReserved = false,
    this.proposalId,
    this.proposalStatus,
    this.hashToSign,
  });

  bool get isIssuing =>
      isReserved ||
      status.toUpperCase() == 'RESERVED' ||
      (proposalStatus != null && proposalStatus!.toUpperCase() != 'COMPLETED');

  bool get isFrozen =>
      status.toUpperCase() == 'BLOCKED' || status.toUpperCase() == 'FROZEN';

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  VirtualCardModel copyWith({
    String? id,
    String? cardName,
    String? cardColor,
    Currency? currency,
    String? status,
    String? last4,
    String? maskedPan,
    String? expirationDate,
    String? cvv,
    String? cardHolderName,
    Money? monthlySpendLimit,
    Money? balance,
    bool? isReserved,
    String? proposalId,
    String? proposalStatus,
    String? hashToSign,
  }) {
    return VirtualCardModel(
      id: id ?? this.id,
      cardName: cardName ?? this.cardName,
      cardColor: cardColor ?? this.cardColor,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      last4: last4 ?? this.last4,
      maskedPan: maskedPan ?? this.maskedPan,
      expirationDate: expirationDate ?? this.expirationDate,
      cvv: cvv ?? this.cvv,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      monthlySpendLimit: monthlySpendLimit ?? this.monthlySpendLimit,
      balance: balance ?? this.balance,
      isReserved: isReserved ?? this.isReserved,
      proposalId: proposalId ?? this.proposalId,
      proposalStatus: proposalStatus ?? this.proposalStatus,
      hashToSign: hashToSign ?? this.hashToSign,
    );
  }
}

class CreateCardProposalResult {
  final String proposalId;
  final String proposalStatus;
  final String? hashToSign;
  final bool signPayloadPending;
  final String? feeAmount;
  final String? feeCurrency;
  final VirtualCardModel reservedCard;

  const CreateCardProposalResult({
    required this.proposalId,
    required this.proposalStatus,
    this.hashToSign,
    this.signPayloadPending = false,
    this.feeAmount,
    this.feeCurrency,
    required this.reservedCard,
  });
}

class CardTransactionModel {
  final String id;
  final String cardId;
  final Money amount; // Parsed strictly as major units
  final String merchantName;
  final String category;
  final String status;
  final DateTime timestamp;

  const CardTransactionModel({
    required this.id,
    required this.cardId,
    required this.amount,
    required this.merchantName,
    required this.category,
    required this.status,
    required this.timestamp,
  });
}

abstract class CardRepository {
  Future<List<VirtualCardModel>> getCards({
    String? smartWalletId,
    String? userId,
  });

  Future<VirtualCardModel> getCardDetail(
    String cardId, {
    String? smartWalletId,
    String? userId,
  });

  Future<Map<String, dynamic>> getCardSensitiveData(
    String cardId, {
    String? identityId,
    String? userId,
  });

  Future<CreateCardProposalResult> createCardProposal({
    required String cardName,
    String cardColor = '#F4B740',
    required Currency currency,
    required String smartWalletId,
    String? nin,
    String? userId,
  });

  Future<String> fetchSignPayload({
    required String proposalId,
    String? userId,
  });

  Future<VirtualCardModel> submitCardSignature({
    required String proposalId,
    required String signature,
    String? userId,
  });

  Future<VirtualCardModel> createCard({
    required String cardName,
    required String cardColor,
    required Currency currency,
    required String smartWalletId,
    String? nin,
  });

  Future<List<CardTransactionModel>> getCardTransactions(
    String cardId, {
    int? size,
    String? status,
  });

  Future<VirtualCardModel> toggleCardStatus(
    String cardId,
    String currentStatus,
  );

  Future<VirtualCardModel> setCardStatus(
    String cardId, {
    required bool freeze,
    String? userId,
  });
}
