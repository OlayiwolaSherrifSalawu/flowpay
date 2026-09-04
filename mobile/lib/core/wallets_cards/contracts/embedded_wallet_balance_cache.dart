/// Fast cache contract for live smart wallet balances.
abstract class EmbeddedWalletBalanceCache {
  Future<void> saveBalance(String walletId, double balance);
  Future<double?> loadBalance(String walletId);
  Future<void> clearAll();
}

/// In-memory cache implementation for testing and demo execution.
class InMemoryEmbeddedWalletBalanceCache implements EmbeddedWalletBalanceCache {
  final Map<String, double> _balances = {};

  @override
  Future<void> saveBalance(String walletId, double balance) async {
    _balances[walletId] = balance;
  }

  @override
  Future<double?> loadBalance(String walletId) async {
    return _balances[walletId];
  }

  @override
  Future<void> clearAll() async {
    _balances.clear();
  }
}
