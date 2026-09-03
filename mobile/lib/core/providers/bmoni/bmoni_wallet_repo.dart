import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/wallet_repository.dart';

class BmoniWalletRepository implements WalletRepository {
  final FlowPayApiClient apiClient;

  BmoniWalletRepository({required this.apiClient});

  @override
  Future<List<WalletAccount>> getWallets() async {
    final res = await apiClient.get('/api/wallets');
    if (res is List) {
      return res.map((w) {
        final cur = Currency.fromToken(w['currency'] ?? 'USDB');
        return WalletAccount(
          id: w['id'] ?? '',
          address: w['address'] ?? '',
          currency: cur,
          stablecoinToken: w['currency'] ?? 'USDB',
          balance: Money.fromMajorString('0.00', cur),
          status: w['status'] ?? 'active',
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<List<Money>> getBalances() async {
    final res = await apiClient.get('/api/wallets/balances');
    if (res is List) {
      return res.map((b) {
        final cur = Currency.fromToken(b['currency'] ?? 'USDB');
        final balStr = b['balance']?.toString() ?? '0.00';
        return Money.fromMajorString(balStr, cur);
      }).toList();
    }
    return [];
  }

  @override
  Future<String> createManagedWallet({
    required Currency currency,
    required String ownerAddress,
  }) async {
    final challenge = await apiClient.post('/api/wallets/owner-proof-challenge', body: {
      'currency': currency.stablecoinToken,
      'userOwnerAddress': ownerAddress,
    });

    final res = await apiClient.post('/api/wallets/create-managed', body: {
      'currency': currency.stablecoinToken,
      'userOwnerAddress': ownerAddress,
      'ownerProofChallengeId': challenge['challengeId'],
      'ownerProofSignature': '0x_signed_challenge_placeholder',
    });

    return res['id'] ?? '';
  }
}
