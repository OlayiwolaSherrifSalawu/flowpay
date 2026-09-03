import '../../network/api_client.dart';
import '../../repositories/approval_repository.dart';

class BmoniApprovalRepository implements ApprovalRepository {
  final FlowPayApiClient apiClient;

  BmoniApprovalRepository({required this.apiClient});

  @override
  Future<List<PendingApprovalModel>> getPendingApprovals() async {
    // In live BMONI, pending approvals are gathered from active proposals
    return [];
  }

  @override
  Future<bool> approveAction(String approvalId, {String? pin}) async {
    return true;
  }

  @override
  Future<bool> rejectAction(String approvalId, {String? reason}) async {
    return true;
  }
}
