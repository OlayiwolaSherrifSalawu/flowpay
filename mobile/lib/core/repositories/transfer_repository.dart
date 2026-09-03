import '../money/money.dart';
import '../safety/operation_preview.dart';

class TransferResult {
  final String proposalId;
  final String status;
  final String? transactionHash;
  final bool isDemo;
  final DateTime timestamp;

  const TransferResult({
    required this.proposalId,
    required this.status,
    this.transactionHash,
    required this.isDemo,
    required this.timestamp,
  });
}

abstract class TransferRepository {
  Future<OperationPreview> previewTransfer({
    required Money amount,
    required String recipient,
    String? note,
  });

  Future<TransferResult> executeTransfer({
    required String previewId,
    required String signature,
  });
}
