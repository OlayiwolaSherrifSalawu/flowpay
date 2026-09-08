import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../financial_operator/services/execution_provider.dart' show ExecutionResult;
import '../models/quote_model.dart';
import '../models/smart_payment_plan.dart';
import '../models/wallet_balance_model.dart';
import 'execution_provider.dart';

/// FlowPay Deterministic Demo Execution Provider
/// Implements [ExecutionProvider] with realistic live rates, deterministic quotes,
/// balance tracking, and atomic funds reservations.
class DemoExecutionProvider implements ExecutionProvider {
  final ActivityRepository? activityRepo;
  final WalletRepository? walletRepo;

  bool _isAvailable = true;
  Duration quoteTtl = const Duration(seconds: 45);

  // In-memory wallet balances
  final Map<Currency, WalletBalanceDetails> _wallets = {};

  // Active reservations: reservationId -> List<Money>
  final Map<String, List<Money>> _reservations = {};

  // Realistic FX rates (Target per 1 Source unit)
  static final Map<String, double> _fxRates = {
    // USD base
    'USD_NGN': 1550.00,
    'USD_GHS': 15.50,
    'USD_MXN': 17.20,
    'USD_CAD': 1.35,
    'USD_EUR': 0.9259, // 1 / 1.08
    'USD_GBP': 0.7812, // 1 / 1.28
    // Reverse rates
    'EUR_USD': 1.08,
    'GBP_USD': 1.28,
    'CAD_USD': 0.7407,
    'MXN_USD': 0.0581,
    'NGN_USD': 0.000645,
    'GHS_USD': 0.0645,
  };

  DemoExecutionProvider({
    this.activityRepo,
    this.walletRepo,
    Money? initialUsd,
    Money? initialEur,
    Money? initialNgn,
    Money? initialMxn,
    Money? initialCad,
    bool initialTaxReserve = false,
    Money? taxReserveAmount,
  }) {
    _initDefaultBalances(
      usd: initialUsd ?? Money.fromMajorString('1200.00', Currency.usd),
      eur: initialEur ?? Money.fromMajorString('2000.00', Currency.eur),
      ngn: initialNgn ?? Money.fromMajorString('800000.00', Currency.ngn),
      mxn: initialMxn ?? Money.fromMajorString('48500.00', Currency.mxn),
      cad: initialCad ?? Money.fromMajorString('8250.00', Currency.cad),
      taxReserve: initialTaxReserve,
      taxReserveAmount: taxReserveAmount,
    );
  }

  void _initDefaultBalances({
    required Money usd,
    required Money eur,
    required Money ngn,
    required Money mxn,
    required Money cad,
    bool taxReserve = false,
    Money? taxReserveAmount,
  }) {
    _wallets[Currency.usd] = WalletBalanceDetails(
      walletId: 'sw_demo_usdb_01',
      walletName: 'USD Smart Wallet',
      address: '0x8f2d6B48e89405d414a3D65B2Af6d73f1d93E3C1',
      currency: Currency.usd,
      stablecoinToken: 'USDB',
      available: usd,
      reserved: Money.zero(Currency.usd),
      pending: Money.zero(Currency.usd),
      isProtected: taxReserve,
      protectedAmount: taxReserveAmount ??
          (taxReserve ? Money.fromMajorString('1000.00', Currency.usd) : Money.zero(Currency.usd)),
      purpose: taxReserve ? 'Tax Reserve' : 'Main Treasury',
    );

    _wallets[Currency.eur] = WalletBalanceDetails(
      walletId: 'sw_demo_eure_05',
      walletName: 'EUR Smart Wallet',
      address: '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
      currency: Currency.eur,
      stablecoinToken: 'EURe',
      available: eur,
      reserved: Money.zero(Currency.eur),
      pending: Money.zero(Currency.eur),
      protectedAmount: Money.zero(Currency.eur),
      purpose: 'European Operations',
    );

    _wallets[Currency.ngn] = WalletBalanceDetails(
      walletId: 'sw_demo_cngn_02',
      walletName: 'NGN Smart Wallet',
      address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      currency: Currency.ngn,
      stablecoinToken: 'CNGN',
      available: ngn,
      reserved: Money.zero(Currency.ngn),
      pending: Money.zero(Currency.ngn),
      protectedAmount: Money.zero(Currency.ngn),
      purpose: 'Nigerian Disbursements',
    );

    _wallets[Currency.mxn] = WalletBalanceDetails(
      walletId: 'sw_demo_mexe_03',
      walletName: 'MXN Smart Wallet',
      address: '0x9B10d4818F2312643a60a7F03C12b07C6418B573',
      currency: Currency.mxn,
      stablecoinToken: 'MEXe',
      available: mxn,
      reserved: Money.zero(Currency.mxn),
      pending: Money.zero(Currency.mxn),
      protectedAmount: Money.zero(Currency.mxn),
      purpose: 'LATAM Disbursements',
    );

    _wallets[Currency.cad] = WalletBalanceDetails(
      walletId: 'sw_demo_cadc_04',
      walletName: 'CAD Smart Wallet',
      address: '0x1C44F5a92B7e012354c41893D9B0A361e2A89F90',
      currency: Currency.cad,
      stablecoinToken: 'CADC',
      available: cad,
      reserved: Money.zero(Currency.cad),
      pending: Money.zero(Currency.cad),
      protectedAmount: Money.zero(Currency.cad),
      purpose: 'Canadian Operations',
    );
  }

