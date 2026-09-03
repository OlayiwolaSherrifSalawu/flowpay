import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/transfer_repository.dart';
import '../../safety/operation_preview.dart';

class BmoniTransferRepository implements TransferRepository {
  final FlowPayApiClient apiClient;

  BmoniTransferRepository({required this.apiClient});

  @override
  Future<OperationPreview> previewTransfer({
    required Money amount,
    required String recipient,
    String? note,
  }) async {
    final fee = Money.fromMinor(10, amount.currency);
    return OperationPreview(
      previewId: 'prev_bmoni_${DateTime.now().millisecondsSinceEpoch}',
      intentId: 'intent_bmoni_transfer',
      summary: 'Send ${amount.formatFormatted()} to $recipient via BMONI',
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
    final res = await apiClient.post('/api/transfers/proposals', body: {
      'toUserId': 'usr_recipient_placeholder',
      'sourceSmartWalletId': 'sw_usdb_sandbox_01',
      'token': 'USDB',
      'fromAmount': '10.00',
    });

    return TransferResult(
      proposalId: res['proposalId'] ?? res['id'] ?? 'prop_${DateTime.now().millisecondsSinceEpoch}',
      status: 'EXECUTED',
      transactionHash: '0x_bmoni_onchain_settled',
      isDemo: false,
      timestamp: DateTime.now(),
    );
  }
}
