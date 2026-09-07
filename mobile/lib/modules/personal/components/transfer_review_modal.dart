import 'package:flutter/material.dart';
import '../../../core/design_system/amount_display.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/transfers/transfer_funding.dart';
import '../../../core/transfers/transfer_intent.dart';

/// Premium Confirmation Screen for FlowPay Transfers
/// Directives:
/// - Recipient identity & destination
/// - Funding source
/// - Conversion details & exchange rate
/// - Fee breakdown & total debit
/// - Clear consequence section: "After this payment" balance impact
/// - Security reassurance: "Nothing moves until you approve."
/// - Primary Action: "Approve & Continue", Secondary: "Edit"
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
      backgroundColor: FlowPayColors.darkBackground,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate before and after balance estimates
    final currentBal = fundingOption.availableBalance.formatted;
    final afterBalDouble = (fundingOption.availableBalance.majorUnits -
            fundingOption.totalDebit.majorUnits)
        .clamp(0.0, double.infinity);
    final afterBal =
        '${fundingOption.totalDebit.currency.symbol}${afterBalDouble.toStringAsFixed(2)}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
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
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: FlowPayColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ready to Send',
                    style: FlowPayTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: FlowPayColors.darkTextSecondary,
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
                      borderRadius: FlowPaySpacing.borderRadiusXl,
                      border: Border.all(
                        color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TRANSFER AMOUNT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: FlowPayColors.darkTextSecondary,
                          ),
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
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? FlowPayColors.darkSurfaceElevated
                                : FlowPayColors.lightSurfaceElevated,
                            borderRadius: FlowPaySpacing.borderRadiusMd,
                            border: Border.all(
                              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: FlowPayColors.primary.withAlpha(35),
                                child: Text(
                                  intent.recipient.isNotEmpty
                                      ? intent.recipient[0].toUpperCase()
                                      : 'B',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: FlowPayColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      intent.recipient,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? FlowPayColors.darkTextPrimary
                                            : FlowPayColors.lightTextPrimary,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (intent.purpose != null &&
                                        intent.purpose!.isNotEmpty)
                                      Text(
                                        intent.purpose!,
                                        style: FlowPayTypography.captionStyle(
                                          color: FlowPayColors.darkTextSecondary,
                                        ),
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
                      color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
                      borderRadius: FlowPaySpacing.borderRadiusLg,
                      border: Border.all(
                        color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Recipient', intent.recipient, isDark),
                        _buildRow('Amount',
                            '${intent.amount} ${intent.currency.code}', isDark),
                        _buildRow('Currency',
                            '${intent.currency.name} (${intent.currency.code})', isDark),
                        _buildRow(
                            'Funding Source', fundingOption.fundingWalletName, isDark),
                        const Divider(color: FlowPayColors.hairline, height: 18),

                        // Conversion & Exchange Rate Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Conversion',
                                style: TextStyle(
                                    color: FlowPayColors.darkTextSecondary, fontSize: 13)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: fundingOption.requiresConversion
                                      ? FlowPayColors.accent.withAlpha(35)
                                      : FlowPayColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: fundingOption.requiresConversion
                                        ? FlowPayColors.accent.withAlpha(80)
                                        : FlowPayColors.primary.withAlpha(70),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (fundingOption.requiresConversion)
                                      const Icon(Icons.currency_exchange,
                                          size: 12, color: FlowPayColors.accentLight),
                                    if (fundingOption.requiresConversion)
                                      const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        fundingOption.conversionLabel,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: fundingOption.requiresConversion
                                              ? FlowPayColors.accentLight
                                              : FlowPayColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (fundingOption.requiresConversion &&
                            fundingOption.exchangeRate != null) ...[
                          const SizedBox(height: 8),
                          _buildRow(
                            'Exchange Rate',
                            '1 ${intent.currency.code} = ${fundingOption.exchangeRate!.toStringAsFixed(2)} ${fundingOption.fundingCurrency.code}',
                            isDark,
                          ),
                        ],

                        const Divider(color: FlowPayColors.hairline, height: 18),

                        // Fees & Debit
                        _buildRow(
                            'Network Fee',
                            fundingOption.networkFee.formatted,
                            isDark),
                        if (fundingOption.requiresConversion)
                          _buildRow(
                              'FX Conversion Fee',
                              fundingOption.fxFee.formatted,
                              isDark),
                        const Divider(color: FlowPayColors.hairline, height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Debit',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: FlowPayColors.ink,
                              ),
                            ),
                            Text(
                              fundingOption.totalDebit.formatted,
                              style: FlowPayTypography.amount(
                                color: FlowPayColors.primary,
                              ).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Clear Consequence Block: "After this payment"
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlowPayColors.surfaceAlt,
                      borderRadius: FlowPaySpacing.borderRadiusLg,
                      border: Border.all(color: FlowPayColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics_outlined,
                                size: 16, color: FlowPayColors.primaryLight),
                            SizedBox(width: 8),
                            Text(
                              'AFTER THIS PAYMENT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: FlowPayColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${fundingOption.fundingCurrency.code} Balance:',
                                style: FlowPayTypography.bodyMd.copyWith(
                                  color: FlowPayColors.darkTextSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$currentBal → $afterBal',
                                textAlign: TextAlign.right,
                                style: FlowPayTypography.amount(
                                  color: FlowPayColors.ink,
                                ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Security Reassurance Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(20),
                      borderRadius: FlowPaySpacing.borderRadiusLg,
                      border: Border.all(
                        color: FlowPayColors.primary.withAlpha(70),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 20, color: FlowPayColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nothing moves until you approve.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: FlowPayColors.ink,
                                ),
                              ),
                              Text(
                                'Requires on-device PIN signature • Zero unauthorized movement',
                                style: FlowPayTypography.captionStyle(
                                  color: FlowPayColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Action Buttons: Primary Approve & Send / Secondary Edit
          Row(
            children: [
              Expanded(
                child: FlowPayButton(
                  key: const Key('transfer_review_edit_button'),
                  text: 'Edit',
                  variant: FlowPayButtonVariant.secondary,
                  size: FlowPayButtonSize.medium,
                  onPressed: isProcessing ? null : onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FlowPayButton(
                  key: const Key('transfer_review_approve_button'),
                  text: 'Approve & Send',
                  icon: Icons.lock_outline,
                  size: FlowPayButtonSize.medium,
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

  Widget _buildRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FlowPayColors.darkTextSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
