import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../financial_operator/services/execution_provider.dart' show ExecutionResult;
import '../models/quote_model.dart';
import '../models/smart_payment_plan.dart';
import '../models/wallet_balance_model.dart';
import 'execution_provider.dart';

/// FlowPay Live BMONI Execution Provider
/// Adapts BMONI Embedded Smart Wallet & Rails APIs for the smart payment engine.
/// Strictly enforces the rule: NEVER fabricate a success response on a failed BMONI call.
class BmoniExecutionProvider implements ExecutionProvider {
  final FlowPayApiClient apiClient;

  BmoniExecutionProvider({required this.apiClient});

  @override
  String get providerId => 'bmoni';

  @override
  Future<bool> isAvailable() async {
    try {
      await apiClient.get('/api/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<WalletBalanceDetails>> getBalances() async {
    try {
      final res = await apiClient.get('/api/wallets');
      final data = res as List<dynamic>;
      return data.map((json) {
        final code = json['currency'] as String? ?? 'USD';
        final curr = Currency.fromCode(code);
        final availUnits = json['availableMinor'] as int? ?? 0;
        final resUnits = json['reservedMinor'] as int? ?? 0;
        final pendUnits = json['pendingMinor'] as int? ?? 0;

        return WalletBalanceDetails(
          walletId: json['id'] as String,
          walletName: json['name'] as String? ?? '${curr.code} Smart Wallet',
          address: json['address'] as String? ?? '',
          currency: curr,
          stablecoinToken: curr.stablecoinToken,
          available: Money.fromMinor(availUnits, curr),
          reserved: Money.fromMinor(resUnits, curr),
          pending: Money.fromMinor(pendUnits, curr),
          isProtected: json['isProtected'] as bool? ?? false,
          protectedAmount: Money.fromMinor(json['protectedMinor'] as int? ?? 0, curr),
        );
      }).toList();
    } catch (e) {
      if (e is ProviderUnavailableException) rethrow;
      throw ProviderUnavailableException(
        provider: 'bmoni',
        message: 'Could not connect to BMONI infrastructure: $e',
      );
    }
  }

  @override
  Future<List<FundingRoute>> getSupportedRoutes(
      Currency source, Currency destination) async {
    return [
      FundingRoute(
        id: 'bmoni_${source.code}_${destination.code}',
        sourceCurrency: source,
        destinationCurrency: destination,
        steps: [source.code, destination.code],
        totalFee: Money.fromMinor(50, source),
        exchangeRate: 1.0,
        explanation: 'BMONI Embedded rails route for ${source.code} to ${destination.code}',
      ),
    ];
  }

  @override
  Future<PaymentQuote> getQuote({
    required Currency source,
    required Currency destination,
    required Money amount,
    bool isSourceAmount = true,
  }) async {
    try {
      final data = await apiClient.post('/api/transfers/quote', body: {
        'sourceCurrency': source.code,
        'destinationCurrency': destination.code,
        'amount': amount.toMajorString(),
        'isSourceAmount': isSourceAmount,
      }) as Map<String, dynamic>;

      final rate = (data['exchangeRate'] as num?)?.toDouble() ?? 1.0;
      final feeUnits = data['feeMinor'] as int? ?? 50;

      return PaymentQuote(
        quoteId: data['quoteId'] as String,
        sourceCurrency: source,
        sourceAmount: amount,
        destinationCurrency: destination,
        destinationAmount: Money.fromMinor(
          (amount.minorUnits * rate).round(),
          destination,
        ),
        exchangeRate: rate,
        providerFee: Money.fromMinor(feeUnits, source),
        networkFee: Money.fromMinor(10, source),
        totalSourceAmount: amount.add(Money.fromMinor(feeUnits + 10, source)),
        expiresAt: DateTime.parse(data['expiresAt'] as String),
        route: '${source.code} -> ${destination.code}',
        provider: 'bmoni',
      );
    } catch (e) {
      if (e is ProviderUnavailableException) rethrow;
      throw ProviderUnavailableException(
        provider: 'bmoni',
        message: 'BMONI quotes service unreachable: $e',
      );
    }
  }

  @override
  Future<String> createConversion({
    required Currency from,
    required Currency to,
    required Money amount,
  }) async {
    try {
      final data = await apiClient.post('/api/transfers/convert', body: {
        'fromCurrency': from.code,
        'toCurrency': to.code,
        'amount': amount.toMajorString(),
      }) as Map<String, dynamic>;
      return data['proposalId'] as String;
    } catch (e) {
      throw ProviderUnavailableException(
        provider: 'bmoni',
        message: 'BMONI conversion creation failed: $e',
      );
    }
  }

  @override
  Future<String> createTransfer({required SmartPaymentItem item}) async {
    try {
      final data = await apiClient.post('/api/transfers/proposal', body: {
        'recipientId': item.recipient.id,
        'amount': item.displayAmount.toMajorString(),
        'destinationCurrency': item.destinationCurrency.code,
      }) as Map<String, dynamic>;
      return data['proposalId'] as String;
    } catch (e) {
      throw ProviderUnavailableException(
        provider: 'bmoni',
        message: 'BMONI transfer creation failed: $e',
      );
    }
  }

  @override
  Future<bool> reserveFunds(String reservationId, List<Money> amounts) async {
    // Live mode delegates reservation tracking to proposal state machine
    return true;
  }

  @override
  Future<void> releaseReservation(String reservationId) async {}

  @override
  Future<ExecutionResult> executeBatch(
    SmartPaymentBatchPlan plan, {
    required String pin,
  }) async {
    try {
      final data = await apiClient.post('/api/transfers/execute-batch', body: {
        'planId': plan.planId,
        'pin': pin,
      }) as Map<String, dynamic>;

      return ExecutionResult(
        success: true,
        txHash: data['txHash'] as String? ?? '',
        planId: plan.planId,
        executedActionsCount: plan.items.length,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ExecutionResult.failed(
        plan.planId,
        'BMONI execution failed: $e',
      );
    }
  }

  @override
  Future<String> getTransferStatus(String transferId) async {
    try {
      final data = await apiClient.get('/api/transfers/$transferId/status') as Map<String, dynamic>;
      return data['status'] as String? ?? 'UNKNOWN';
    } catch (_) {
      return 'UNKNOWN';
    }
  }
}
