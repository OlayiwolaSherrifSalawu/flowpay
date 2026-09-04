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
  Future<PayrollItemModel> retryFailedProposal({
    required String proposalId,
    required String employeeId,
    required String pin,
  }) async {
    final res = await apiClient.post('/api/payroll/proposals/$proposalId/retry', body: {
      'employeeId': employeeId,
      'pin': pin,
    });
    final itemJson = res['item'] ?? res;
    final cur = Currency.fromCode(itemJson['targetCurrency'] ?? 'NGN');
    return PayrollItemModel(
      employeeId: itemJson['employeeId'] ?? employeeId,
      employeeName: itemJson['name'] ?? itemJson['employeeName'] ?? 'Employee',
      country: itemJson['country'] ?? 'NG',
      targetCurrency: cur,
      destinationStablecoin: itemJson['destinationStablecoin'] ?? (cur == Currency.ngn ? 'CNGN' : 'MEXe'),
      targetAmount: Money.fromMajorString(itemJson['targetAmountFormatted'] ?? '0.00', cur),
      usdAmount: Money.fromMajorString(itemJson['usdAmountFormatted'] ?? '0.00', Currency.usd),
      exchangeRate: (itemJson['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      status: itemJson['status'] ?? 'COMPLETED',
      isRailActive: true,
      railValidationMessage: itemJson['railValidationMessage'] ?? 'Retried successfully',
      proposalId: itemJson['proposalId'] ?? proposalId,
      transactionHash: itemJson['transactionHash'],
    );
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
    final data = json['data'] ?? json;
    final itemsList = (data['items'] as List?) ?? [];
    final mappedItems = itemsList.map((i) {
      final cur = Currency.fromCode(i['targetCurrency'] ?? 'NGN');
      final stablecoin = i['destinationStablecoin'] ?? (cur == Currency.ngn ? 'CNGN' : cur == Currency.mxn ? 'MEXe' : 'USDB');
      return PayrollItemModel(
        employeeId: i['employeeId'] ?? '',
        employeeName: i['name'] ?? i['employeeName'] ?? '',
        country: i['country'] ?? 'NG',
        targetCurrency: cur,
        destinationStablecoin: stablecoin,
        targetAmount: Money.fromMajorString(i['targetAmountFormatted'] ?? '0.00', cur),
        usdAmount: Money.fromMajorString(i['usdAmountFormatted'] ?? '0.00', Currency.usd),
        exchangeRate: (i['exchangeRate'] as num?)?.toDouble() ?? 1.0,
        status: i['status'] ?? 'SUCCESS',
        isRailActive: i['isRailActive'] ?? true,
        railValidationMessage: i['railValidationMessage'],
        proposalId: i['proposalId'],
        transactionHash: i['transactionHash'],
        errorReason: i['error'],
      );
    }).toList();

    return PayrollRunModel(
      runId: data['runId'] ?? '',
      title: data['title'] ?? 'Global Payroll Run',
      totalUsd: Money.fromMajorString(data['totalUsdFormatted'] ?? '0.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString(data['totalFeeUsdFormatted'] ?? '0.00', Currency.usd),
      totalSavedFeeUsd: Money.fromMajorString(data['totalSavedUsdFormatted'] ?? '0.00', Currency.usd),
      savedPercentage: (data['savedPercentage'] as num?)?.toDouble() ?? 97.0,
      employerBalanceUsd: Money.fromMajorString(data['employerBalanceUsdFormatted'] ?? '24500.00', Currency.usd),
      isBalanceSufficient: data['isBalanceSufficient'] ?? true,
      employeeCount: data['employeeCount'] ?? mappedItems.length,
      countries: List<String>.from(data['countries'] ?? ['NG', 'MX']),
      currencies: List<String>.from(data['currencies'] ?? ['NGN', 'MXN']),
      items: mappedItems,
      status: data['status'] ?? 'COMPLETED',
      executedAt: DateTime.tryParse(data['executedAt'] ?? '') ?? DateTime.now(),
      isDemo: isDemo,
    );
  }
}
