import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/wallet_repository.dart';
import 'demo_data.dart';

class DemoWalletRepository implements WalletRepository {
  @override
  Future<List<WalletAccount>> getWallets() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return DemoData.wallets;
  }

  @override
  Future<List<Money>> getBalances() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return DemoData.wallets.map((w) => w.balance).toList();
  }

  @override
  Future<String> createManagedWallet({
    required Currency currency,
    required String ownerAddress,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newId = 'sw_demo_${currency.stablecoinToken.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    return newId;
  }
}
