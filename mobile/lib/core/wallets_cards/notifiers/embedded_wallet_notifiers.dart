import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../contracts/embedded_wallet_balance_cache.dart';
import '../contracts/embedded_wallet_read_data_source.dart';
import '../contracts/embedded_wallet_storage.dart';
import '../failures/embedded_failure.dart';
import '../models/embedded_wallet.dart';

// ==========================================
// 1. Embedded Wallet List State & Notifier
// ==========================================

@immutable
class EmbeddedWalletListState {
  final List<EmbeddedWallet> wallets;
  final bool isLoading;
  final bool isRefreshing;
  final EmbeddedFailure? failure;

  const EmbeddedWalletListState({
    this.wallets = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.failure,
  });

  bool get hasError => failure != null;

  EmbeddedWalletListState copyWith({
    List<EmbeddedWallet>? wallets,
    bool? isLoading,
    bool? isRefreshing,
    EmbeddedFailure? failure,
    bool clearFailure = false,
  }) {
    return EmbeddedWalletListState(
      wallets: wallets ?? this.wallets,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class EmbeddedWalletListNotifier
    extends StateNotifier<EmbeddedWalletListState> {
  final EmbeddedWalletReadDataSource walletDataSource;
  final EmbeddedWalletStorage? storage;

  EmbeddedWalletListNotifier({
    required this.walletDataSource,
    this.storage,
  }) : super(const EmbeddedWalletListState());

  Future<void> fetchWallets({bool isCache = false}) async {
    if (isCache && storage != null) {
      final cached = await storage!.loadWallets();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(
            wallets: cached, isLoading: false, clearFailure: true);
        return;
      }
    }

    state = state.copyWith(
        isLoading: state.wallets.isEmpty,
        isRefreshing: state.wallets.isNotEmpty);

    final result = await walletDataSource.fetchWallets();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          failure: failure,
        );
      },
      (response) {
        state = state.copyWith(
          wallets: response.wallets,
          isLoading: false,
          isRefreshing: false,
          clearFailure: true,
        );
        storage?.saveWallets(response.wallets);
      },
    );
  }
}

// ==========================================
// 2. Embedded Wallet Balance Notifier
// ==========================================

class EmbeddedWalletBalanceNotifier extends StateNotifier<Map<String, double>> {
  final EmbeddedWalletReadDataSource walletDataSource;
  final EmbeddedWalletBalanceCache? cache;

  EmbeddedWalletBalanceNotifier({
    required this.walletDataSource,
    this.cache,
  }) : super(const {});

  Future<void> fetchWalletBalances(List<String> walletIds,
      {bool isCache = false}) async {
    if (isCache && cache != null) {
      final Map<String, double> cachedMap = {};
      for (final id in walletIds) {
        final bal = await cache!.loadBalance(id);
        if (bal != null) cachedMap[id] = bal;
      }
      if (cachedMap.isNotEmpty) {
        state = {...state, ...cachedMap};
        return;
      }
    }

    final Map<String, double> updated = {...state};
    for (final id in walletIds) {
      final result = await walletDataSource.fetchBalance(id);
      result.fold(
        (_) {}, // Ignore balance failure, keep previous balance
        (resp) {
          updated[id] = resp.balance;
          cache?.saveBalance(id, resp.balance);
        },
      );
    }
    state = updated;
  }
}

// ==========================================
// 3. Embedded Wallet Transactions State & Notifier
// ==========================================

@immutable
class EmbeddedWalletTransactionsState {
  final Map<String, List<EmbeddedWalletTransaction>> transactionsByWallet;
  final bool isLoading;
  final EmbeddedFailure? failure;

  const EmbeddedWalletTransactionsState({
    this.transactionsByWallet = const {},
    this.isLoading = false,
    this.failure,
  });

  bool get hasError => failure != null;

  List<EmbeddedWalletTransaction> getTransactionsForWallet(String walletId) {
    return transactionsByWallet[walletId] ?? const [];
  }

  EmbeddedWalletTransactionsState copyWith({
    Map<String, List<EmbeddedWalletTransaction>>? transactionsByWallet,
    bool? isLoading,
    EmbeddedFailure? failure,
    bool clearFailure = false,
  }) {
    return EmbeddedWalletTransactionsState(
      transactionsByWallet: transactionsByWallet ?? this.transactionsByWallet,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class EmbeddedWalletTransactionsNotifier
    extends StateNotifier<EmbeddedWalletTransactionsState> {
  final EmbeddedWalletReadDataSource walletDataSource;
  final EmbeddedWalletStorage? storage;

  EmbeddedWalletTransactionsNotifier({
    required this.walletDataSource,
    this.storage,
  }) : super(const EmbeddedWalletTransactionsState());

  Future<void> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
    bool isCache = false,
  }) async {
    if (isCache && storage != null) {
      final cached = await storage!.loadTransactions(walletId);
      if (cached != null) {
        final map = {...state.transactionsByWallet, walletId: cached};
        state = state.copyWith(
            transactionsByWallet: map, isLoading: false, clearFailure: true);
        return;
      }
    }

    state = state.copyWith(isLoading: true);

    final result = await walletDataSource.fetchTransactions(walletId,
        page: page, pageSize: pageSize);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, failure: failure);
      },
      (resp) {
        final map = {
          ...state.transactionsByWallet,
          walletId: resp.transactions
        };
        state = state.copyWith(
          transactionsByWallet: map,
          isLoading: false,
          clearFailure: true,
        );
        storage?.saveTransactions(walletId, resp.transactions);
      },
    );
  }
}

// ==========================================
// 4. Standard Riverpod Dependency Providers
// ==========================================

final walletDataSourceProvider = Provider<EmbeddedWalletReadDataSource>((ref) {
  throw UnimplementedError('walletDataSourceProvider must be overridden');
});

final walletStorageProvider = Provider<EmbeddedWalletStorage>((ref) {
  return InMemoryEmbeddedWalletStorage();
});

final walletBalanceCacheProvider = Provider<EmbeddedWalletBalanceCache>((ref) {
  return InMemoryEmbeddedWalletBalanceCache();
});

final walletListProvider =
    StateNotifierProvider<EmbeddedWalletListNotifier, EmbeddedWalletListState>(
  (ref) => EmbeddedWalletListNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    storage: ref.watch(walletStorageProvider),
  ),
);

final walletBalancesProvider =
    StateNotifierProvider<EmbeddedWalletBalanceNotifier, Map<String, double>>(
  (ref) => EmbeddedWalletBalanceNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    cache: ref.watch(walletBalanceCacheProvider),
  ),
);

final walletTransactionsProvider = StateNotifierProvider<
    EmbeddedWalletTransactionsNotifier, EmbeddedWalletTransactionsState>(
  (ref) => EmbeddedWalletTransactionsNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    storage: ref.watch(walletStorageProvider),
  ),
);
