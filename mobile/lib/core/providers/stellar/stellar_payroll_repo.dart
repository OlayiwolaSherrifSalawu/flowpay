import '../../network/api_client.dart';
import '../../repositories/payroll_repository.dart';

/// Live payroll: the preview carries the real Stellar transactions (≤100 employees
/// each, atomic) for the employer to sign; execution submits them. Errors propagate.
class StellarPayrollRepository implements PayrollRepository {
  final FlowPayApiClient apiClient;

  StellarPayrollRepository({required this.apiClient});

  Map<String, String> get _identity => {'x-user-id': apiClient.userId};

  @override
  Future<PayrollRunModel> getPayrollPreview() async =>
      PayrollRunModel.fromJson(Map<String, dynamic>.from(await apiClient.get('/api/payroll/preview', headers: _identity) as Map));

  @override
  Future<PayrollRunModel> executePayrollRun({required String runId, required Map<String, String> signedBatches}) async {
    final res = await apiClient.post('/api/payroll/execute', headers: _identity, body: {'runId': runId, 'signed': signedBatches});
    return PayrollRunModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<PayrollRunModel>> getPastRuns() async {
    final res = await apiClient.get('/api/payroll/runs', headers: _identity);
    final list = res is Map && res['items'] is List ? res['items'] as List : (res as List);
    return [for (final r in list) PayrollRunModel.fromJson(Map<String, dynamic>.from(r as Map))];
  }
}
