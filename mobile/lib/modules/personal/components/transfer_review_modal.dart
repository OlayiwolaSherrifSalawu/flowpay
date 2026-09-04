import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../../core/design_system/amount_display.dart';
import '../../../core/transfers/transfer_funding.dart';
import '../../../core/transfers/transfer_intent.dart';

/// Premium Confirmation Screen for FlowPay Transfers
/// Shows:
/// - Recipient
/// - Amount
/// - Currency
/// - Funding source
/// - Conversion
/// - Exchange rate where available
/// - Fee
/// - Total
/// - "Nothing moves until you approve."
/// - Buttons: Edit, Approve & Send
class TransferReviewModal extends StatelessWidget {
  final TransferIntent intent;
  final TransferFundingOption fundingOption;
  final VoidCallback onEdit;
  final VoidCallback onApproveAndSend;
  final bool isProcessing;

  const TransferReviewModal({
    super.key,
    required this.intent,
    required this.fundingOption,
    required this.onEdit,
    required this.onApproveAndSend,
    this.isProcessing = false,
  });

  static Future<void> show({
    required BuildContext context,
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
    required VoidCallback onEdit,
    required VoidCallback onApproveAndSend,
    bool isProcessing = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BMoniColors.offbrand950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TransferReviewModal(
        intent: intent,
        fundingOption: fundingOption,
        onEdit: onEdit,
        onApproveAndSend: onApproveAndSend,
        isProcessing: isProcessing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: BMoniColors.offbrand950,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: BMoniColors.offbrand700),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BMoniColors.offbrand700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: BMoniColors.brand400, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Review Transfer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: BMoniColors.grey50,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: BMoniColors.grey400, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Amount & Recipient Hero Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BMoniColors.offbrand900,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BMoniColors.offbrand700),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total to Send',
                          style: TextStyle(
                              fontSize: 13, color: BMoniColors.grey400),
                        ),
                        const SizedBox(height: 6),
                        FlowPayAmountDisplay(
                          amount: intent.amount,
                          currencySymbol: intent.currency.symbol,
                          currencyCode: intent.currency.code,
                          size: AmountDisplaySize.large,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: BMoniColors.offbrand800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: BMoniColors.offbrand700),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    BMoniColors.brand500.withAlpha(50),
                                child: Text(
                                  intent.recipient.isNotEmpty
                                      ? intent.recipient[0].toUpperCase()
                                      : 'B',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: BMoniColors.brand300,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      intent.recipient,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: BMoniColors.grey50,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (intent.purpose != null &&
                                        intent.purpose!.isNotEmpty)
                                      Text(
                                        intent.purpose!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: BMoniColors.grey400),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Transfer Breakdown Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BMoniColors.offbrand900,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BMoniColors.offbrand700),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Recipient', intent.recipient),
                        _buildRow('Amount',
                            '${intent.amount} ${intent.currency.code}'),
                        _buildRow('Currency',
                            '${intent.currency.name} (${intent.currency.code})'),
                        _buildRow(
                            'Funding Source', fundingOption.fundingWalletName),
                        const Divider(
                            color: BMoniColors.offbrand700, height: 18),

                        // Conversion & Exchange Rate Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Conversion',
                                style: TextStyle(
                                    color: BMoniColors.grey400, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: fundingOption.requiresConversion
                                    ? BMoniColors.brand500.withAlpha(40)
                                    : BMoniColors.success400.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: fundingOption.requiresConversion
                                      ? BMoniColors.brand500.withAlpha(80)
                                      : BMoniColors.success400.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (fundingOption.requiresConversion)
                                    const Icon(Icons.currency_exchange,
                                        size: 12, color: BMoniColors.brand300),
                                  if (fundingOption.requiresConversion)
                                    const SizedBox(width: 4),
                                  Text(
                                    fundingOption.conversionLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: fundingOption.requiresConversion
                                          ? BMoniColors.brand300
                                          : BMoniColors.success400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (fundingOption.exchangeRate != null)
                          _buildRow(
                            'Exchange Rate',
                            fundingOption.fundingCurrency == intent.currency
                                ? '1.00'
                                : '1 ${intent.currency.code} = ${fundingOption.exchangeRate!.toStringAsFixed(2)} ${fundingOption.fundingCurrency.code}',
                          ),

                        if (fundingOption.requiresConversion)
                          _buildRow(
                            'Converted Principal',
                            fundingOption.convertedDebit.formatFormatted(),
                          ),

                        _buildRow('Network & Rail Fee',
                            fundingOption.networkFee.formatFormatted()),

                        if (fundingOption.requiresConversion &&
                            fundingOption.fxFee.amountMinor > BigInt.zero)
                          _buildRow('Conversion Fee (15 bps)',
                              fundingOption.fxFee.formatFormatted()),

                        const Divider(
                            color: BMoniColors.offbrand700, height: 18),

                        // Total Settlement
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Settlement',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: BMoniColors.grey50,
                              ),
                            ),
                            Text(
                              fundingOption.totalDebit.formatFormatted(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: BMoniColors.brand300,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Reassurance Banner: "Nothing moves until you approve."
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BMoniColors.brand500.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: BMoniColors.brand500.withAlpha(80)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: BMoniColors.brand300, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nothing moves until you approve.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: BMoniColors.grey50,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Zero AI money movement • On-device B-Key hardware PIN signature required',
                                style: TextStyle(
                                    fontSize: 11, color: BMoniColors.grey400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Action Buttons: Edit and Approve & Send
          Row(
            children: [
              Expanded(
                flex: 1,
                child: BMoniButton(
                  key: const Key('transfer_review_edit_button'),
                  text: 'Edit',
                  variant: BMoniButtonVariant.secondary,
                  size: BMoniButtonSize.large,
                  onPressed: isProcessing ? null : onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: BMoniButton(
                  key: const Key('transfer_review_approve_button'),
                  text: 'Approve & Send',
                  variant: BMoniButtonVariant.primary,
                  size: BMoniButtonSize.large,
                  isLoading: isProcessing,
                  onPressed: isProcessing ? null : onApproveAndSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: BMoniColors.grey400, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: BMoniColors.grey50,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
