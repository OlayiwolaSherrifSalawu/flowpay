import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/wallet_repository.dart';
import '../../wallets_cards/bmoni_embedded_wallets_cards.dart';
import 'demo_data.dart';

/// Deterministic Demo Implementation of [WalletRepository] satisfying
/// the exact [EmbeddedWalletReadDataSource], [EmbeddedWalletStorage],
/// and [EmbeddedWalletBalanceCache] contracts from bmoni_embedded_wallets_cards.
class DemoWalletRepository implements WalletRepository {
  late List<WalletAccount> _wallets;

  DemoWalletRepository() {
    _wallets = List.from(DemoData.wallets);
  }

  final InMemoryEmbeddedWalletStorage _storage =
      InMemoryEmbeddedWalletStorage();
  final InMemoryEmbeddedWalletBalanceCache _cache =
      InMemoryEmbeddedWalletBalanceCache();

  // Deterministic Demo Embedded Wallets matching BMONI Sandbox personas
  final List<EmbeddedWallet> _demoEmbeddedWallets = [
    const EmbeddedWallet(
      walletId: 'sw_ngn_bunch_dillon_01',
      name: 'Nigerian Naira Smart Wallet',
      currency: 'NGN',
      stablecoinToken: 'CNGN',
      balance: 4850000.00,
      colorSuffix: '01',
      address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      status: 'active',
      metadata: {'employeeId': 'emp_1', 'country': 'NG'},
    ),
    const EmbeddedWallet(
      walletId: 'sw_mxn_samson_jabo_02',
      name: 'Mexican Peso Smart Wallet',
      currency: 'MXN',
      stablecoinToken: 'MEXe',
      balance: 52000.00,
      colorSuffix: '02',
      address: '0x7e81C44F35dB56E522432d6771F52994B6b021ad',
      status: 'active',
      metadata: {'employeeId': 'emp_2', 'country': 'MX'},
    ),
    const EmbeddedWallet(
      walletId: 'sw_usd_treasury_03',
      name: 'US Dollar Smart Wallet',
      currency: 'USD',
      stablecoinToken: 'USDB',
      balance: 12450.00,
      colorSuffix: '03',
      address: '0x8f2d6B48e89405d414a3D65B2Af6d73f1d93E3C1',
      status: 'active',
      metadata: {'employeeId': 'emp_master', 'country': 'US'},
    ),
    const EmbeddedWallet(
      walletId: 'sw_cad_tremblay_04',
      name: 'Canadian Dollar Smart Wallet',
      currency: 'CAD',
      stablecoinToken: 'CADC',
      balance: 6500.00,
      colorSuffix: '04',
      address: '0x192eF2D252b4737d9282cA5F024d9c79238e819b',
      status: 'active',
      metadata: {'employeeId': 'emp_3', 'country': 'CA'},
    ),
  ];

