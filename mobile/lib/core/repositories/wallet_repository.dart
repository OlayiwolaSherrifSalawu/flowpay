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

  WalletAccount copyWith({
    String? id,
    String? address,
    Currency? currency,
    String? stablecoinToken,
    Money? balance,
    String? status,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      address: address ?? this.address,
      currency: currency ?? this.currency,
      stablecoinToken: stablecoinToken ?? this.stablecoinToken,
      balance: balance ?? this.balance,
      status: status ?? this.status,
    );
  }
}

abstract class WalletRepository {
  Future<List<WalletAccount>> getWallets();
  Future<List<Money>> getBalances();
  Future<String> createManagedWallet({required Currency currency, required String ownerAddress});
  Future<bool> debitWallet({required String walletId, required Money amount}) async => false;
  Future<bool> creditWallet({required String walletId, required Money amount}) async => false;
}
