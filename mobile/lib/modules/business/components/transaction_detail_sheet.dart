import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/amount_display.dart';
import '../../../core/design_system/dialogs.dart';
import '../../../core/models/shared_transaction.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Modal Bottom Sheet displaying in-depth detail for single transactions:
/// Card Spends, Smart Wallet Transfers, Employee Payments, or Failures.
/// FlowPay Dribbble Fintech styling:
/// - 28dp top sheet radius (FlowPayRadii.sheet)
/// - Theme-adaptive canvas (surfaceOf / borderOf)
/// - Sanitized references with 1-tap copy action
/// - Universal pill dismiss button
class TransactionDetailSheet extends StatelessWidget {
  final SharedTransactionModel transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<void> show(BuildContext context, SharedTransactionModel tx) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: tx),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    final flag = transaction.country == 'NG'
        ? '🇳🇬'
        : (transaction.country == 'MX'
            ? '🇲🇽'
            : (transaction.country == 'CA' ? '🇨🇦' : '🌐'));

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: FlowPayRadii.sheet,
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Squircle Icon & Title
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: transaction.isFailure
                      ? FlowPayColors.stateError.withValues(alpha: 0.15)
                      : FlowPayColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: FlowPayRadii.avatar,
                  border: Border.all(
                    color: transaction.isFailure
                        ? FlowPayColors.stateError.withValues(alpha: 0.35)
                        : FlowPayColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  transaction.isFailure
                      ? Icons.error_outline_rounded
                      : (transaction.type == TransactionType.cardTransaction
                          ? Icons.credit_card_rounded
                          : Icons.account_balance_wallet_outlined),
                  color: transaction.isFailure
                      ? FlowPayColors.stateError
                      : FlowPayColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: FlowPayTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.counterparty ?? 'FlowPay Business'} · $flag',
                      style: FlowPayTypography.caption.copyWith(
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              StatusText.fromStatusString(transaction.status.displayName),
            ],
          ),
          const SizedBox(height: 20),

          // Primary Amount Display
          FlowPayAmountDisplay(
            amount: transaction.amount.formatFormatted(),
            size: AmountDisplaySize.large,
            color: textPrimaryColor,
          ),
          if (transaction.secondaryAmount != null) ...[
            const SizedBox(height: 4),
            Text(
              '${transaction.secondaryAmount!.formatted} ${transaction.secondaryCurrency ?? ''}',
              style: FlowPayTypography.bodyMedium.copyWith(
                color: FlowPayColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Transaction Metadata Card
          ActivitySectionCard(
            header: const SectionHeader(
              title: 'Transaction Details',
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                _buildRow(context, 'Category', transaction.type.name.toUpperCase()),
                _buildRow(context, 'Date & Time', _formatDate(transaction.timestamp)),
                if (transaction.flowpayReference != null)
                  _buildRowWithCopy(context, 'FlowPay Reference', transaction.flowpayReference!),
                if (transaction.bmoniReference != null)
                  _buildRowWithCopy(context, 'BMONI Rail Reference', transaction.bmoniReference!),
                if (transaction.description.isNotEmpty)
                  _buildRow(context, 'Description', transaction.description),
              ],
            ),
          ),

          // Failure Details (if applicable)
          if (transaction.isFailure && transaction.errorReason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlowPayColors.stateError.withValues(alpha: 0.12),
                borderRadius: FlowPayRadii.input,
                border: Border.all(
                    color: FlowPayColors.stateError.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: FlowPayColors.stateError, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'AUDIT FAILURE LOG',
                        style: FlowPayTypography.caption.copyWith(
                          color: FlowPayColors.stateError,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    transaction.errorReason!,
                    style: FlowPayTypography.caption
                        .copyWith(color: textPrimaryColor),
                  ),
                  if (transaction.failedStage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Failed Stage: ${transaction.failedStage}',
                      style: FlowPayTypography.caption.copyWith(
                        color: textSecondaryColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Dismiss Button
          FlowPayButton(
            text: 'Dismiss',
            variant: FlowPayButtonVariant.secondary,
            size: FlowPayButtonSize.medium,
            isFullWidth: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FlowPayTypography.caption.copyWith(
              color: textSecondaryColor,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: FlowPayTypography.caption.copyWith(
                color: textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowWithCopy(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FlowPayTypography.caption.copyWith(
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: FlowPayTypography.caption.copyWith(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    BMoniToastOverlay.showSuccess(
                      context: context,
                      title: 'Copied',
                      message: '$label copied to clipboard.',
                    );
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: FlowPayColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
