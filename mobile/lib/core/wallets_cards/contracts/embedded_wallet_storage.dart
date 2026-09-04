import '../models/embedded_wallet.dart';

/// Local persistence contract for smart wallets and transaction records.
abstract class EmbeddedWalletStorage {
  Future<void> saveWallets(List<EmbeddedWallet> wallets);
  Future<List<EmbeddedWallet>?> loadWallets();

  Future<void> saveTransactions(
    String walletId,
    List<EmbeddedWalletTransaction> transactions,
  );
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId);
}

/// Ready-to-use in-memory implementation for testing, prototyping, and demo mode.
class InMemoryEmbeddedWalletStorage implements EmbeddedWalletStorage {
  final Map<String, List<EmbeddedWallet>> _wallets = {};
  final Map<String, List<EmbeddedWalletTransaction>> _txs = {};

  @override
  Future<void> saveWallets(List<EmbeddedWallet> wallets) async {
    _wallets['wallets'] = List.unmodifiable(wallets);
  }

  @override
  Future<List<EmbeddedWallet>?> loadWallets() async {
    return _wallets['wallets'];
  }

  @override
  Future<void> saveTransactions(
    String walletId,
    List<EmbeddedWalletTransaction> transactions,
  ) async {
    _txs[walletId] = List.unmodifiable(transactions);
  }

  @override
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(
      String walletId) async {
    return _txs[walletId];
  }

  void clear() {
    _wallets.clear();
    _txs.clear();
  }
}
