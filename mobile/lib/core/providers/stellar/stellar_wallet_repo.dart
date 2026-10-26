import 'dart:async';

import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/wallet_repository.dart';
import '../../stellar/stellar_api.dart';
import '../../stellar/stellar_key_vault.dart';
import '../../wallets_cards/wallets_cards.dart';

/// Live wallets = the balances of this device's Stellar account, read from the
/// network. There is no local ledger and no offline "fallback" balance: when the
/// network can't be reached, callers get an error, not made-up money.
class StellarWalletRepository implements WalletRepository {
  final StellarApi api;
  final InMemoryEmbeddedWalletStorage _storage = InMemoryEmbeddedWalletStorage();
  final InMemoryEmbeddedWalletBalanceCache _cache = InMemoryEmbeddedWalletBalanceCache();

  StellarWalletRepository({required FlowPayApiClient apiClient}) : api = StellarApi(apiClient);

  static String walletIdFor(String accountId, Currency currency) => '$accountId:${currency.code}';

  Future<StellarAccountSummary?> _summary() async {
    final accountId = await StellarKeyVault.instance.publicKey();
    if (accountId == null) return null;
    return api.account(accountId);
  }

  @override
  Future<List<WalletAccount>> getWallets() async {
    final summary = await _summary();
    if (summary == null || !summary.exists) return const [];
    return [
      for (final b in summary.balances)
        WalletAccount(
          id: walletIdFor(summary.accountId, b.currency),
          address: summary.accountId,
          currency: b.currency,
          stablecoinToken: b.currency.code,
          balance: b.amount,
          status: 'active',
        ),
    ];
  }

  @override
  Future<List<Money>> getBalances() async => [for (final w in await getWallets()) w.balance];

  @override
  Future<String> createManagedWallet({required Currency currency, required String ownerAddress}) {
    throw UnsupportedError('Stellar wallets hold every currency in one account; enable currencies via trustlines instead.');
  }

  @override
  Future<bool> debitWallet({required String walletId, required Money amount}) async => false;

  @override
  Future<bool> creditWallet({required String walletId, required Money amount}) async => false;

  // ── EmbeddedWalletReadDataSource ───────────────────────────────────────

  EmbeddedFailure _failure(Object e) {
    if (e is TimeoutException) return EmbeddedNetworkFailure('The network took too long to respond.', cause: e);
    if (e is ApiException) {
      if (e.statusCode == 404) return EmbeddedNotFoundFailure(e.message, statusCode: 404, cause: e);
      if (e.statusCode >= 500) return EmbeddedServerFailure(e.message, statusCode: e.statusCode, cause: e);
      return EmbeddedValidationFailure(e.message, cause: e);
    }
    return EmbeddedNetworkFailure(e.toString(), cause: e);
  }

  EmbeddedWallet _toEmbedded(WalletAccount w) => EmbeddedWallet(
        walletId: w.id,
        name: '${w.currency.code} balance',
        currency: w.currency.code,
        stablecoinToken: w.currency.code,
        balance: w.balance.minorUnits / 100,
        address: w.address,
        status: w.status,
      );

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets() async {
    try {
      final wallets = (await getWallets()).map(_toEmbedded).toList();
      await _storage.saveWallets(wallets);
      return Right(EmbeddedWalletListResponse(wallets: wallets));
    } catch (e) {
      return Left(_failure(e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(String walletId) async {
    try {
      final match = (await getWallets()).where((w) => w.id == walletId);
      if (match.isEmpty) return Left(EmbeddedNotFoundFailure('Wallet $walletId not found', statusCode: 404));
      return Right(EmbeddedWalletDetailResponse(wallet: _toEmbedded(match.first)));
    } catch (e) {
      return Left(_failure(e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(String walletId) async {
    final detail = await fetchWalletDetail(walletId);
    return detail.fold(
      (f) => Left(f),
      (d) => Right(EmbeddedWalletBalanceResponse(walletId: walletId, balance: d.wallet.balance, currency: d.wallet.currency)),
    );
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) async {
    try {
      final accountId = walletId.split(':').first;
      final currencyCode = walletId.contains(':') ? walletId.split(':').last : null;
      final payments = await api.payments(accountId, limit: pageSize ?? 30);
      final txs = [
        for (final p in payments)
          if (currencyCode == null || p.currency == currencyCode)
            EmbeddedWalletTransaction(
              id: p.id,
              walletId: walletId,
              amount: double.tryParse(p.amount) ?? 0,
              currency: p.currency,
              direction: p.direction == 'incoming' ? EmbeddedTransactionDirection.incoming : EmbeddedTransactionDirection.outgoing,
              status: p.successful ? EmbeddedWalletTransactionStatus.completed : EmbeddedWalletTransactionStatus.failed,
              title: p.type == 'path_payment'
                  ? 'Converted payment'
                  : p.direction == 'incoming'
                      ? 'Received'
                      : 'Sent',
              counterpartyName: p.counterparty,
              createdAt: p.createdAt,
              description: p.memo,
              reference: p.transactionHash,
              metadata: {'explorerUrl': p.explorerUrl},
            ),
      ];
      await _storage.saveTransactions(walletId, txs);
      return Right(EmbeddedWalletTransactionsResponse(
        walletId: walletId,
        transactions: txs,
        total: txs.length,
        page: page ?? 1,
        pageSize: pageSize ?? 30,
      ));
    } catch (e) {
      return Left(_failure(e));
    }
  }

  // ── EmbeddedWalletStorage / EmbeddedWalletBalanceCache ────────────────

  @override
  Future<void> saveWallets(List<EmbeddedWallet> wallets) => _storage.saveWallets(wallets);

  @override
  Future<List<EmbeddedWallet>?> loadWallets() => _storage.loadWallets();

  @override
  Future<void> saveTransactions(String walletId, List<EmbeddedWalletTransaction> transactions) =>
      _storage.saveTransactions(walletId, transactions);

  @override
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId) => _storage.loadTransactions(walletId);

  @override
  Future<void> saveBalance(String walletId, double balance) => _cache.saveBalance(walletId, balance);

  @override
  Future<double?> loadBalance(String walletId) => _cache.loadBalance(walletId);

  @override
  Future<void> clearAll() => _cache.clearAll();
}
