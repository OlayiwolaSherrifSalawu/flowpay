import 'transfer_funding.dart';
import 'transfer_intent.dart';

enum TransferErrorCode {
  insufficientFunds,
  unsupportedCurrency,
  invalidRecipient,
  conversionUnavailable,
  transferFailure,
  signatureFailure,
  proposalExpiration,
  networkFailure;

  String get humanReadableMessage {
    switch (this) {
      case TransferErrorCode.insufficientFunds:
        return 'Insufficient funds across all available wallets. Please fund your smart wallet or choose another currency rail.';
      case TransferErrorCode.unsupportedCurrency:
        return 'The selected currency is unsupported. FlowPay currently supports USD, NGN, MXN, CAD, and EUR.';
      case TransferErrorCode.invalidRecipient:
        return 'Invalid recipient. Please specify a valid beneficiary name, email address, or 0x Ethereum address.';
      case TransferErrorCode.conversionUnavailable:
        return 'Currency conversion between the requested pairs is currently unavailable.';
      case TransferErrorCode.transferFailure:
        return 'Transfer failed to settle on BMONI rails. Please verify recipient details and try again.';
      case TransferErrorCode.signatureFailure:
        return 'B-Key PIN verification failed or was cancelled. Transaction was not authorized.';
      case TransferErrorCode.proposalExpiration:
        return 'Transfer proposal expired (15-minute validity). Exchange rates have been refreshed; please review and confirm again.';
      case TransferErrorCode.networkFailure:
        return 'Network connection error. Unable to communicate with FlowPay backend or BMONI infrastructure.';
    }
  }
}

class TransferProposal {
  final String proposalId;
  final String status;
  final String hashToSign;
  final String signPayload;
  final DateTime expiresAt;
  final TransferFundingOption fundingOption;
  final TransferIntent intent;

  const TransferProposal({
    required this.proposalId,
    required this.status,
    required this.hashToSign,
    required this.signPayload,
    required this.expiresAt,
    required this.fundingOption,
    required this.intent,
  });

  factory TransferProposal.fromJson(Map<String, dynamic> json) {
    return TransferProposal(
      proposalId: json['proposalId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING_SIGNATURES',
      hashToSign: json['hashToSign']?.toString() ?? '',
      signPayload: json['signPayload']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
      fundingOption: TransferFundingOption.fromJson(
        Map<String, dynamic>.from(json['fundingOption'] ?? {}),
      ),
      intent: TransferIntent.fromJson(
        Map<String, dynamic>.from(json['intent'] ?? {}),
      ),
    );
  }
}

class TransferExecutionResult {
  final String proposalId;
  final String status;
  final String transactionHash;
  final DateTime timestamp;
  final String? auditActivityId;

  const TransferExecutionResult({
    required this.proposalId,
    required this.status,
    required this.transactionHash,
    required this.timestamp,
    this.auditActivityId,
  });

  factory TransferExecutionResult.fromJson(Map<String, dynamic> json) {
    return TransferExecutionResult(
      proposalId: json['proposalId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      transactionHash: json['transactionHash']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      auditActivityId: json['auditActivityId']?.toString(),
    );
  }
}
