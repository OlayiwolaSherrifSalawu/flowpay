import '../../money/money.dart';
import '../../repositories/transfer_repository.dart';
import '../../safety/operation_preview.dart';

class DemoTransferRepository implements TransferRepository {
  @override
  Future<OperationPreview> previewTransfer({
    required Money amount,
    required String recipient,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final fee = Money.fromMinor(10, amount.currency);
    return OperationPreview(
      previewId: 'prev_demo_${DateTime.now().millisecondsSinceEpoch}',
      intentId: 'intent_demo_transfer',
      summary: 'Send ${amount.formatFormatted()} to $recipient',
      sourceAmount: amount,
      estimatedFee: fee,
      totalAmount: amount.add(fee),
      recipient: recipient,
      requiresOnDeviceSigning: true,
      warnings: const [],
    );
  }

  @override
  Future<TransferResult> executeTransfer({
    required String previewId,
    required String signature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return TransferResult(
      proposalId: 'prop_demo_${DateTime.now().millisecondsSinceEpoch}',
      status: 'EXECUTED',
      transactionHash: '0x3a92b...demo_tx_hash_deterministic',
      isDemo: true,
      timestamp: DateTime.now(),
    );
  }
}
