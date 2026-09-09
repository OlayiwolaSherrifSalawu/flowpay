import '../../money/currency.dart';
import '../../money/money.dart';
import 'wallet_balance_model.dart';

/// Status of a fund reservation in FlowPay's accounting truth layer
enum ReservationStatus {
  active,
  released,
  consumed,
  expired,
  cancelled;

  String get displayName {
    switch (this) {
      case ReservationStatus.active:
        return 'ACTIVE';
      case ReservationStatus.released:
        return 'RELEASED';
      case ReservationStatus.consumed:
        return 'CONSUMED';
      case ReservationStatus.expired:
        return 'EXPIRED';
      case ReservationStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

/// Immutable record of protected funds held by a policy, mission, or escrow
class Reservation {
  final String id;
  final String walletId;
  final String? missionId;
  final Money amount;
  final String reason;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? releasedAt;
  final DateTime? consumedAt;
  final String? txHash;

  const Reservation({
    required this.id,
    required this.walletId,
    this.missionId,
    required this.amount,
    required this.reason,
    this.status = ReservationStatus.active,
    required this.createdAt,
    this.expiresAt,
    this.releasedAt,
    this.consumedAt,
    this.txHash,
  });

  bool get isActive => status == ReservationStatus.active;
  String get purpose => reason;
  String? get missionTag => missionId;

  Reservation copyWith({
    String? id,
    String? walletId,
    String? missionId,
    Money? amount,
    String? reason,
    ReservationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? releasedAt,
    DateTime? consumedAt,
    String? txHash,
  }) {
    return Reservation(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      missionId: missionId ?? this.missionId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      releasedAt: releasedAt ?? this.releasedAt,
      consumedAt: consumedAt ?? this.consumedAt,
      txHash: txHash ?? this.txHash,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'walletId': walletId,
        'missionId': missionId,
        'amountMinor': amount.minorUnits.toString(),
        'currency': amount.currency.code,
        'formattedAmount': amount.toFormattedString(),
        'reason': reason,
        'status': status.displayName,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'releasedAt': releasedAt?.toIso8601String(),
        'consumedAt': consumedAt?.toIso8601String(),
        'txHash': txHash,
      };
}

/// Central Reservation Ledger managing true accounting reservations across wallets
class ReservationLedger {
  static final ReservationLedger _instance = ReservationLedger._internal();
  factory ReservationLedger() => _instance;
  static ReservationLedger get instance => _instance;

  ReservationLedger._internal();

  final List<Reservation> _reservations = [];

  List<Reservation> get allReservations => List.unmodifiable(_reservations);

  /// Create and lock an active reservation against a wallet
  Reservation createReservation({
    required String walletId,
    String? missionId,
    required Money amount,
    required String reason,
    DateTime? expiresAt,
  }) {
    final reservation = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}_${(_reservations.length + 1)}',
      walletId: walletId,
      missionId: missionId,
      amount: amount,
      reason: reason,
      status: ReservationStatus.active,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
    );
    _reservations.add(reservation);
    return reservation;
  }

  /// Release a reservation back to spendable funds
  Reservation? releaseReservation(String reservationId) {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) return null;

    final updated = _reservations[idx].copyWith(
      status: ReservationStatus.released,
      releasedAt: DateTime.now(),
    );
    _reservations[idx] = updated;
    return updated;
  }

  /// Mark reservation as consumed (e.g. tax disbursed or bill paid)
  Reservation? consumeReservation(String reservationId, {String? txHash}) {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) return null;

    final updated = _reservations[idx].copyWith(
      status: ReservationStatus.consumed,
      consumedAt: DateTime.now(),
      txHash: txHash,
    );
    _reservations[idx] = updated;
    return updated;
  }

  /// Get active reservations for a specific wallet or across all wallets
  List<Reservation> getActiveReservations({String? walletId}) {
    return _reservations.where((r) {
      if (!r.isActive) return false;
      if (walletId != null && r.walletId != walletId) return false;
      return true;
    }).toList();
  }

  /// Compute total reserved money in a given wallet for a currency
  Money getTotalReserved(String walletId, Currency currency) {
    final active = getActiveReservations(walletId: walletId)
        .where((r) => r.amount.currency == currency);
    if (active.isEmpty) return Money.zero(currency);

    Money total = Money.zero(currency);
    for (final r in active) {
      total = total.add(r.amount);
    }
    return total;
  }

  Money getReservedAmount(String walletId, Currency currency) =>
      getTotalReserved(walletId, currency);

  Money getReservedAmountByPurpose(String purpose, Currency currency) {
    final p = purpose.toLowerCase();
    final active = _reservations.where((r) =>
        r.isActive &&
        r.amount.currency == currency &&
        r.reason.toLowerCase().contains(p));
    Money total = Money.zero(currency);
    for (final r in active) {
      total = total.add(r.amount);
    }
    return total;
  }

  Money getSpendableBalance(String walletId, Money availableBalance) {
    final reserved = getTotalReserved(walletId, availableBalance.currency);
    if (reserved.minorUnits >= availableBalance.minorUnits) {
      return Money.zero(availableBalance.currency);
    }
    return availableBalance.subtract(reserved);
  }

  WalletBalanceDetails getWalletBalanceDetails(
    String walletId,
    Currency currency,
    Money available,
  ) {
    final reserved = getTotalReserved(walletId, currency);
    final pending = Money.zero(currency);
    return WalletBalanceDetails(
      walletId: walletId,
      walletName: '${currency.code} Wallet',
      address: '0x...',
      currency: currency,
      stablecoinToken: currency.stablecoinToken,
      available: available,
      reserved: reserved,
      pending: pending,
      protectedAmount: reserved,
    );
  }

  /// Reset reservations (used primarily for test isolation)
  void clear() {
    _reservations.clear();
  }
}
