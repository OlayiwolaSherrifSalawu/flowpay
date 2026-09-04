import '../money/money.dart';
import '../money/currency.dart';
import '../wallets_cards/bmoni_embedded_wallets_cards.dart';

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

/// WalletRepository is a thin wrapper that directly implements
/// [EmbeddedWalletReadDataSource], [EmbeddedWalletStorage], and [EmbeddedWalletBalanceCache]
/// from bmoni_embedded_wallets_cards, while preserving backward-compatible convenience methods.
abstract class WalletRepository
    implements
        EmbeddedWalletReadDataSource,
        EmbeddedWalletStorage,
        EmbeddedWalletBalanceCache {
  // Legacy / convenience helpers
  Future<List<WalletAccount>> getWallets();
  Future<List<Money>> getBalances();
  Future<String> createManagedWallet({
    required Currency currency,
    required String ownerAddress,
  });
}

