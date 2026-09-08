import '../../money/currency.dart';
import '../../money/money.dart';
import '../../financial_operator/services/execution_provider.dart' show ExecutionResult;
import '../models/quote_model.dart';
import '../models/smart_payment_plan.dart';
import '../models/wallet_balance_model.dart';

/// Exception thrown when a provider (e.g. BMONI sandbox) is unreachable or times out
class ProviderUnavailableException implements Exception {
  final String provider;
  final String message;

  const ProviderUnavailableException({
    required this.provider,
    this.message = 'Financial execution provider is temporarily unavailable.',
  });

  @override
  String toString() => 'ProviderUnavailableException ($provider): $message';
}

/// Exception thrown when attempting to execute with an expired quote
class QuoteExpiredException implements Exception {
  final String quoteId;
  final String message;

  const QuoteExpiredException({
    required this.quoteId,
    this.message = 'Payment quote has expired. Please refresh to get current rates.',
  });

  @override
  String toString() => 'QuoteExpiredException ($quoteId): $message';
}

/// Decoupled Execution Provider Interface
/// The AI layer has zero knowledge of the underlying provider (BMONI, Smart Contract, Demo).
abstract class ExecutionProvider {
  /// Provider identity (e.g. 'bmoni', 'demo', 'smart_contract')
  String get providerId;

  /// Whether the provider is currently online and accessible
  Future<bool> isAvailable();

  /// Retrieve verified wallet balances with available/reserved breakdown
  Future<List<WalletBalanceDetails>> getBalances();

  /// Retrieve supported funding and cross-border routes
  Future<List<FundingRoute>> getSupportedRoutes(
      Currency source, Currency destination);

  /// Fetch a firm, time-boxed quote for conversion or cross-border payment
  Future<PaymentQuote> getQuote({
    required Currency source,
    required Currency destination,
    required Money amount,
    bool isSourceAmount = true,
  });

  /// Create a currency conversion inside the wallet
  Future<String> createConversion({
    required Currency from,
    required Currency to,
    required Money amount,
  });

  /// Create a cross-border or local transfer
  Future<String> createTransfer({
    required SmartPaymentItem item,
  });

  /// Atomically reserve funds prior to execution
  Future<bool> reserveFunds(String reservationId, List<Money> amounts);

  /// Release a reservation after settlement or on cancellation
  Future<void> releaseReservation(String reservationId);

  /// Execute an approved payment batch with on-device PIN authorization
  Future<ExecutionResult> executeBatch(
    SmartPaymentBatchPlan plan, {
    required String pin,
  });

  /// Query execution or settlement status
  Future<String> getTransferStatus(String transferId);
}
