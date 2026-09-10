import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? FlowPayColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: FlowPayRadii.card,
        side: BorderSide(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FlowPayColors.primary.withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FlowPayColors.primary.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: FlowPayColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Payment Sent',
              style: FlowPayTypography.headingSm.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Payment confirmed and recorded to activity',
              style: FlowPayTypography.captionStyle(
                color: FlowPayColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Amount summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.mint100.withAlpha(50),
                borderRadius: FlowPayRadii.cardMedium,
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.emerald600.withAlpha(40),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${intent.amount} ${intent.currency.code}',
                    style: FlowPayTypography.amount(
                      color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                    ).copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'to ${intent.recipient}',
                    style: FlowPayTypography.captionStyle(
                      color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Key details
            _buildSummaryRow('Recipient', intent.recipient, isDark),
            _buildSummaryRow(
                'Paid from', fundingOption.fundingWalletName, isDark),
            if (fundingOption.requiresConversion)
              _buildSummaryRow(
                  'Exchange', fundingOption.conversionLabel, isDark),
            _buildSummaryRow(
                'Total paid',
                fundingOption.totalDebit.formattedWithSymbol,
                isDark),
            _buildSummaryRow(
                'Timestamp',
                DateTime.now().toLocal().toString().substring(0, 16),
                isDark),

            const SizedBox(height: 12),

            // Reference hash pill
            if (result.transactionHash.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF3F4F6),
                  borderRadius: FlowPayRadii.input,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, size: 14, color: FlowPayColors.darkTextSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ref: ${result.transactionHash}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: FlowPayColors.darkTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.transactionHash));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction reference copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(Icons.copy,
                          size: 14, color: FlowPayColors.primary),
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
                    child: FlowPayButton(
                      text: 'Activity',
                      variant: FlowPayButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onViewActivity!();
                      },
                    ),
                  ),
                if (onViewActivity != null) const SizedBox(width: 10),
                Expanded(
                  child: FlowPayButton(
                    key: const Key('transfer_receipt_done_button'),
                    text: 'Done',
                    variant: FlowPayButtonVariant.primary,
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

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: FlowPayColors.darkTextSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
