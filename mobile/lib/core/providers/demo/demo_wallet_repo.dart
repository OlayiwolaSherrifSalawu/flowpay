import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/wallet_repository.dart';
import 'demo_data.dart';

class DemoWalletRepository implements WalletRepository {
  late List<WalletAccount> _wallets;

  DemoWalletRepository() {
    _wallets = List.from(DemoData.wallets);
  }

  @override
  Future<List<WalletAccount>> getWallets() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_wallets);
  }

  @override
  Future<List<Money>> getBalances() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _wallets.map((w) => w.balance).toList();
  }

  @override
  Future<String> createManagedWallet({
    required Currency currency,
    required String ownerAddress,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newId = 'sw_demo_${currency.stablecoinToken.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    final newWallet = WalletAccount(
      id: newId,
      address: ownerAddress,
      currency: currency,
      stablecoinToken: currency.stablecoinToken,
      balance: Money.zero(currency),
      status: 'active',
    );
    _wallets.add(newWallet);
    return newId;
  }

  @override
  Future<bool> debitWallet({required String walletId, required Money amount}) async {
    int idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx == -1) {
      idx = _wallets.indexWhere((w) => w.currency == amount.currency);
    }
    if (idx != -1) {
      final current = _wallets[idx];
      final newBalance = current.balance.subtract(amount);
      _wallets[idx] = current.copyWith(balance: newBalance);
      return true;
    }
    return false;
  }

  @override
  Future<bool> creditWallet({required String walletId, required Money amount}) async {
    int idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx == -1) {
      idx = _wallets.indexWhere((w) => w.currency == amount.currency);
    }
    if (idx != -1) {
      final current = _wallets[idx];
      final newBalance = current.balance.add(amount);
      _wallets[idx] = current.copyWith(balance: newBalance);
      return true;
    }
    return false;
  }

  void reset() {
    _wallets = List.from(DemoData.wallets);
  }
}
