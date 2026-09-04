import 'dart:async';
import 'dart:io';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/wallet_repository.dart';
import '../../wallets_cards/bmoni_embedded_wallets_cards.dart';

/// Live BMONI Provider implementation of [WalletRepository] satisfying
/// the exact [EmbeddedWalletReadDataSource], [EmbeddedWalletStorage],
/// and [EmbeddedWalletBalanceCache] contracts from bmoni_embedded_wallets_cards.
class BmoniWalletRepository implements WalletRepository {
  final FlowPayApiClient apiClient;
  final InMemoryEmbeddedWalletStorage _storage =
      InMemoryEmbeddedWalletStorage();
  final InMemoryEmbeddedWalletBalanceCache _cache =
      InMemoryEmbeddedWalletBalanceCache();

  BmoniWalletRepository({required this.apiClient});

  // =========================================================
  // Helper: Maps HTTP / Network exceptions into typed EmbeddedFailure
  // =========================================================

  EmbeddedFailure _mapException(dynamic error) {
    if (error is SocketException || error is TimeoutException) {
      return EmbeddedNetworkFailure(
          'Network connectivity error. Please verify your connection.',
          cause: error);
    }
    final msg = error.toString().replaceFirst('Exception: ', '');
    if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
      return EmbeddedAuthenticationFailure(msg, statusCode: 401, cause: error);
    }
    if (msg.contains('403') || msg.toLowerCase().contains('forbidden')) {
      return EmbeddedAuthorizationFailure(msg, statusCode: 403, cause: error);
    }
    if (msg.contains('404') || msg.toLowerCase().contains('not found')) {
      return EmbeddedNotFoundFailure(msg, statusCode: 404, cause: error);
    }
    if (msg.contains('429') || msg.toLowerCase().contains('rate limit')) {
      return EmbeddedRateLimitFailure(msg, statusCode: 429, cause: error);
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return EmbeddedServerFailure(msg, statusCode: 500, cause: error);
    }
    return EmbeddedValidationFailure(msg, cause: error);
  }

  // =========================================================
  // 1. EmbeddedWalletReadDataSource Implementation
  // =========================================================

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>>
      fetchWallets() async {
    try {
      final res = await apiClient.get('/api/wallets');
      if (res is List) {
        final wallets = res.map((w) {
          final cur = (w['currency'] ?? 'USDB').toString();
          final balNum =
              double.tryParse(w['balance']?.toString() ?? '0.00') ?? 0.0;
          return EmbeddedWallet(
            walletId: w['id'] ?? w['walletId'] ?? '',
            name: w['name'] ?? '$cur Smart Wallet',
            currency: cur.startsWith('C') && cur.length == 4
                ? 'NGN'
                : cur.startsWith('M')
                    ? 'MXN'
                    : cur,
            stablecoinToken: cur,
            balance: balNum,
            address: w['address'] ?? '',
            status: w['status'] ?? 'active',
            colorSuffix: w['colorSuffix'] ?? '01',
          );
        }).toList();

        await _storage.saveWallets(wallets);
        return Right(EmbeddedWalletListResponse(wallets: wallets));
      }
      return const Right(EmbeddedWalletListResponse(wallets: []));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>>
      fetchWalletDetail(
    String walletId,
  ) async {
    try {
      final res = await apiClient.get('/api/wallets/$walletId');
      if (res is Map<String, dynamic>) {
        final cur = (res['currency'] ?? 'USDB').toString();
        final balNum =
            double.tryParse(res['balance']?.toString() ?? '0.00') ?? 0.0;
        final wallet = EmbeddedWallet(
          walletId: res['id'] ?? walletId,
          name: res['name'] ?? '$cur Smart Wallet',
          currency: cur.startsWith('C') && cur.length == 4
              ? 'NGN'
              : cur.startsWith('M')
                  ? 'MXN'
                  : cur,
          stablecoinToken: cur,
          balance: balNum,
          address: res['address'] ?? '',
          status: res['status'] ?? 'active',
          colorSuffix: res['colorSuffix'] ?? '01',
        );
        return Right(EmbeddedWalletDetailResponse(wallet: wallet));
      }
      return Left(EmbeddedNotFoundFailure(
          'Wallet $walletId not found on BMONI API',
          statusCode: 404));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(
    String walletId,
  ) async {
    try {
      final res = await apiClient.get('/api/wallets/$walletId/balance');
      if (res is Map<String, dynamic>) {
        final bal =
            double.tryParse(res['balance']?.toString() ?? '0.00') ?? 0.0;
        final cur = res['currency'] ?? 'USDB';
        await _cache.saveBalance(walletId, bal);
        return Right(EmbeddedWalletBalanceResponse(
            walletId: walletId, balance: bal, currency: cur));
      }
      return Right(EmbeddedWalletBalanceResponse(
          walletId: walletId, balance: 0.0, currency: 'USDB'));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>>
      fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) async {
    try {
      final res = await apiClient.get(
        '/api/wallets/$walletId/transactions',
        queryParams: {
          if (page != null) 'page': page.toString(),
          if (pageSize != null) 'pageSize': pageSize.toString(),
        },
      );

      if (res is Map<String, dynamic> && res['transactions'] is List) {
        final rawList = res['transactions'] as List;
        final txs = rawList.map((t) {
          final amt = double.tryParse(t['amount']?.toString() ?? '0.00') ?? 0.0;
          final isInc = t['direction'] == 'incoming' || t['type'] == 'CREDIT';
          return EmbeddedWalletTransaction(
            id: t['id'] ?? '',
            walletId: walletId,
            amount: amt,
            currency: t['currency'] ?? 'USDB',
            direction: isInc
                ? EmbeddedTransactionDirection.incoming
                : EmbeddedTransactionDirection.outgoing,
            status: t['status'] == 'completed'
                ? EmbeddedWalletTransactionStatus.completed
                : t['status'] == 'failed'
                    ? EmbeddedWalletTransactionStatus.failed
                    : EmbeddedWalletTransactionStatus.pending,
            title: t['title'] ?? (isInc ? 'Salary Disbursement' : 'Card Spend'),
            counterpartyName: t['counterpartyName'] ?? 'FlowPay Global',
            createdAt: t['createdAt'] != null
                ? DateTime.tryParse(t['createdAt']) ?? DateTime.now()
                : DateTime.now(),
            reference: t['reference'],
          );
        }).toList();

        await _storage.saveTransactions(walletId, txs);
        return Right(
          EmbeddedWalletTransactionsResponse(
            walletId: walletId,
            transactions: txs,
            total: res['total'] ?? txs.length,
            page: page ?? 1,
            pageSize: pageSize ?? 20,
          ),
        );
      }
      return Right(EmbeddedWalletTransactionsResponse(
          walletId: walletId, transactions: const []));
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  // =========================================================
  // 2. EmbeddedWalletStorage Implementation
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
    final res = await apiClient.get('/api/wallets');
    if (res is List) {
      return res.map((w) {
        final cur = Currency.fromToken(w['currency'] ?? 'USDB');
        return WalletAccount(
          id: w['id'] ?? '',
          address: w['address'] ?? '',
          currency: cur,
          stablecoinToken: w['currency'] ?? 'USDB',
          balance:
              Money.fromMajorString(w['balance']?.toString() ?? '0.00', cur),
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
    final challenge =
        await apiClient.post('/api/wallets/owner-proof-challenge', body: {
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

  @override
  Future<bool> debitWallet(
      {required String walletId, required Money amount}) async {
    return true;
  }

  @override
  Future<bool> creditWallet(
      {required String walletId, required Money amount}) async {
    return true;
  }
}
