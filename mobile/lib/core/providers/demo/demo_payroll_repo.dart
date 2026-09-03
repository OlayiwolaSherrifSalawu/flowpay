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
    await Future.delayed(const Duration(milliseconds: 500));
    final preview = DemoData.getPayrollPreview();

    final executedItems = preview.items.map((i) {
      return PayrollItemModel(
        employeeId: i.employeeId,
        employeeName: i.employeeName,
        country: i.country,
        targetCurrency: i.targetCurrency,
        targetAmount: i.targetAmount,
        usdAmount: i.usdAmount,
        exchangeRate: i.exchangeRate,
        status: 'SUCCESS',
        proposalId: 'prop_demo_${i.country.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        transactionHash: '0x7e81...demo_payroll_fanout_receipt',
      );
    }).toList();

    final completedRun = PayrollRunModel(
      runId: 'run_demo_${DateTime.now().millisecondsSinceEpoch}',
      title: preview.title,
      totalUsd: preview.totalUsd,
      totalFeeUsd: preview.totalFeeUsd,
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
