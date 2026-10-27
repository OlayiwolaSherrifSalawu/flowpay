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

  // ── Payday guarantee (Soroban) ──

  Map<String, dynamic> _map(dynamic res) => Map<String, dynamic>.from(res as Map);

  @override
  Future<PayrollGuaranteeProposal> proposeGuarantee(DateTime unlockAt) async => PayrollGuaranteeProposal.fromJson(
      _map(await apiClient.post('/api/payroll/guarantees/propose', body: {'unlockAt': unlockAt.toUtc().toIso8601String()})));

  @override
  Future<PayrollGuaranteeModel> executeGuarantee({required String proposalId, String? signedPayload}) async {
    if (signedPayload == null) throw StateError('A signed transaction is required.');
    return PayrollGuaranteeModel.fromJson(
        _map(await apiClient.post('/api/payroll/guarantees/execute', body: {'proposalId': proposalId, 'signedXdr': signedPayload})));
  }

  @override
  Future<List<PayrollGuaranteeModel>> getGuarantees() async {
    final res = await apiClient.get('/api/payroll/guarantees');
    return [for (final g in res as List) PayrollGuaranteeModel.fromJson(_map(g))];
  }

  @override
  Future<List<GuaranteePayoutResult>> releaseGuarantee(int payrollId) async {
    final res = _map(await apiClient.post('/api/payroll/guarantees/$payrollId/release', body: {}));
    return [for (final r in (res['results'] as List? ?? const [])) GuaranteePayoutResult.fromJson(_map(r))];
  }

  @override
  Future<List<GuaranteedPayModel>> getMyGuaranteedPay() async {
    final res = await apiClient.get('/api/payroll/guarantees/mine');
    return [for (final g in res as List) GuaranteedPayModel.fromJson(_map(g))];
  }

  @override
  Future<({String proposalId, String? signPayload})> proposeGuaranteeClaim(int payrollId) async {
    final res = _map(await apiClient.post('/api/payroll/guarantees/$payrollId/claim', body: {}));
    return (proposalId: res['proposalId'].toString(), signPayload: res['signPayload'] as String?);
  }

  @override
  Future<GuaranteePayoutResult> executeGuaranteeClaim({required String proposalId, String? signedPayload}) async {
    if (signedPayload == null) throw StateError('A signed transaction is required.');
    final res = _map(await apiClient.post('/api/payroll/guarantees/claim/execute', body: {'proposalId': proposalId, 'signedXdr': signedPayload}));
    return GuaranteePayoutResult(name: 'You', status: res['status']?.toString() ?? 'FAILED', amountUsd: res['amountUsd']?.toString(), explorerUrl: res['explorerUrl']?.toString());
  }
}
