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
          destinationStablecoin: 'CNGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'CNGN Settled on BMONI Rails via Providus VBA',
          proposalId: 'prop_demo_ng_9941',
          transactionHash: '0x8f2d...cngn_settled_fanout',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MEXe',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'MEXe Settled on BMONI Rails via STP CLABE',
          proposalId: 'prop_demo_mx_9942',
          transactionHash: '0x9b10...mexe_settled_fanout',
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
          destinationStablecoin: 'CNGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'CNGN Settled on BMONI Rails',
          proposalId: 'prop_demo_ng_8812',
          transactionHash: '0x8f2d...cngn_settled_mid',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MEXe',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'FAILED',
          isRailActive: false,
          railValidationMessage: 'Rail activation required',
          proposalId: 'prop_demo_mx_failed_8813',
          errorReason: 'Destination MEXe smart-wallet unactivated (requires Etherfuse agreement)',
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
          destinationStablecoin: 'CNGN',
          targetAmount: Money.fromMajorString('3100000.00', Currency.ngn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 1550.0,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'CNGN Settled on BMONI Rails',
          proposalId: 'prop_demo_ng_7701',
          transactionHash: '0x8f2d...cngn_aug_receipt',
        ),
        PayrollItemModel(
          employeeId: 'emp_samson_jabo',
          employeeName: 'Samson Jabo',
          country: 'MX',
          targetCurrency: Currency.mxn,
          destinationStablecoin: 'MEXe',
          targetAmount: Money.fromMajorString('35000.00', Currency.mxn),
          usdAmount: Money.fromMajorString('2000.00', Currency.usd),
          exchangeRate: 17.5,
          status: 'COMPLETED',
          isRailActive: true,
          railValidationMessage: 'MEXe Settled on BMONI Rails',
          proposalId: 'prop_demo_mx_7702',
          transactionHash: '0x9b10...mexe_aug_receipt',
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
    required String signature,
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
        railValidationMessage: '${i.destinationStablecoin} Settled on BMONI Rails',
        proposalId: 'prop_demo_${i.country.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        transactionHash: '0x7e81...demo_${i.destinationStablecoin.toLowerCase()}_fanout_receipt',
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
  Future<PayrollItemModel> retryFailedProposal({
    required String proposalId,
    required String employeeId,
    required String pin,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Per BMONI docs: Calling approve again restarts the workflow for this single proposal
    return PayrollItemModel(
      employeeId: employeeId,
      employeeName: 'Retried Employee',
      country: 'NG',
      targetCurrency: demoCurrencyForId(employeeId),
      destinationStablecoin: demoStablecoinForId(employeeId),
      targetAmount: DemoData.getPayrollPreview().items.firstWhere((i) => i.employeeId == employeeId).targetAmount,
      usdAmount: DemoData.getPayrollPreview().items.firstWhere((i) => i.employeeId == employeeId).usdAmount,
      exchangeRate: DemoData.getPayrollPreview().items.firstWhere((i) => i.employeeId == employeeId).exchangeRate,
      status: 'COMPLETED',
      isRailActive: true,
      railValidationMessage: 'Successfully Retried & Settled on BMONI Rails',
      proposalId: proposalId,
      transactionHash: '0x7e81...retry_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  dynamic demoCurrencyForId(String employeeId) {
    final match = DemoData.getPayrollPreview().items.where((i) => i.employeeId == employeeId);
    return match.isNotEmpty ? match.first.targetCurrency : DemoData.getPayrollPreview().items.first.targetCurrency;
  }

  String demoStablecoinForId(String employeeId) {
    final match = DemoData.getPayrollPreview().items.where((i) => i.employeeId == employeeId);
    return match.isNotEmpty ? match.first.destinationStablecoin : 'CNGN';
  }

  @override
  Future<List<PayrollRunModel>> getPastRuns() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _runs;
  }
}
