import '../../network/api_client.dart';
import '../../repositories/approval_repository.dart';

class LiveApprovalRepository implements ApprovalRepository {
  final FlowPayApiClient apiClient;

  LiveApprovalRepository({required this.apiClient});

  @override
  Future<List<PendingApprovalModel>> getPendingApprovals() async {
    return [];
  }

  // On Stellar every money movement is approved by signing its transaction, so
  // there is no separate approval queue. Refuse instead of reporting success.
  @override
  Future<bool> approveAction(String approvalId, {String? pin}) async {
    throw UnsupportedError('There is no approval queue on Stellar; payments are approved by signing them.');
  }

  @override
  Future<bool> rejectAction(String approvalId, {String? reason}) async {
    throw UnsupportedError('There is no approval queue on Stellar; payments are approved by signing them.');
  }
}
