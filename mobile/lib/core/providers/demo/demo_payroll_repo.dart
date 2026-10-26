import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/payroll_repository.dart';
import 'demo_data.dart';

class DemoPayrollRepository implements PayrollRepository {
  final List<PayrollRunModel> _runs = [
    PayrollRunModel(
      runId: 'run_sep_2026_01',
      title: 'September 2026 Global Payroll Fan-Out',
      totalUsd: Money.fromMajorString('4000.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString('10.00', Currency.usd),
      totalSavedFeeUsd: Money.fromMajorString('330.00', Currency.usd),
      savedPercentage: 97.0,
      employerBalanceUsd: Money.fromMajorString('20500.00', Currency.usd),
      isBalanceSufficient: true,
      employeeCount: 2,
      countries: const ['NG', 'MX'],
      currencies: const ['NGN', 'MXN'],
      status: 'COMPLETED',
      executedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      isDemo: true,
      items: [
        PayrollItemModel(
          employeeId: 'emp_bunch_dillon',
          employeeName: 'Bunch Dillon',
          country: 'NG',
          targetCurrency: Currency.ngn,
          destinationStablecoin: 'NGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'NGN Settled on Stellar via Providus VBA',
          proposalId: 'prop_demo_ng_9941',
          transactionHash: '3912ff23350f9ac7a4018ced4faccbd633958e023f72cd9d634f8823ef26dfeb',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MXN',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'MXN Settled on Stellar via STP CLABE',
          proposalId: 'prop_demo_mx_9942',
          transactionHash: 'c05f99ff1aa97483203c3b6641b2f714a3e1a5876a1527e02f68c1f8f02f4e21',
        ),
      ],
    ),
    PayrollRunModel(
      runId: 'run_aug_2026_mid',
      title: 'August 2026 Mid-Cycle Contractor Run',
      totalUsd: Money.fromMajorString('4000.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString('10.00', Currency.usd),
      totalSavedFeeUsd: Money.fromMajorString('330.00', Currency.usd),
      savedPercentage: 97.0,
      employerBalanceUsd: Money.fromMajorString('24500.00', Currency.usd),
      isBalanceSufficient: true,
      employeeCount: 2,
      countries: const ['NG', 'MX'],
      currencies: const ['NGN', 'MXN'],
      status: 'PARTIALLY_COMPLETED',
      executedAt: DateTime.now().subtract(const Duration(days: 14, hours: 3)),
      isDemo: true,
      items: [
        PayrollItemModel(
          employeeId: 'emp_bunch_dillon',
          employeeName: 'Bunch Dillon',
          country: 'NG',
          targetCurrency: Currency.ngn,
          destinationStablecoin: 'NGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'NGN Settled on Stellar',
          proposalId: 'prop_demo_ng_8812',
          transactionHash: '119de3d94375b8829889064c9e2655c8802aa3ecd4e6b759847bfbe47ddbb4e8',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MXN',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'FAILED',
          isRailActive: false,
          railValidationMessage: 'Rail activation required',
          proposalId: 'prop_demo_mx_failed_8813',
          errorReason: 'Destination MXN smart-wallet unactivated (requires Etherfuse agreement)',
        ),
      ],
    ),
    PayrollRunModel(
      runId: 'run_aug_2026_end',
      title: 'August 2026 Monthly Global Payroll',
      totalUsd: Money.fromMajorString('4000.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString('10.00', Currency.usd),
      totalSavedFeeUsd: Money.fromMajorString('330.00', Currency.usd),
      savedPercentage: 97.0,
      employerBalanceUsd: Money.fromMajorString('28500.00', Currency.usd),
      isBalanceSufficient: true,
      employeeCount: 2,
      countries: const ['NG', 'MX'],
      currencies: const ['NGN', 'MXN'],
      status: 'COMPLETED',
      executedAt: DateTime.now().subtract(const Duration(days: 29)),
      isDemo: true,
      items: [
        PayrollItemModel(
          employeeId: 'emp_bunch_dillon',
          employeeName: 'Bunch Dillon',
          country: 'NG',
          targetCurrency: Currency.ngn,
          destinationStablecoin: 'NGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'NGN Settled on Stellar',
          proposalId: 'prop_demo_ng_7701',
          transactionHash: '35811808802eb94098aed3ebccff2b7e1b3d6d29346b5a6954372b87d2767874',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MXN',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'MXN Settled on Stellar',
          proposalId: 'prop_demo_mx_7702',
          transactionHash: '0100d5d98db66c0a21e105e775bc34c1c7f93b0ab4e836982920b87ada7339ed',
        ),
      ],
    ),
  ];

  @override
  Future<PayrollRunModel> getPayrollPreview() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return DemoData.getPayrollPreview();
  }

  @override
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required Map<String, String> signedBatches,
  }) async {
    // Deterministic simulation matching demo-mode spec:
    // Fast, reliable, no external sandbox dependency
    await Future.delayed(const Duration(milliseconds: 600));
    final preview = DemoData.getPayrollPreview();

    final executedItems = preview.items.map((i) {
      return PayrollItemModel(
        employeeId: i.employeeId,
        employeeName: i.employeeName,
        country: i.country,
        targetCurrency: i.targetCurrency,
        destinationStablecoin: i.destinationStablecoin,
        targetAmount: i.targetAmount,
        usdAmount: i.usdAmount,
        exchangeRate: i.exchangeRate,
        status: 'COMPLETED',
        isRailActive: true,
        railValidationMessage: 'Demo simulation — no real money moved',
        proposalId: 'prop_demo_${i.country.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        transactionHash: 'demo_tx_${i.employeeId}',
      );
    }).toList();

    final completedRun = PayrollRunModel(
      runId: 'run_demo_${DateTime.now().millisecondsSinceEpoch}',
      title: preview.title,
      totalUsd: preview.totalUsd,
      totalFeeUsd: preview.totalFeeUsd,
      totalSavedFeeUsd: preview.totalSavedFeeUsd,
      savedPercentage: preview.savedPercentage,
      employerBalanceUsd: preview.employerBalanceUsd,
      isBalanceSufficient: preview.isBalanceSufficient,
      employeeCount: preview.employeeCount,
      countries: preview.countries,
      currencies: preview.currencies,
      items: executedItems,
      status: 'COMPLETED',
      executedAt: DateTime.now(),
      isDemo: true,
    );

    _runs.insert(0, completedRun);
    return completedRun;
  }

  @override
  Future<List<PayrollRunModel>> getPastRuns() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _runs;
  }
}
