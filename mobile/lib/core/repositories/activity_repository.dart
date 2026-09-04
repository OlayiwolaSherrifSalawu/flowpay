import 'package:flutter/material.dart';
import '../design_system/states.dart';
import '../money/currency.dart';
import '../money/money.dart';

enum ActivityCategory {
  mission,
  transfer,
  card,
  fx,
  payroll,
  system,
}

enum ActivityType {
  transfer,
  conversion,
  mission,
  wallet,
  card,
}

extension ActivityTypeX on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.transfer:
        return 'Transfer';
      case ActivityType.conversion:
        return 'Conversion';
      case ActivityType.mission:
        return 'Mission Execution';
      case ActivityType.wallet:
        return 'Wallet Operation';
      case ActivityType.card:
        return 'Card Transaction';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.transfer:
        return Icons.arrow_outward;
      case ActivityType.conversion:
        return Icons.currency_exchange;
      case ActivityType.mission:
        return Icons.bolt;
      case ActivityType.wallet:
        return Icons.account_balance_wallet_outlined;
      case ActivityType.card:
        return Icons.credit_card;
    }
  }
}

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final Money? amount;
  final Currency currency;
  final ActivityType type;
  final ActivityCategory category;
  final String counterparty; // recipient or merchant
  final FlowPayAppStatus status;
  final DateTime timestamp;
  final String reference; // FlowPay reference
  final String? source;
  final String? destination;
  final Money? fee;
  final String? exchangeRate;
  final String? bmoniReference;
  final Map<String, dynamic>? metadata;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    this.amount,
    Currency? currency,
    ActivityType? type,
    ActivityCategory? category,
    String? counterparty,
    required this.status,
    required this.timestamp,
    String? reference,
    this.source,
    this.destination,
    this.fee,
    this.exchangeRate,
    this.bmoniReference,
    this.metadata,
  })  : type = type ?? _inferType(category, title),
        category = category ?? _inferCategory(type),
        currency = currency ?? amount?.currency ?? Currency.usd,
        reference = reference ?? id,
        counterparty = counterparty ?? _inferCounterparty(metadata, title);

  static ActivityType _inferType(ActivityCategory? cat, String title) {
    if (cat == ActivityCategory.transfer) return ActivityType.transfer;
    if (cat == ActivityCategory.fx) return ActivityType.conversion;
    if (cat == ActivityCategory.mission) return ActivityType.mission;
    if (cat == ActivityCategory.card) return ActivityType.card;
    final lower = title.toLowerCase();
    if (lower.contains('transfer') ||
        lower.contains('sent') ||
        lower.contains('paid')) {
      return ActivityType.transfer;
    }
    if (lower.contains('fx') ||
        lower.contains('conversion') ||
        lower.contains('convert')) {
      return ActivityType.conversion;
    }
    if (lower.contains('mission') ||
        lower.contains('sweep') ||
        lower.contains('rule')) {
      return ActivityType.mission;
    }
    if (lower.contains('card')) return ActivityType.card;
    return ActivityType.wallet;
  }

  static ActivityCategory _inferCategory(ActivityType? t) {
    switch (t) {
      case ActivityType.transfer:
        return ActivityCategory.transfer;
      case ActivityType.conversion:
        return ActivityCategory.fx;
      case ActivityType.mission:
        return ActivityCategory.mission;
      case ActivityType.card:
        return ActivityCategory.card;
      case ActivityType.wallet:
      case null:
        return ActivityCategory.system;
    }
  }

  static String _inferCounterparty(Map<String, dynamic>? meta, String title) {
    if (meta != null) {
      if (meta['recipient'] != null) return meta['recipient'].toString();
      if (meta['merchant'] != null) return meta['merchant'].toString();
    }
    if (title.contains(' to ')) {
      return title.split(' to ').last.trim();
    }
    if (title.contains(': ')) {
      return title.split(': ').last.trim();
    }
    return 'FlowPay Rail';
  }

  ActivityModel copyWith({
    String? id,
    String? title,
    String? description,
    Money? amount,
    Currency? currency,
    ActivityType? type,
    ActivityCategory? category,
    String? counterparty,
    FlowPayAppStatus? status,
    DateTime? timestamp,
    String? reference,
    String? source,
    String? destination,
    Money? fee,
    String? exchangeRate,
    String? bmoniReference,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      category: category ?? this.category,
      counterparty: counterparty ?? this.counterparty,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      reference: reference ?? this.reference,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      fee: fee ?? this.fee,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      bmoniReference: bmoniReference ?? this.bmoniReference,
      metadata: metadata ?? this.metadata,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 60);
      return '${mins}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }
}

abstract class ActivityRepository {
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
    ActivityType? type,
  });

  Future<ActivityModel> recordActivity(ActivityModel activity);
}
