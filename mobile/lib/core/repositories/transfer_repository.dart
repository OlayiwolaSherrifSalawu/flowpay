import '../money/money.dart';
import '../safety/operation_preview.dart';
import '../transfers/transfer_funding.dart';
import '../transfers/transfer_intent.dart';
import '../transfers/transfer_models.dart';
import 'wallet_repository.dart';

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
  /// Step 1: Natural Language Intent Interpretation
  Future<TransferIntent> interpretPrompt(String prompt);

  /// Step 2: Balance-Aware Multi-Currency Inspection
  Future<BalanceInspectionResult> inspectBalances({
    required TransferIntent intent,
    required List<WalletAccount> wallets,
  });

  /// Step 3: BMONI Proposal Creation & On-Device Signing Payload
  Future<TransferProposal> createProposal({
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
  });

  /// Step 4: Submit On-Device B-Key Signature & Execute
  Future<TransferExecutionResult> executeProposal({
    required String proposalId,
    required String signature,
    required TransferProposal proposal,
  });

  /// Legacy interface for backwards compatibility
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