  /// Update / override a wallet's balance for test scenarios
  void setWalletBalance(Currency currency, Money balance, {bool isProtected = false, Money? protectedAmount}) {
    final existing = _wallets[currency];
    if (existing != null) {
      _wallets[currency] = existing.copyWith(
        available: balance,
        isProtected: isProtected,
        protectedAmount: protectedAmount ?? (isProtected ? balance : Money.zero(currency)),
      );
    }
  }

  /// Toggle provider availability (simulate outage)
  void setAvailable(bool available) {
    _isAvailable = available;
  }

  @override
  String get providerId => 'demo';

  @override
  Future<bool> isAvailable() async => _isAvailable;

  @override
  Future<List<WalletBalanceDetails>> getBalances() async {
    if (!_isAvailable) {
      throw const ProviderUnavailableException(
        provider: 'demo',
        message: 'FlowPay execution provider is offline.',
      );
    }
    if (walletRepo != null) {
      final wallets = await walletRepo!.getWallets();
      return wallets.map<WalletBalanceDetails>((w) {
        final existing = _wallets[w.currency];
        return WalletBalanceDetails(
          walletId: w.id,
          walletName: '${w.currency.code} Smart Wallet',
          address: w.address,
          currency: w.currency,
          stablecoinToken: w.stablecoinToken,
          available: w.balance,
          reserved: Money.zero(w.currency),
          pending: Money.zero(w.currency),
          isProtected: existing?.isProtected ?? false,
          protectedAmount: existing?.protectedAmount ?? Money.zero(w.currency),
          purpose: existing?.purpose,
        );
      }).toList();
    }
    return List.unmodifiable(_wallets.values);
  }

