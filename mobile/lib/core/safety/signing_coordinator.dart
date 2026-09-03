import '../bmoni_sdk/bmoni_sdk_service.dart';
import '../money/money.dart';
import 'financial_intent.dart';
import 'operation_preview.dart';

class SigningCoordinator {
  /**
   * Complete Financial Safety Pipeline:
   * 1. Validate intent deterministically against available balance
   * 2. Build explicit Preview
   * 3. Prompt user PIN & sign on-device
   * 4. Return signed execution payload
   */
  static Future<OperationPreview> prepareTransfer({
    required FinancialIntent intent,
    required Money availableBalance,
  }) async {
    final amountMoney = Money.fromMinor(intent.amountMinor, intent.sourceCurrency);
    final recipient = intent.recipientIdentifier ?? 'Unknown Recipient';

    return OperationPreview.fromIntentAndBalance(
      intentId: intent.intentId,
      amount: amountMoney,
      recipient: recipient,
      availableBalance: availableBalance,
    );
  }

  static Future<String> authorizeAndSign({
    required String hashToSign,
    required String pin,
  }) async {
    // Executes strictly on-device using Keystore / Secure Enclave
    return await BmoniSdkService.signTransactionHash(hashToSign, pin: pin);
  }
}
