import '../money/currency.dart';
import '../money/money.dart';

class PayrollItemModel {
  final String employeeId;
  final String employeeName;
  final String country;
  final Currency targetCurrency;
  final Money targetAmount;
  final Money usdAmount;
  final double exchangeRate;
  final String status;
  final String? proposalId;
  final String? transactionHash;

  const PayrollItemModel({
    required this.employeeId,
    required this.employeeName,
    required this.country,
    required this.targetCurrency,
    required this.targetAmount,
    required this.usdAmount,
    required this.exchangeRate,
    required this.status,
    this.proposalId,
    this.transactionHash,
  });
}

class PayrollRunModel {
  final String runId;
  final String title;
  final Money totalUsd;
  final Money totalFeeUsd;
  final int employeeCount;
  final List<String> countries;
  final List<String> currencies;
  final List<PayrollItemModel> items;
  final String status;
  final DateTime executedAt;
  final bool isDemo;

  const PayrollRunModel({
    required this.runId,
    required this.title,
    required this.totalUsd,
    required this.totalFeeUsd,
    required this.employeeCount,
    required this.countries,
    required this.currencies,
    required this.items,
    required this.status,
    required this.executedAt,
    required this.isDemo,
  });
}

abstract class PayrollRepository {
  Future<PayrollRunModel> getPayrollPreview();
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required String signature,
  });
  Future<List<PayrollRunModel>> getPastRuns();
}
