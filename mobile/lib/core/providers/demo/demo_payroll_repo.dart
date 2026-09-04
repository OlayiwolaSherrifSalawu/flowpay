import '../../repositories/payroll_repository.dart';
import 'demo_data.dart';

class DemoPayrollRepository implements PayrollRepository {
  final List<PayrollRunModel> _runs = [];

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
