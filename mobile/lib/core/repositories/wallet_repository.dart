import '../money/money.dart';
import '../money/currency.dart';

class WalletAccount {
  final String id;
  final String address;
  final Currency currency;
  final String stablecoinToken;
  final Money balance;
  final String status;

  const WalletAccount({
    required this.id,
    required this.address,
    required this.currency,
    required this.stablecoinToken,
    required this.balance,
    required this.status,
  });
}

abstract class WalletRepository {
  Future<List<WalletAccount>> getWallets();
  Future<List<Money>> getBalances();
  Future<String> createManagedWallet({required Currency currency, required String ownerAddress});
}
