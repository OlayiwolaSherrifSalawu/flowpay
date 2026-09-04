import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/payroll_repository.dart';

class BmoniPayrollRepository implements PayrollRepository {
  final FlowPayApiClient apiClient;

  BmoniPayrollRepository({required this.apiClient});

  @override
  Future<PayrollRunModel> getPayrollPreview() async {
    final res = await apiClient.get('/api/payroll/preview');
    return _mapRunModel(res, isDemo: false);
  }

  @override
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required String signature,
  }) async {
    final res = await apiClient.post('/api/payroll/execute', body: {
      'runId': runId,
      'signature': signature,
    });
    return _mapRunModel(res, isDemo: false);
  }

  @override
  Future<List<PayrollRunModel>> getPastRuns() async {
    final res = await apiClient.get('/api/payroll/runs');
    if (res is List) {
      return res.map((r) => _mapRunModel(r, isDemo: false)).toList();
    }
    return [];
  }

  PayrollRunModel _mapRunModel(dynamic json, {required bool isDemo}) {
    final itemsList = (json['items'] as List?) ?? [];
    final mappedItems = itemsList.map((i) {
      final cur = Currency.fromCode(i['targetCurrency'] ?? 'NGN');
      return PayrollItemModel(
        employeeId: i['employeeId'] ?? '',
        employeeName: i['name'] ?? '',
        country: i['country'] ?? 'NG',
        targetCurrency: cur,
        targetAmount:
            Money.fromMajorString(i['targetAmountFormatted'] ?? '0.00', cur),
        usdAmount: Money.fromMajorString(
            i['usdAmountFormatted'] ?? '0.00', Currency.usd),
        exchangeRate: (i['exchangeRate'] as num?)?.toDouble() ?? 1.0,
        status: i['status'] ?? 'SUCCESS',
        proposalId: i['proposalId'],
        transactionHash: i['transactionHash'],
      );
    }).toList();

    return PayrollRunModel(
      runId: json['runId'] ?? '',
      title: json['title'] ?? 'Global Payroll Run',
      totalUsd: Money.fromMajorString(
          json['totalUsdFormatted'] ?? '0.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString(
          json['totalFeeUsdFormatted'] ?? '0.00', Currency.usd),
      employeeCount: json['employeeCount'] ?? mappedItems.length,
      countries: List<String>.from(json['countries'] ?? ['NG', 'MX']),
      currencies: List<String>.from(json['currencies'] ?? ['NGN', 'MXN']),
      items: mappedItems,
      status: json['status'] ?? 'COMPLETED',
      executedAt: DateTime.tryParse(json['executedAt'] ?? '') ?? DateTime.now(),
      isDemo: isDemo,
    );
  }
}
