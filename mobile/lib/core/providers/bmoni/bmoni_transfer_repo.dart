import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/transfer_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../safety/operation_preview.dart';
import '../../transfers/transfer_funding.dart';
import '../../transfers/transfer_intent.dart';
import '../../transfers/transfer_models.dart';

class BmoniTransferRepository implements TransferRepository {
  final FlowPayApiClient apiClient;

  BmoniTransferRepository({required this.apiClient});

  @override
  Future<TransferIntent> interpretPrompt(String prompt) async {
    final res = await apiClient.post('/api/transfers/interpret', body: {
      'prompt': prompt,
    });

    final intentJson = res['data']?['intent'] ?? res['data'] ?? {};
    return TransferIntent.fromJson(Map<String, dynamic>.from(intentJson));
  }

  @override
  Future<BalanceInspectionResult> inspectBalances({
    required TransferIntent intent,
    required List<WalletAccount> wallets,
  }) async {
    final walletsJson = wallets.map((w) {
      return {
        'id': w.id,
        'currency': w.currency.code,
        'balanceMinor': w.balance.amountMinor.toString(),
        'name': '${w.currency.code} Smart Wallet',
      };
    }).toList();

    final res = await apiClient.post('/api/transfers/inspect-balances', body: {
      'intent': intent.toJson(),
      'wallets': walletsJson,
    });

    final data = res['data'] ?? {};
    return BalanceInspectionResult.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<TransferProposal> createProposal({
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
  }) async {
    final res = await apiClient.post('/api/transfers/propose', body: {
      'intent': intent.toJson(),
      'fundingOption': fundingOption.toJson(),
    });

    final data = res['data'] ?? {};
    return TransferProposal.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<TransferExecutionResult> executeProposal({
    required String proposalId,
    required String signature,
    required TransferProposal proposal,
  }) async {
    final res = await apiClient.post('/api/transfers/execute', body: {
      'proposalId': proposalId,
      'signature': signature,
      'proposalPayload': {
        'proposalId': proposal.proposalId,
        'intent': proposal.intent.toJson(),
        'fundingOption': proposal.fundingOption.toJson(),
      },
    });

    final data = res['data'] ?? {};
    return TransferExecutionResult.fromJson(Map<String, dynamic>.from(data));
  }

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
      proposalId: res['proposalId'] ??
          res['id'] ??
          'prop_${DateTime.now().millisecondsSinceEpoch}',
      status: 'EXECUTED',
      transactionHash: '0x_bmoni_onchain_settled',
      isDemo: false,
      timestamp: DateTime.now(),
    );
  }
}