  // =========================================================
  // 1. EmbeddedWalletReadDataSource Implementation
  // =========================================================

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>>
      fetchWallets() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return Right(EmbeddedWalletListResponse(
        wallets: List.unmodifiable(_demoEmbeddedWallets)));
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>>
      fetchWalletDetail(
    String walletId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final found = _demoEmbeddedWallets.firstWhere(
      (w) => w.walletId == walletId,
      orElse: () => _demoEmbeddedWallets.first,
    );
    return Right(EmbeddedWalletDetailResponse(wallet: found));
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(
    String walletId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final found = _demoEmbeddedWallets.firstWhere(
      (w) => w.walletId == walletId,
      orElse: () => _demoEmbeddedWallets.first,
    );
    return Right(EmbeddedWalletBalanceResponse(
      walletId: found.walletId,
      balance: found.balance,
      currency: found.currency,
    ));
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>>
      fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final wallet = _demoEmbeddedWallets.firstWhere(
      (w) => w.walletId == walletId,
      orElse: () => _demoEmbeddedWallets.first,
    );

    final isNg = wallet.currency.toUpperCase() == 'NGN' ||
        wallet.currency.toUpperCase() == 'CNGN';
    final isMx = wallet.currency.toUpperCase() == 'MXN' ||
        wallet.currency.toUpperCase() == 'MEXE';

    final List<EmbeddedWalletTransaction> txs;

    if (isNg) {
      txs = [
        EmbeddedWalletTransaction(
          id: 'tx_ng_01',
          walletId: wallet.walletId,
          amount: 2500000.00,
          currency: 'NGN',
          direction: EmbeddedTransactionDirection.incoming,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Monthly Net Salary Disbursement',
          counterpartyName: 'FlowPay Global Payroll',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          reference: 'FP-PAY-2026-08-NG',
        ),
        EmbeddedWalletTransaction(
          id: 'tx_ng_02',
          walletId: wallet.walletId,
          amount: 18500.00,
          currency: 'NGN',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Mastercard Spend — AWS Cloud',
          counterpartyName: 'Amazon Web Services',
          createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
          reference: 'CARD-AUTH-9418',
        ),
        EmbeddedWalletTransaction(
          id: 'tx_ng_03',
          walletId: wallet.walletId,
          amount: 500000.00,
          currency: 'NGN',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Auto-Sweep: 20% Emergency Savings',
          counterpartyName: 'FlowPay Money Mission #1',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          reference: 'MM-SWEEP-8821',
        ),
        EmbeddedWalletTransaction(
          id: 'tx_ng_04',
          walletId: wallet.walletId,
          amount: 4500.00,
          currency: 'NGN',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Mastercard Spend — Uber Trip',
          counterpartyName: 'Uber BV Lagos',
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
          reference: 'CARD-AUTH-2194',
        ),
      ];
    } else if (isMx) {
      txs = [
        EmbeddedWalletTransaction(
          id: 'tx_mx_01',
          walletId: wallet.walletId,
          amount: 35000.00,
          currency: 'MXN',
          direction: EmbeddedTransactionDirection.incoming,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Monthly Net Salary Disbursement',
          counterpartyName: 'FlowPay Global Payroll (SPEI)',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          reference: 'FP-PAY-2026-08-MX',
        ),
        EmbeddedWalletTransaction(
          id: 'tx_mx_02',
          walletId: wallet.walletId,
          amount: 850.00,
          currency: 'MXN',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Mastercard Spend — GitHub Enterprise',
          counterpartyName: 'GitHub Inc',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          reference: 'CARD-AUTH-6612',
        ),
        EmbeddedWalletTransaction(
          id: 'tx_mx_03',
          walletId: wallet.walletId,
          amount: 7000.00,
          currency: 'MXN',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Auto-Sweep: 20% Tax Reserve',
          counterpartyName: 'FlowPay Money Mission #2',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          reference: 'MM-SWEEP-4192',
        ),
      ];
    } else {
      txs = [
        EmbeddedWalletTransaction(
          id: 'tx_usd_01',
          walletId: wallet.walletId,
          amount: 2500.00,
          currency: 'USD',
          direction: EmbeddedTransactionDirection.incoming,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Global Payroll Disbursement',
          counterpartyName: 'FlowPay Global Payroll',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        EmbeddedWalletTransaction(
          id: 'tx_usd_02',
          walletId: wallet.walletId,
          amount: 142.50,
          currency: 'USD',
          direction: EmbeddedTransactionDirection.outgoing,
          status: EmbeddedWalletTransactionStatus.completed,
          title: 'Mastercard Spend — Google Cloud',
          counterpartyName: 'Google Cloud Platform',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
    }

    return Right(
      EmbeddedWalletTransactionsResponse(
        walletId: wallet.walletId,
        transactions: txs,
        total: txs.length,
        page: page ?? 1,
        pageSize: pageSize ?? 20,
      ),
    );
  }

  // =========================================================
  // 2. EmbeddedWalletStorage Implementation (Delegates to InMemory)
  // =========================================================

  @override
  Future<void> saveWallets(List<EmbeddedWallet> wallets) =>
      _storage.saveWallets(wallets);

  @override
  Future<List<EmbeddedWallet>?> loadWallets() => _storage.loadWallets();

  @override
  Future<void> saveTransactions(
          String walletId, List<EmbeddedWalletTransaction> transactions) =>
      _storage.saveTransactions(walletId, transactions);

  @override
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId) =>
      _storage.loadTransactions(walletId);

  // =========================================================
  // 3. EmbeddedWalletBalanceCache Implementation
  // =========================================================

  @override
  Future<void> saveBalance(String walletId, double balance) =>
      _cache.saveBalance(walletId, balance);

  @override
  Future<double?> loadBalance(String walletId) => _cache.loadBalance(walletId);

  @override
  Future<void> clearAll() => _cache.clearAll();

  // =========================================================
  // 4. Legacy Convenience Methods
  // =========================================================

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
    final newId =
        'sw_demo_${currency.stablecoinToken.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
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
  Future<bool> debitWallet(
      {required String walletId, required Money amount}) async {
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
  Future<bool> creditWallet(
      {required String walletId, required Money amount}) async {
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