  @override
  Future<List<FundingRoute>> getSupportedRoutes(
      Currency source, Currency destination) async {
    if (!_isAvailable) {
      throw const ProviderUnavailableException(provider: 'demo');
    }

    if (source == destination) {
      return [
        FundingRoute(
          id: 'route_direct_${source.code}',
          sourceCurrency: source,
          destinationCurrency: destination,
          steps: [source.code],
          totalFee: Money.fromMinor(10, source), // $0.10 base rail fee
          exchangeRate: 1.0,
          isDirect: true,
          explanation: 'Direct ${source.code} settlement without currency conversion.',
        ),
      ];
    }

    final key = '${source.code}_${destination.code}';
    final rate = _fxRates[key] ?? 1.0;

    return [
      FundingRoute(
        id: 'route_${source.code}_${destination.code}',
        sourceCurrency: source,
        destinationCurrency: destination,
        steps: [source.code, destination.code],
        totalFee: Money.fromMinor(50, source), // standard fee
        exchangeRate: rate,
        isDirect: false,
        explanation: 'Direct conversion from ${source.code} to ${destination.code} at rate $rate.',
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
    if (!_isAvailable) {
      throw const ProviderUnavailableException(provider: 'demo');
    }

    final quoteId = 'quote_${DateTime.now().millisecondsSinceEpoch}_${source.code}_${destination.code}';
    final expiresAt = DateTime.now().add(quoteTtl);

    if (source == destination) {
      return PaymentQuote(
        quoteId: quoteId,
        sourceCurrency: source,
        sourceAmount: amount,
        destinationCurrency: destination,
        destinationAmount: amount,
        exchangeRate: 1.0,
        providerFee: Money.zero(source),
        networkFee: Money.fromMinor(10, source),
        totalSourceAmount: amount.add(Money.fromMinor(10, source)),
        expiresAt: expiresAt,
        route: 'Direct ${source.code}',
        provider: 'demo',
      );
    }

    final key = '${source.code}_${destination.code}';
    final rate = _fxRates[key] ?? 1.0;

    Money computedSource;
    Money computedDest;

    if (isSourceAmount) {
      computedSource = amount;
      final destUnits = (amount.minorUnits * rate).round();
      computedDest = Money.fromMinor(destUnits, destination);
    } else {
      // Given destination amount, calculate required source amount
      computedDest = amount;
      final sourceUnits = (amount.minorUnits / rate).ceil();
      computedSource = Money.fromMinor(sourceUnits, source);
    }

    final providerFee = Money.fromMinor(
      (computedSource.minorUnits * 0.0015).round(), // 15 bps fee
      source,
    );
    final networkFee = Money.fromMinor(50, source); // fixed $0.50 network fee

    return PaymentQuote(
      quoteId: quoteId,
      sourceCurrency: source,
      sourceAmount: computedSource,
      destinationCurrency: destination,
      destinationAmount: computedDest,
      exchangeRate: rate,
      providerFee: providerFee,
      networkFee: networkFee,
      totalSourceAmount: computedSource.add(providerFee).add(networkFee),
      expiresAt: expiresAt,
      route: '${source.code} -> ${destination.code}',
      provider: 'demo',
    );
  }

  @override
  Future<String> createConversion({
    required Currency from,
    required Currency to,
    required Money amount,
  }) async {
    if (!_isAvailable) {
      throw const ProviderUnavailableException(provider: 'demo');
    }
    return 'conv_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> createTransfer({required SmartPaymentItem item}) async {
    if (!_isAvailable) {
      throw const ProviderUnavailableException(provider: 'demo');
    }
    return 'tx_${item.id}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<bool> reserveFunds(String reservationId, List<Money> amounts) async {
    // Check if sufficient available balances exist
    for (final amt in amounts) {
      final w = _wallets[amt.currency];
      if (w == null || w.spendableBalance.minorUnits < amt.minorUnits) {
        return false;
      }
    }

    // Lock funds into reserved state
    for (final amt in amounts) {
      final w = _wallets[amt.currency]!;
      _wallets[amt.currency] = w.copyWith(
        available: w.available.subtract(amt),
        reserved: w.reserved.add(amt),
      );
    }

    _reservations[reservationId] = amounts;
    return true;
  }

  @override
  Future<void> releaseReservation(String reservationId) async {
    final reservedAmounts = _reservations.remove(reservationId);
    if (reservedAmounts != null) {
      for (final amt in reservedAmounts) {
        final w = _wallets[amt.currency];
        if (w != null) {
          _wallets[amt.currency] = w.copyWith(
            available: w.available.add(amt),
            reserved: w.reserved.subtract(amt),
          );
        }
      }
    }
  }

  @override
  Future<ExecutionResult> executeBatch(
    SmartPaymentBatchPlan plan, {
    required String pin,
  }) async {
    if (!_isAvailable) {
      throw const ProviderUnavailableException(
        provider: 'demo',
        message: 'FlowPay execution rails are currently offline. Transfers are temporarily unavailable.',
      );
    }

    if (plan.isQuoteExpired) {
      throw QuoteExpiredException(
        quoteId: plan.quotes.isNotEmpty ? plan.quotes.first.quoteId : 'batch',
      );
    }

    if (!plan.validation.isValid) {
      return ExecutionResult.failed(
        plan.planId,
        'Cannot execute an invalid financial plan: ${plan.validation.errors.join("; ")}',
      );
    }

    if (pin.trim().length < 4) {
      return ExecutionResult.failed(
        plan.planId,
        'On-device B-Key PIN signature required for execution.',
      );
    }

    final reservationId = 'res_${plan.planId}';
    final reservationAmounts = plan.fundingAllocations
        .map((a) => a.allocatedAmount.add(a.fee))
        .toList();

    // 1. Reserve funds atomically
    final reserved = await reserveFunds(reservationId, reservationAmounts);
    if (!reserved) {
      return ExecutionResult.failed(
        plan.planId,
        'Could not reserve funds. One or more wallets have insufficient spendable balance.',
      );
    }

    try {
      // 2. Settle conversions and transfers (debit reserved amounts permanently)
      for (final amt in reservationAmounts) {
        final w = _wallets[amt.currency]!;
        _wallets[amt.currency] = w.copyWith(
          reserved: w.reserved.subtract(amt),
        );
      }
      _reservations.remove(reservationId);

      // 3. Log activity ledger
      final txHash = '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${plan.planId.hashCode.abs().toRadixString(16)}';

      if (activityRepo != null) {
        for (final item in plan.items) {
          final actModel = ActivityModel(
            id: 'act_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Send ${item.displayAmount.toFormattedString()} to ${item.recipient.displayName}',
            description: '${item.destinationAmount.toFormattedString()} delivered to ${item.destinationRail}',
            amount: item.displayAmount,
            category: ActivityCategory.transfer,
            status: FlowPayAppStatus.completed,
            timestamp: DateTime.now(),
            reference: 'FP-BATCH-${item.id}',
          );
          try {
            await activityRepo!.recordActivity(actModel);
          } catch (_) {}
        }
      }

      return ExecutionResult(
        success: true,
        txHash: txHash,
        planId: plan.planId,
        executedActionsCount: plan.items.length,
        timestamp: DateTime.now(),
        details: {
          'totalRequested': plan.totalRequested.toFormattedString(),
          'totalDebit': plan.totalDebit.toFormattedString(),
          'shortfall': plan.shortfall.toFormattedString(),
          'fundingCurrency': plan.selectedFundingCurrency.code,
        },
      );
    } catch (e) {
      await releaseReservation(reservationId);
      return ExecutionResult.failed(plan.planId, e.toString());
    }
  }

  @override
  Future<String> getTransferStatus(String transferId) async {
    return 'COMPLETED';
  }
}
