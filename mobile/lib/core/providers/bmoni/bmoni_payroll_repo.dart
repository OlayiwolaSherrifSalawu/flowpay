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
    final res =
        await apiClient.post('/api/payroll/proposals/$proposalId/retry', body: {
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
      destinationStablecoin: itemJson['destinationStablecoin'] ??
          (cur == Currency.ngn ? 'CNGN' : 'MEXe'),
      targetAmount: Money.fromMajorString(
          itemJson['targetAmountFormatted'] ?? '0.00', cur),
      usdAmount: Money.fromMajorString(
          itemJson['usdAmountFormatted'] ?? '0.00', Currency.usd),
      exchangeRate: (itemJson['exchangeRate'] as num?)?.toDouble() ?? 1.0,
      status: itemJson['status'] ?? 'COMPLETED',
      isRailActive: true,
      railValidationMessage:
          itemJson['railValidationMessage'] ?? 'Retried successfully',
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
      final cur = Currency.fromCode(
          i['targetCurrency'] ?? i['target_currency'] ?? 'NGN');
      final stablecoin = i['destinationStablecoin'] ??
          (cur == Currency.ngn
              ? 'CNGN'
              : cur == Currency.mxn
                  ? 'MEXe'
                  : 'USDB');

      final targetAmount = i['targetAmountFormatted'] != null
          ? Money.fromMajorString(i['targetAmountFormatted'].toString(), cur)
          : (i['targetAmountMinor'] != null
              ? Money.fromMinor(i['targetAmountMinor'] as int, cur)
              : (i['target_amount_minor'] != null
                  ? Money.fromMinor(i['target_amount_minor'] as int, cur)
                  : Money.fromMajorString('0.00', cur)));

      final usdAmount = i['usdAmountFormatted'] != null
          ? Money.fromMajorString(
              i['usdAmountFormatted'].toString(), Currency.usd)
          : (i['usdAmountMinor'] != null
              ? Money.fromMinor(i['usdAmountMinor'] as int, Currency.usd)
              : (i['usd_amount_minor'] != null
                  ? Money.fromMinor(i['usd_amount_minor'] as int, Currency.usd)
                  : Money.fromMajorString('0.00', Currency.usd)));

      return PayrollItemModel(
        employeeId: i['employeeId'] ?? i['employee_id'] ?? '',
        employeeName:
            i['name'] ?? i['employeeName'] ?? i['employee_name'] ?? '',
        country: i['country'] ?? 'NG',
        targetCurrency: cur,
        destinationStablecoin: stablecoin,
        targetAmount: targetAmount,
        usdAmount: usdAmount,
        exchangeRate: (i['exchangeRate'] as num?)?.toDouble() ??
            (i['exchange_rate'] as num?)?.toDouble() ??
            1.0,
        status: i['status'] ?? 'COMPLETED',
        isRailActive: i['isRailActive'] ?? true,
        railValidationMessage: i['railValidationMessage'],
        proposalId: i['proposalId'] ?? i['proposal_id'],
        transactionHash: i['transactionHash'],
        errorReason: i['error'] ?? i['errorReason'],
      );
    }).toList();

    final runId = (data['runId'] ?? data['id'] ?? '').toString();
    final totalUsd = data['totalUsdFormatted'] != null
        ? Money.fromMajorString(
            data['totalUsdFormatted'].toString(), Currency.usd)
        : (data['totalUsdMinor'] != null
            ? Money.fromMinor(data['totalUsdMinor'] as int, Currency.usd)
            : (data['total_usd_minor'] != null
                ? Money.fromMinor(data['total_usd_minor'] as int, Currency.usd)
                : Money.fromMajorString('0.00', Currency.usd)));

    final totalFeeUsd = data['totalFeeUsdFormatted'] != null
        ? Money.fromMajorString(
            data['totalFeeUsdFormatted'].toString(), Currency.usd)
        : (data['feeUsdMinor'] != null
            ? Money.fromMinor(data['feeUsdMinor'] as int, Currency.usd)
            : (data['fee_usd_minor'] != null
                ? Money.fromMinor(data['fee_usd_minor'] as int, Currency.usd)
                : Money.fromMajorString('10.00', Currency.usd)));

    final savedUsd = data['totalSavedUsdFormatted'] != null
        ? Money.fromMajorString(
            data['totalSavedUsdFormatted'].toString(), Currency.usd)
        : Money.fromMajorString('330.00', Currency.usd);

    final countries = data['countries'] != null
        ? List<String>.from(data['countries'])
        : (mappedItems.isNotEmpty
            ? mappedItems.map((i) => i.country).toSet().toList()
            : ['NG', 'MX']);

    final currencies = data['currencies'] != null
        ? List<String>.from(data['currencies'])
        : (mappedItems.isNotEmpty
            ? mappedItems.map((i) => i.targetCurrency.code).toSet().toList()
            : ['NGN', 'MXN']);

    return PayrollRunModel(
      runId: runId,
      title: (data['title'] ?? 'Global Payroll Fan-Out').toString(),
      totalUsd: totalUsd,
      totalFeeUsd: totalFeeUsd,
      totalSavedFeeUsd: savedUsd,
      savedPercentage: (data['savedPercentage'] as num?)?.toDouble() ?? 97.0,
      employerBalanceUsd: Money.fromMajorString(
          data['employerBalanceUsdFormatted'] ?? '24500.00', Currency.usd),
      isBalanceSufficient: data['isBalanceSufficient'] ?? true,
      employeeCount: data['employeeCount'] ??
          (mappedItems.isNotEmpty ? mappedItems.length : 2),
      countries: countries,
      currencies: currencies,
      items: mappedItems,
      status: (data['status'] ?? 'COMPLETED').toString(),
      executedAt: DateTime.tryParse(data['executedAt']?.toString() ??
              data['executed_at']?.toString() ??
              data['createdAt']?.toString() ??
              '') ??
          DateTime.now(),
      isDemo: isDemo,
    );
  }
}
