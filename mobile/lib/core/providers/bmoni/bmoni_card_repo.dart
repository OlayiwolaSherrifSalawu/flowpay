import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/card_repository.dart';

class BmoniCardRepository implements CardRepository {
  final FlowPayApiClient apiClient;

  BmoniCardRepository({required this.apiClient});

  @override
  Future<List<VirtualCardModel>> getCards() async {
    final res = await apiClient.get('/api/cards');
    if (res is List) {
      return res.map((c) {
        return VirtualCardModel(
          id: c['id'] ?? '',
          cardName: c['cardName'] ?? 'FlowPay Card',
          cardColor: c['cardColor'] ?? '#6366F1',
          currency: Currency.fromCode(c['currency'] ?? 'USD'),
          status: c['status'] ?? 'active',
          last4: c['last4'] ?? '4242',
          maskedPan: c['maskedPan'] ?? '•••• •••• •••• 4242',
          expirationDate: c['expirationDate'] ?? '12/29',
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<VirtualCardModel> createCard({
    required String cardName,
    required String cardColor,
    required Currency currency,
    required String smartWalletId,
  }) async {
    final res = await apiClient.post('/api/cards', body: {
      'cardName': cardName,
      'cardColor': cardColor,
      'currency': currency.code,
      'smartWalletId': smartWalletId,
    });
    final c = res['card'] ?? res;
    return VirtualCardModel(
      id: c['id'] ?? '',
      cardName: c['cardName'] ?? cardName,
      cardColor: c['cardColor'] ?? cardColor,
      currency: currency,
      status: c['status'] ?? 'active',
      last4: c['last4'] ?? '1234',
      maskedPan: c['maskedPan'] ?? '•••• •••• •••• 1234',
      expirationDate: c['expirationDate'] ?? '12/29',
    );
  }

  @override
  Future<List<CardTransactionModel>> getCardTransactions(String cardId) async {
    final res = await apiClient.get('/api/cards/$cardId/transactions');
    if (res is List) {
      return res.map((t) {
        final cur = Currency.fromCode(t['currency'] ?? 'USD');
        return CardTransactionModel(
          id: t['id'] ?? '',
          cardId: cardId,
          amount: Money.fromMinor(t['amountMinor'] ?? 0, cur),
          merchantName: t['merchantName'] ?? 'Merchant',
          category: t['category'] ?? 'General',
          status: t['status'] ?? 'settled',
          timestamp: DateTime.tryParse(t['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<VirtualCardModel> toggleCardStatus(String cardId, String currentStatus) async {
    final res = await apiClient.patch('/api/cards/$cardId/toggle-status', body: {
      'currentStatus': currentStatus,
    });
    final newStatus = res['status'] ?? (currentStatus == 'frozen' ? 'active' : 'frozen');
    return VirtualCardModel(
      id: cardId,
      cardName: 'Card',
      cardColor: '#6366F1',
      currency: Currency.usd,
      status: newStatus,
      last4: '4242',
      maskedPan: '•••• •••• •••• 4242',
      expirationDate: '12/29',
    );
  }
}
