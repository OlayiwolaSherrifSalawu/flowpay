import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/transfer_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../safety/operation_preview.dart';
import '../../stellar/stellar_key_vault.dart';
import '../../transfers/transfer_funding.dart';
import '../../transfers/transfer_intent.dart';
import '../../transfers/transfer_models.dart';

/// Live transfers on Stellar.
///
///   interpret → inspect (real balances + live path quotes) → propose (unsigned XDR)
///   → device signs the XDR → execute (submit) → COMPLETED | PENDING | throws
///
/// There is no offline fallback for anything that moves or quotes money.
class StellarTransferRepository implements TransferRepository {
  final FlowPayApiClient apiClient;

  StellarTransferRepository({required this.apiClient});

  Future<String> _accountId() async {
    final id = await StellarKeyVault.instance.publicKey();
    if (id == null) {
      throw const StellarVaultException(StellarVaultErrorCode.noWallet, 'Set up your wallet before sending money.');
    }
    return id;
  }

  @override
  Future<TransferIntent> interpretPrompt(String prompt) async {
    final res = await apiClient.post('/api/transfers/interpret', body: {'prompt': prompt});
    final intentJson = (res is Map && res['intent'] is Map) ? res['intent'] : res;
    return TransferIntent.fromJson(Map<String, dynamic>.from(intentJson as Map));
  }

  @override
  Future<BalanceInspectionResult> inspectBalances({
    required TransferIntent intent,
    required List<WalletAccount> wallets,
  }) async {
    // Balances are read on-chain by the backend; the passed list is display-only.
    final res = await apiClient.post('/api/transfers/inspect-balances', body: {
      'userId': apiClient.userId,
      'accountId': await _accountId(),
      'intent': intent.toJson(),
    });
    return BalanceInspectionResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<TransferProposal> createProposal({
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
  }) async {
    final res = await apiClient.post('/api/transfers/propose', body: {
      'userId': apiClient.userId,
      'accountId': await _accountId(),
      'intent': intent.toJson(),
      'fundingOption': fundingOption.toJson(),
    });
    final proposal = TransferProposal.fromJson(Map<String, dynamic>.from(res as Map));
    if (proposal.signPayload.isEmpty || proposal.proposalId.isEmpty) {
      throw StateError('The server returned an incomplete transfer proposal.');
    }
    return proposal;
  }

  /// [signature] is the device-signed transaction envelope (base64 XDR).
  @override
  Future<TransferExecutionResult> executeProposal({
    required String proposalId,
    required String signature,
    required TransferProposal proposal,
  }) async {
    final res = await apiClient.post('/api/transfers/execute', body: {
      'userId': apiClient.userId,
      'proposalId': proposalId,
      'signedXdr': signature,
    });
    final data = Map<String, dynamic>.from(res as Map);
    final result = TransferExecutionResult.fromJson(data);
    if (!result.isCompleted && !result.isPending) {
      throw StateError('Transfer status is unknown (${result.status}). Check your activity before retrying.');
    }
    return result;
  }

  @override
  Future<OperationPreview> previewTransfer({required Money amount, required String recipient, String? note}) {
    throw UnsupportedError('Use inspectBalances/createProposal for Stellar transfers.');
  }

  @override
  Future<TransferResult> executeTransfer({required String previewId, required String signature}) {
    throw UnsupportedError('Use executeProposal for Stellar transfers.');
  }
}
