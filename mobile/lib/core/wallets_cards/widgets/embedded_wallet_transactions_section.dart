import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../models/embedded_wallet.dart';

typedef EmbeddedTransactionItemBuilder = Widget Function(
  BuildContext context,
  EmbeddedWalletTransaction transaction,
);

/// Composed recent-activity list with a "view all" action, pagination support,
/// and host-driven row builders adhering to design.md copy rules.
class EmbeddedWalletTransactionsSection extends StatelessWidget {
  final String title;
  final String viewAllLabel;
  final VoidCallback? onViewAll;
  final List<EmbeddedWalletTransaction> transactions;
  final bool isInitialLoading;
  final Widget? emptyState;
  final EmbeddedTransactionItemBuilder? itemBuilder;

  const EmbeddedWalletTransactionsSection({
    super.key,
    this.title = 'Recent Activity',
    this.viewAllLabel = 'View All',
    this.onViewAll,
    required this.transactions,
    this.isInitialLoading = false,
    this.emptyState,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title.toUpperCase(),
              style: FlowPayTypography.captionStyle(
                color: FlowPayColors.textTertiary,
              ).copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onViewAll != null) ...[
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      viewAllLabel,
                      style: const TextStyle(
                        color: FlowPayColors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: FlowPayColors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Body Content
        if (isInitialLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          )
        else if (transactions.isEmpty)
          emptyState ??
              FlowPayCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: FlowPayColors.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No recent transactions',
                          style: FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Disbursements and card settlements will appear here.',
                          textAlign: TextAlign.center,
                          style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
        else
          FlowPayCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(
                color: FlowPayColors.hairline,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                if (itemBuilder != null) {
                  return itemBuilder!(context, tx);
                }
                return _DefaultTransactionTile(transaction: tx);
              },
            ),
          ),
      ],
    );
  }
}

class _DefaultTransactionTile extends StatelessWidget {
  final EmbeddedWalletTransaction transaction;

  const _DefaultTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.isIncoming;
    final sign = isIncoming ? '+' : '-';
    final amountColor = isIncoming ? FlowPayColors.signal : FlowPayColors.ink;

    final sym = transaction.currency.toUpperCase() == 'NGN' ||
            transaction.currency.toUpperCase() == 'CNGN'
        ? '₦'
        : transaction.currency.toUpperCase() == 'MXN' ||
                transaction.currency.toUpperCase() == 'MEXE'
            ? 'Mex\$'
            : transaction.currency.toUpperCase() == 'CAD' ||
                    transaction.currency.toUpperCase() == 'CADC'
                ? 'CA\$'
                : '\$';

    final formattedAmount =
        '$sign$sym${transaction.amount.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isIncoming
                  ? FlowPayColors.signal.withValues(alpha: 0.12)
                  : FlowPayColors.surfaceAlt,
            ),
            child: Icon(
              isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: isIncoming ? FlowPayColors.signal : FlowPayColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.counterpartyName ??
                      (isIncoming ? 'FlowPay Payroll' : 'Card Spend'),
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: transaction.status == EmbeddedWalletTransactionStatus.completed
                      ? FlowPayColors.signal.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  transaction.status.name.toUpperCase(),
                  style: TextStyle(
                    color: transaction.status == EmbeddedWalletTransactionStatus.completed
                        ? FlowPayColors.signal
                        : Colors.amber[700],
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
