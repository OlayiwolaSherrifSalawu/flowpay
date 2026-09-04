import 'package:flutter/foundation.dart';

/// Direction of wallet transaction
enum EmbeddedTransactionDirection {
  incoming,
  outgoing,
}

/// Status of wallet transaction
enum EmbeddedWalletTransactionStatus {
  pending,
  completed,
  failed,
}

/// Core read model for an embedded smart wallet.
@immutable
class EmbeddedWallet {
  final String walletId;
  final String name;
  final String currency; // ISO 4217, e.g. 'USD', 'NGN', 'MXN', 'CAD'
  final String? stablecoinToken; // e.g. 'USDB', 'CNGN', 'MEXe', 'CADC'
  final double balance;
  final String? colorSuffix; // '01'-'06' or null for default background art
  final String? address; // EVM smart wallet address (debug/support detail)
  final String status; // 'active', 'pending', 'frozen', etc.
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  const EmbeddedWallet({
    required this.walletId,
    required this.name,
    required this.currency,
    this.stablecoinToken,
    required this.balance,
    this.colorSuffix,
    this.address,
    this.status = 'active',
    this.createdAt,
    this.metadata,
  });

  String get id => walletId;

  EmbeddedWallet copyWith({
    String? walletId,
    String? name,
    String? currency,
    String? stablecoinToken,
    double? balance,
    String? colorSuffix,
    String? address,
    String? status,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return EmbeddedWallet(
      walletId: walletId ?? this.walletId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      stablecoinToken: stablecoinToken ?? this.stablecoinToken,
      balance: balance ?? this.balance,
      colorSuffix: colorSuffix ?? this.colorSuffix,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddedWallet &&
          walletId == other.walletId &&
          currency == other.currency &&
          balance == other.balance &&
          address == other.address &&
          status == other.status;

  @override
  int get hashCode =>
      walletId.hashCode ^
      currency.hashCode ^
      balance.hashCode ^
      address.hashCode ^
      status.hashCode;
}

/// Model for an embedded wallet transaction.
@immutable
class EmbeddedWalletTransaction {
  final String id;
  final String walletId;
  final double amount;
  final String currency;
  final EmbeddedTransactionDirection direction;
  final EmbeddedWalletTransactionStatus status;
  final String title;
  final String? counterpartyName;
  final DateTime createdAt;
  final String? description;
  final String? reference;
  final Map<String, dynamic>? metadata;

  const EmbeddedWalletTransaction({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    required this.title,
    this.counterpartyName,
    required this.createdAt,
    this.description,
    this.reference,
    this.metadata,
  });

  bool get isIncoming => direction == EmbeddedTransactionDirection.incoming;
  bool get isOutgoing => direction == EmbeddedTransactionDirection.outgoing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddedWalletTransaction &&
          id == other.id &&
          walletId == other.walletId &&
          amount == other.amount &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ walletId.hashCode ^ amount.hashCode ^ status.hashCode;
}

/// Response payload for listing smart wallets.
@immutable
class EmbeddedWalletListResponse {
  final List<EmbeddedWallet> wallets;

  const EmbeddedWalletListResponse({required this.wallets});
}

/// Response payload for wallet detail.
@immutable
class EmbeddedWalletDetailResponse {
  final EmbeddedWallet wallet;

  const EmbeddedWalletDetailResponse({required this.wallet});
}

/// Response payload for live wallet balance.
@immutable
class EmbeddedWalletBalanceResponse {
  final String walletId;
  final double balance;
  final String currency;

  const EmbeddedWalletBalanceResponse({
    required this.walletId,
    required this.balance,
    required this.currency,
  });
}

/// Response payload for transactions list with pagination.
@immutable
class EmbeddedWalletTransactionsResponse {
  final String walletId;
  final List<EmbeddedWalletTransaction> transactions;
  final int total;
  final int page;
  final int pageSize;

  const EmbeddedWalletTransactionsResponse({
    required this.walletId,
    required this.transactions,
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
  });
}
