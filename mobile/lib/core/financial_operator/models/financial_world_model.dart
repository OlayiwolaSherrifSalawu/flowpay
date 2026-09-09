import '../../money/currency.dart';
import '../../beneficiaries/beneficiary_model.dart';
import '../../repositories/wallet_repository.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/mission_repository.dart';
import '../services/financial_context_service.dart';

typedef ReserveEntity = ReserveAccount;

/// Supported financial entity categories in FlowPay's World Model
enum FinancialEntityType {
  person,
  beneficiary,
  wallet,
  reserve,
  mission,
  account,
  bankAccount,
  card,
  currency,
  reservation,
}

/// Strongly typed financial entity representation
class ResolvedEntity {
  final String id;
  final FinancialEntityType type;
  final String displayName;
  final Currency? currency;
  final bool isCurrentUserOwned;
  final String? accountOrAddress;
  final Map<String, dynamic> metadata;

  const ResolvedEntity({
    required this.id,
    required this.type,
    required this.displayName,
    this.currency,
    this.isCurrentUserOwned = false,
    this.accountOrAddress,
    this.metadata = const {},
  });

  bool get isWallet => type == FinancialEntityType.wallet;
  bool get isBeneficiary => type == FinancialEntityType.beneficiary || type == FinancialEntityType.person;
  bool get isReserve => type == FinancialEntityType.reserve;
  bool get isMission => type == FinancialEntityType.mission;
}

/// Typed Financial World Model representing user's complete financial context
class FinancialWorld {
  final List<WalletAccount> wallets;
  final List<Beneficiary> beneficiaries;
  final List<ReserveEntity> reserves;
  final List<MoneyMissionModel> missions;
  final List<ActivityModel> recentTransactions;
  final Map<String, dynamic> preferences;

  const FinancialWorld({
    this.wallets = const [],
    this.beneficiaries = const [],
    this.reserves = const [],
    this.missions = const [],
    this.recentTransactions = const [],
    this.preferences = const {},
  });

  /// Retrieve wallet matching currency code or name
  WalletAccount? findWalletByCurrency(Currency currency) {
    try {
      return wallets.firstWhere((w) => w.currency == currency);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve wallet by loose query (e.g. "usd", "naira", "dollar", "ngn")
  WalletAccount? findWalletByQuery(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.contains('usd') || lower.contains('dollar')) {
      return findWalletByCurrency(Currency.usd);
    }
    if (lower.contains('naira') || lower.contains('ngn') || lower.contains('cngn')) {
      return findWalletByCurrency(Currency.ngn);
    }
    if (lower.contains('peso') || lower.contains('mxn') || lower.contains('mexe')) {
      return findWalletByCurrency(Currency.mxn);
    }
    if (lower.contains('cad') || lower.contains('canadian')) {
      return findWalletByCurrency(Currency.cad);
    }
    if (lower.contains('eur') || lower.contains('euro')) {
      return findWalletByCurrency(Currency.eur);
    }
    if (lower.contains('gbp') || lower.contains('pound')) {
      return findWalletByCurrency(Currency.gbp);
    }
    return null;
  }

  /// Contextual search for beneficiaries by alias, relationship, or legal name
  Beneficiary? findBeneficiary(String query) {
    final lower = query.toLowerCase().trim();
    for (final b in beneficiaries) {
      if (b.nickname.toLowerCase() == lower ||
          b.legalName.toLowerCase() == lower ||
          b.relationship.toLowerCase() == lower ||
          b.aliases.any((a) => a.toLowerCase() == lower)) {
        return b;
      }
    }
    // Partial search
    for (final b in beneficiaries) {
      if (b.nickname.toLowerCase().contains(lower) ||
          b.legalName.toLowerCase().contains(lower) ||
          b.relationship.toLowerCase().contains(lower) ||
          b.aliases.any((a) => a.toLowerCase().contains(lower))) {
        return b;
      }
    }
    return null;
  }

  /// Contextual search for reserves (e.g. "tax", "savings", "emergency")
  ReserveEntity? findReserve(String query) {
    final lower = query.toLowerCase().trim();
    for (final r in reserves) {
      if (r.name.toLowerCase().contains(lower) ||
          r.targetWalletId.toLowerCase().contains(lower)) {
        return r;
      }
    }
    return null;
  }

  /// Contextual search for missions (e.g. "tax", "savings")
  MoneyMissionModel? findMission(String query) {
    final lower = query.toLowerCase().trim();
    for (final m in missions) {
      if (m.title.toLowerCase().contains(lower) ||
          m.tagline.toLowerCase().contains(lower) ||
          m.id.toLowerCase() == lower) {
        return m;
      }
    }
    return null;
  }
}
