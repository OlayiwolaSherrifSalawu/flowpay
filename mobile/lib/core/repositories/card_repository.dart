import '../money/currency.dart';
import '../money/money.dart';

class VirtualCardModel {
  final String id;
  final String cardName;
  final String cardColor;
  final Currency currency;
  final String status; // active, frozen
  final String last4;
  final String maskedPan;
  final String expirationDate;
  final Money? monthlySpendLimit;

  const VirtualCardModel({
    required this.id,
    required this.cardName,
    required this.cardColor,
    required this.currency,
    required this.status,
    required this.last4,
    required this.maskedPan,
    required this.expirationDate,
    this.monthlySpendLimit,
  });
}

class CardTransactionModel {
  final String id;
  final String cardId;
  final Money amount;
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
  Future<List<VirtualCardModel>> getCards();
  Future<VirtualCardModel> createCard({
    required String cardName,
    required String cardColor,
    required Currency currency,
    required String smartWalletId,
  });
  Future<List<CardTransactionModel>> getCardTransactions(String cardId);
  Future<VirtualCardModel> toggleCardStatus(String cardId, String currentStatus);
}
