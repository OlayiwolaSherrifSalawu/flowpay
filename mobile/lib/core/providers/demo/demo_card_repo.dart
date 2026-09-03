import '../../money/currency.dart';
import '../../repositories/card_repository.dart';
import 'demo_data.dart';

class DemoCardRepository implements CardRepository {
  final List<VirtualCardModel> _cards = List.from(DemoData.cards);

  @override
  Future<List<VirtualCardModel>> getCards() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _cards;
  }

  @override
  Future<VirtualCardModel> createCard({
    required String cardName,
    required String cardColor,
    required Currency currency,
    required String smartWalletId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newCard = VirtualCardModel(
      id: 'card_demo_${DateTime.now().millisecondsSinceEpoch}',
      cardName: cardName,
      cardColor: cardColor,
      currency: currency,
      status: 'active',
      last4: '5512',
      maskedPan: '•••• •••• •••• 5512',
      expirationDate: '12/29',
    );
    _cards.insert(0, newCard);
    return newCard;
  }

  @override
  Future<List<CardTransactionModel>> getCardTransactions(String cardId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return DemoData.transactions.where((tx) => tx.cardId == cardId).toList();
  }

  @override
  Future<VirtualCardModel> toggleCardStatus(String cardId, String currentStatus) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      final old = _cards[idx];
      final newStatus = currentStatus == 'frozen' ? 'active' : 'frozen';
      final updated = VirtualCardModel(
        id: old.id,
        cardName: old.cardName,
        cardColor: old.cardColor,
        currency: old.currency,
        status: newStatus,
        last4: old.last4,
        maskedPan: old.maskedPan,
        expirationDate: old.expirationDate,
        monthlySpendLimit: old.monthlySpendLimit,
      );
      _cards[idx] = updated;
      return updated;
    }
    throw StateError('Card not found');
  }
}
