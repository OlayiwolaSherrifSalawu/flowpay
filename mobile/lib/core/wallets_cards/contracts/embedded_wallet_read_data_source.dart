import '../failures/embedded_failure.dart';
import '../models/either.dart';
import '../models/embedded_wallet.dart';

/// Network-facing contract for reading embedded wallet state.
/// Implement this against the BMONI REST API or mock providers.
abstract class EmbeddedWalletReadDataSource {
  /// Fetches all smart wallets belonging to the active user/employee.
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets();

  /// Fetches deep detail for a specific smart wallet.
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(String walletId);

  /// Fetches real-time on-chain balance for a wallet.
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(String walletId);

  /// Fetches paginated transaction history for a wallet.
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  });
}
