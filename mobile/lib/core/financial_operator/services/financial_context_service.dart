import '../../beneficiaries/beneficiary_model.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/mission_repository.dart';
import '../../repositories/wallet_repository.dart';

/// Information about an existing or conceptual Reserve
class ReserveAccount {
  final String id;
  final String name;
  final String purpose;
  final Currency currency;
  final Money currentBalance;
  final String targetWalletId;

  const ReserveAccount({
    required this.id,
    required this.name,
    required this.purpose,
    required this.currency,
    required this.currentBalance,
    required this.targetWalletId,
  });
}

/// Controlled Financial Context Service
/// Implements the tool layer described in Prompt Directive #17 & #18:
/// Safe application tools layer with permissioned, read-only access to
/// application state. AI never directly accesses the database or runs raw SQL.
class FinancialContextService {
  final WalletRepository walletRepo;
  final BeneficiaryRepository beneficiaryRepo;
  final MissionRepository? missionRepo;
  final ActivityRepository? activityRepo;

  // In-memory reserves catalogue (e.g. Tax Reserve, USD Savings, Emergency Fund)
  final List<ReserveAccount> _reserves = [
    ReserveAccount(
      id: 'res_usd_savings_01',
      name: 'USD Savings',
      purpose: 'savings',
      currency: Currency.usd,
      currentBalance: Money.fromMajorString('5200.00', Currency.usd),
      targetWalletId: 'sw_demo_usdb_01',
    ),
    ReserveAccount(
      id: 'res_emergency_02',
      name: 'Emergency Fund',
      purpose: 'emergency',
      currency: Currency.usd,
      currentBalance: Money.fromMajorString('3000.00', Currency.usd),
      targetWalletId: 'sw_demo_usdb_01',
    ),
  ];

  FinancialContextService({
    required this.walletRepo,
    required this.beneficiaryRepo,
    this.missionRepo,
    this.activityRepo,
  });

  /// Retrieve all user smart wallets
  Future<List<WalletAccount>> getWallets() async {
    return await walletRepo.getWallets();
  }

  /// Retrieve wallet matching currency
  Future<WalletAccount?> getWalletForCurrency(Currency currency) async {
    final wallets = await getWallets();
    for (final w in wallets) {
      if (w.currency == currency) return w;
    }
    return wallets.isNotEmpty ? wallets.first : null;
  }

  /// Retrieve all user beneficiaries
  Future<List<Beneficiary>> getBeneficiaries() async {
    return await beneficiaryRepo.getBeneficiaries();
  }

  /// Resolve beneficiary alias or query
  Future<BeneficiaryResolutionResult> resolveBeneficiary(String query) async {
    return await beneficiaryRepo.resolveAlias(query);
  }

  /// Retrieve existing reserves
  Future<List<ReserveAccount>> getReserves() async {
    return List.unmodifiable(_reserves);
  }

  /// Find reserve by name or purpose
  Future<ReserveAccount?> findReserve(String query) async {
    final q = query.trim().toLowerCase();
    for (final r in _reserves) {
      if (r.name.toLowerCase().contains(q) ||
          r.purpose.toLowerCase().contains(q)) {
        return r;
      }
    }
    return null;
  }

  /// Register or track a new reserve destination
  void registerReserve(ReserveAccount reserve) {
    _reserves.add(reserve);
  }

  /// Retrieve active missions
  Future<List<MoneyMissionModel>> getMissions() async {
    if (missionRepo != null) {
      return await missionRepo!.getMissions();
    }
    return const [];
  }

  /// Retrieve recent activity
  Future<List<ActivityModel>> getTransactions() async {
    if (activityRepo != null) {
      return await activityRepo!.getRecentActivities(limit: 10);
    }
    return const [];
  }

  // =========================================================================
  // Deterministic Minor-Unit Arithmetic Tools (No Float Drift)
  // =========================================================================

  /// Calculate percentage of base money using integer minor-unit math
  /// e.g. $2,000.00 * 30% = $600.00
  static Money calculatePercentage(Money base, double percentage) {
    final totalMinor = base.minorUnits;
    final portionMinor = ((totalMinor * percentage) / 100.0).round();
    return Money.fromMinor(portionMinor, base.currency);
  }

  /// Calculate remainder after subtracting specified allocations
  /// e.g. $2,000.00 - ($600.00 + $500.00) = $900.00
  static Money calculateRemainder(Money total, List<Money> deductions) {
    int totalMinor = total.minorUnits;
    for (final d in deductions) {
      totalMinor -= d.minorUnits;
    }
    return Money.fromMinor(totalMinor < 0 ? 0 : totalMinor, total.currency);
  }
}
