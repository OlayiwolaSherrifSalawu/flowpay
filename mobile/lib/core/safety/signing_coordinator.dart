import '../money/money.dart';
import '../wallet/wallet_signer.dart';
import 'financial_intent.dart';
import 'operation_preview.dart';

class SigningCoordinator {
  final WalletSigner _signer;

  const SigningCoordinator({WalletSigner? signer})
      : _signer = signer ?? const BmoniWalletSigner();

  /// Complete Financial Safety Pipeline:
  /// 1. Validate intent deterministically against available balance
  /// 2. Build explicit Preview
  /// 3. Prompt user PIN & sign on-device
  /// 4. Return signed execution payload
  static Future<OperationPreview> prepareTransfer({
    required FinancialIntent intent,
    required Money availableBalance,
  }) async {
    final amountMoney =
        Money.fromMinor(intent.amountMinor, intent.sourceCurrency);
    final recipient = intent.recipientIdentifier ?? 'Unknown Recipient';

    return OperationPreview.fromIntentAndBalance(
      intentId: intent.intentId,
      amount: amountMoney,
      recipient: recipient,
      availableBalance: availableBalance,
    );
  }

  Future<String> authorize({
    required String hashToSign,
    required String pin,
  }) async {
    return await _signer.signTransactionHash(hashToSign, pin: pin);
  }

  static Future<String> authorizeAndSign({
    required String hashToSign,
    required String pin,
    WalletSigner? signer,
  }) async {
    // Executes strictly on-device using WalletSigner (Keystore / Secure Enclave)
    final activeSigner = signer ?? const BmoniWalletSigner();
    return await activeSigner.signTransactionHash(hashToSign, pin: pin);
  }
}
