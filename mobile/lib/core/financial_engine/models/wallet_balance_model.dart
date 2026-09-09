import '../../money/currency.dart';
import '../../money/money.dart';

/// FlowPay Detailed Wallet Balance Model
/// Distinguishes Available, Reserved, Pending, and Total balances.
/// Specifically excludes protected funds (e.g. Tax Reserve) from spendable balance.
class WalletBalanceDetails {
  final String walletId;
  final String walletName;
  final String address;
  final Currency currency;
  final String stablecoinToken;
  final Money available; // Immediately spendable funds
  final Money reserved; // Funds reserved for active pending proposals
  final Money pending; // Unsettled incoming funds
  final bool isProtected; // Whether this wallet or portion of funds is protected
  final Money protectedAmount; // Quarantined amount (e.g. Tax Reserve)
  final String? purpose;

  const WalletBalanceDetails({
    required this.walletId,
    required this.walletName,
    required this.address,
    required this.currency,
    required this.stablecoinToken,
    required this.available,
    required this.reserved,
    required this.pending,
    this.isProtected = false,
    required this.protectedAmount,
    this.purpose,
  });

  /// Total balance held in wallet
  Money get total => available.add(reserved);

  /// Effective spendable balance strictly excluding reservations and pending holds
  Money get spendableBalance {
    final locked = reserved.minorUnits > protectedAmount.minorUnits
        ? reserved.minorUnits
        : protectedAmount.minorUnits;
    final effectiveAvailable = (available.minorUnits >= locked && reserved.minorUnits == 0)
        ? available.minorUnits - locked
        : available.minorUnits;
    final afterPending = effectiveAvailable - pending.minorUnits;
    return Money.fromMinor(
      afterPending < 0 ? 0 : afterPending,
      currency,
    );
  }

  Money get spendable => spendableBalance;

  bool get hasReservations =>
      reserved.minorUnits > 0 || protectedAmount.minorUnits > 0;

  /// Human-friendly explanation of wallet balances
  String get balanceSummary {
    if (reserved.minorUnits > 0 || protectedAmount.minorUnits > 0) {
      final resAmt = reserved.minorUnits > 0 ? reserved : protectedAmount;
      return 'Total: ${total.toFormattedString()} • Reserved: ${resAmt.toFormattedString()} • Spendable: ${spendableBalance.toFormattedString()}';
    }
    return 'Total: ${total.toFormattedString()} • Spendable: ${spendableBalance.toFormattedString()}';
  }

  WalletBalanceDetails copyWith({
    String? walletId,
    String? walletName,
    String? address,
    Currency? currency,
    String? stablecoinToken,
    Money? available,
    Money? reserved,
    Money? pending,
    bool? isProtected,
    Money? protectedAmount,
    String? purpose,
  }) {
    return WalletBalanceDetails(
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      address: address ?? this.address,
      currency: currency ?? this.currency,
      stablecoinToken: stablecoinToken ?? this.stablecoinToken,
      available: available ?? this.available,
      reserved: reserved ?? this.reserved,
      pending: pending ?? this.pending,
      isProtected: isProtected ?? this.isProtected,
      protectedAmount: protectedAmount ?? this.protectedAmount,
      purpose: purpose ?? this.purpose,
    );
  }

  Map<String, dynamic> toJson() => {
        'walletId': walletId,
        'walletName': walletName,
        'address': address,
        'currencyCode': currency.code,
        'stablecoinToken': stablecoinToken,
        'availableMinor': available.minorUnits,
        'reservedMinor': reserved.minorUnits,
        'pendingMinor': pending.minorUnits,
        'totalMinor': total.minorUnits,
        'spendableMinor': spendableBalance.minorUnits,
        'isProtected': isProtected,
        'protectedAmountMinor': protectedAmount.minorUnits,
        'purpose': purpose,
      };
}

/// Structured Balance Target Model
/// Represents a user's natural language goal (e.g. "Make sure I have $2,000 in USD")
class BalanceTarget {
  final Currency currency;
  final Money minimumAmount;
  final String purpose;
  final List<Currency> sourceWallets;
  final int priority;
  final DateTime? expiry;

  const BalanceTarget({
    required this.currency,
    required this.minimumAmount,
    this.purpose = 'wallet_balancing',
    this.sourceWallets = const [Currency.usd, Currency.eur, Currency.ngn],
    this.priority = 1,
    this.expiry,
  });
}

/// User Financial Preferences Model
class FinancialPreferences {
  final Currency? preferredFundingWallet;
  final List<Currency> preferredFundingOrder;
  final bool allowAutomaticRebalancing;
  final Currency preferredDisplayCurrency;
  final String feePreference; // 'lowest_cost', 'fastest', 'direct_only'

  const FinancialPreferences({
    this.preferredFundingWallet = Currency.usd,
    this.preferredFundingOrder = const [
      Currency.usd,
      Currency.eur,
      Currency.ngn,
      Currency.cad,
      Currency.mxn,
      Currency.gbp,
    ],
    this.allowAutomaticRebalancing = true,
    this.preferredDisplayCurrency = Currency.usd,
    this.feePreference = 'lowest_cost',
  });
}
