import 'package:flutter/material.dart';
import '../../../core/design_system/amount_display.dart';
import '../../../core/models/shared_transaction.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/typography.dart';

/// Modal Bottom Sheet displaying in-depth detail for single transactions:
/// Card Spends, Smart Wallet Transfers, Employee Payments, or Failures.
/// Strictly sanitizes references to ensure no private key or signing secrets are exposed.
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
    final flag = transaction.country == 'NG'
        ? '🇳🇬'
        : (transaction.country == 'MX'
            ? '🇲🇽'
            : (transaction.country == 'CA' ? '🇨🇦' : '🌐'));

    return Container(
      decoration: BoxDecoration(
        color: FlowPayColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: FlowPayColors.hairline),
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
                color: FlowPayColors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Icon & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: transaction.isFailure
                      ? FlowPayColors.stateError.withValues(alpha: 0.15)
                      : FlowPayColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.isFailure
                      ? Icons.error_outline
                      : (transaction.type == TransactionType.cardTransaction
                          ? Icons.credit_card
                          : Icons.account_balance_wallet_outlined),
                  color: transaction.isFailure
                      ? FlowPayColors.stateError
                      : FlowPayColors.accent,
                  size: 24,
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
                        color: FlowPayColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.counterparty ?? 'FlowPay Business'} · $flag',
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.darkTextSecondary,
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
            color: FlowPayColors.ink,
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
                _buildRow('Category', transaction.type.name.toUpperCase()),
                _buildRow('Date & Time', _formatDate(transaction.timestamp)),
                if (transaction.flowpayReference != null)
                  _buildRow('FlowPay Reference', transaction.flowpayReference!,
                      isMonospace: true),
                if (transaction.bmoniReference != null)
                  _buildRow('BMONI Rail Reference', transaction.bmoniReference!,
                      isMonospace: true),
                if (transaction.description.isNotEmpty)
                  _buildRow('Description', transaction.description),
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
                borderRadius: BorderRadius.circular(12),
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
                        .copyWith(color: FlowPayColors.ink),
                  ),
                  if (transaction.failedStage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Failed Stage: ${transaction.failedStage}',
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.darkTextTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FlowPayTypography.caption.copyWith(
              color: FlowPayColors.darkTextSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: FlowPayTypography.caption.copyWith(
                color: FlowPayColors.ink,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
