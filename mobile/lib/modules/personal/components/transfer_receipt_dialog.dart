import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../../core/transfers/transfer_funding.dart';
import '../../../core/transfers/transfer_intent.dart';
import '../../../core/transfers/transfer_models.dart';

class TransferReceiptDialog extends StatelessWidget {
  final TransferIntent intent;
  final TransferFundingOption fundingOption;
  final TransferExecutionResult result;
  final VoidCallback onDone;
  final VoidCallback? onViewActivity;

  const TransferReceiptDialog({
    super.key,
    required this.intent,
    required this.fundingOption,
    required this.result,
    required this.onDone,
    this.onViewActivity,
  });

  static Future<void> show({
    required BuildContext context,
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
    required TransferExecutionResult result,
    required VoidCallback onDone,
    VoidCallback? onViewActivity,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TransferReceiptDialog(
        intent: intent,
        fundingOption: fundingOption,
        result: result,
        onDone: onDone,
        onViewActivity: onViewActivity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BMoniColors.offbrand900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: BMoniColors.offbrand700),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: BMoniColors.success400.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: BMoniColors.success400.withAlpha(100), width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: BMoniColors.success400,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Transfer Settled',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BMoniColors.grey50,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Successfully delivered ${intent.amount} ${intent.currency.code}',
              style: const TextStyle(fontSize: 13, color: BMoniColors.grey400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BMoniColors.offbrand800,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BMoniColors.offbrand700),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Beneficiary', intent.recipient),
                  _buildSummaryRow('Delivered Amount', '${intent.amount} ${intent.currency.code}'),
                  _buildSummaryRow('Funding Wallet', fundingOption.fundingWalletName),
                  if (fundingOption.requiresConversion)
                    _buildSummaryRow('Conversion', fundingOption.conversionLabel),
                  _buildSummaryRow('Settlement Debit', fundingOption.totalDebit.formatFormatted()),
                  const Divider(color: BMoniColors.offbrand700, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BMONI On-Chain Rail',
                        style: TextStyle(fontSize: 12, color: BMoniColors.grey400),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BMoniColors.brand500.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Verified & Logged',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: BMoniColors.brand300,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Transaction Hash with Copy Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: BMoniColors.offbrand950,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BMoniColors.offbrand700),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: BMoniColors.grey400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.transactionHash,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Courier',
                        color: BMoniColors.grey400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: result.transactionHash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction hash copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy, size: 14, color: BMoniColors.brand300),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Buttons
            Row(
              children: [
                if (onViewActivity != null)
                  Expanded(
                    child: BMoniButton(
                      text: 'Activity',
                      variant: BMoniButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onViewActivity!();
                      },
                    ),
                  ),
                if (onViewActivity != null) const SizedBox(width: 10),
                Expanded(
                  child: BMoniButton(
                    key: const Key('transfer_receipt_done_button'),
                    text: 'Done',
                    variant: BMoniButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDone();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: BMoniColors.grey400)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BMoniColors.grey50,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
