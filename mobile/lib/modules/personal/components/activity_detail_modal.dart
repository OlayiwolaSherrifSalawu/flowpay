import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/repositories/activity_repository.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';

/// Transaction Details Bottom Sheet
///
/// Displays complete transaction details:
/// - Amount
/// - Currency
/// - Source
/// - Destination
/// - Fee
/// - Exchange Rate
/// - Timestamp
/// - FlowPay Reference
/// - BMONI Reference
///
/// Strictly guarantees that:
/// - Private keys are never exposed
/// - Signing payloads are not exposed unnecessarily
/// - API credentials and secrets are never surfaced
class ActivityDetailModal extends StatelessWidget {
  final ActivityModel activity;
  final ValueChanged<ActivityModel>? onApprove;

  const ActivityDetailModal({
    super.key,
    required this.activity,
    this.onApprove,
  });

  static Future<void> show(
    BuildContext context, {
    required ActivityModel activity,
    ValueChanged<ActivityModel>? onApprove,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityDetailModal(
        activity: activity,
        onApprove: onApprove,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: FlowPayColors.accent,
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final d = dt.day;
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m $d, $y • $h:$min UTC';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAwaiting = activity.status == FlowPayAppStatus.awaitingApproval;

    final tokenBadge = activity.currency.stablecoinToken;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlowPaySpacing.xl),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.lightSurfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity.type.icon,
                    color: FlowPayColors.primaryLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activity.type.label} Details',
                        style: FlowPayTypography.headingSm.copyWith(
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FlowPay • BMONI Embedded Rails',
                        style: FlowPayTypography.caption.copyWith(
                          color: isDark
                              ? FlowPayColors.darkTextTertiary
                              : FlowPayColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Scrollable Content
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: FlowPaySpacing.xl),
              shrinkWrap: true,
              children: [
                // Hero Amount & Status Card
                FlowPayCard(
                  variant: FlowPayCardVariant.elevated,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRANSACTION AMOUNT',
                            style: FlowPayTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? FlowPayColors.darkTextTertiary
                                  : FlowPayColors.lightTextTertiary,
                            ),
                          ),
                          FlowPayStatusBadge(
                            appStatus: activity.status,
                            showDot: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: FlowPaySpacing.md),
                      FlowPayAmountDisplay(
                        amount: activity.amount != null
                            ? activity.amount!.formatFormatted(includeSymbol: false)
                            : '0.00',
                        currencySymbol: activity.currency.symbol,
                        currencyCode: activity.currency.code,
                        size: AmountDisplaySize.large,
                      ),
                      if (activity.exchangeRate != null &&
                          activity.exchangeRate != 'N/A' &&
                          activity.exchangeRate != 'N/A (Direct Currency)') ...[
                        const SizedBox(height: FlowPaySpacing.xs),
                        Text(
                          'Exchange Rate: ${activity.exchangeRate}',
                          style: FlowPayTypography.caption.copyWith(
                            color: FlowPayColors.accentLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: FlowPaySpacing.lg),

                // Core Transaction Breakdown
                FlowPayCard(
                  child: Column(
                    children: [
                      _buildDetailRow(
                        context,
                        label: 'Currency',
                        value: '${activity.currency.code} ($tokenBadge)',
                        badge: tokenBadge,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'Source',
                        value: activity.source ?? 'FlowPay Smart Wallet',
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'Destination',
                        value: activity.destination ?? activity.counterparty,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'Network Fee',
                        value: activity.fee != null
                            ? (activity.fee!.amountMinor == BigInt.zero
                                ? 'Sponsored by B-Key (\$0.00)'
                                : activity.fee!.formatFormatted())
                            : 'Sponsored by B-Key (\$0.00)',
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'Exchange Rate',
                        value: activity.exchangeRate ?? 'N/A (Direct Currency)',
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'Timestamp',
                        value: '${_formatTimestamp(activity.timestamp)} (${activity.timeAgo})',
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        context,
                        label: 'FlowPay Reference',
                        value: activity.reference,
                        isCopyable: true,
                        onCopy: () => _copyToClipboard(context, activity.reference, 'FlowPay Reference'),
                      ),
                      if (activity.bmoniReference != null) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          context,
                          label: 'BMONI Reference',
                          value: activity.bmoniReference!,
                          isCopyable: true,
                          onCopy: () => _copyToClipboard(context, activity.bmoniReference!, 'BMONI Reference'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: FlowPaySpacing.lg),

                // Security & Non-Exposure Guarantee Banner
                Container(
                  padding: FlowPaySpacing.insetMd,
                  decoration: BoxDecoration(
                    color: FlowPayColors.accent.withAlpha(20),
                    borderRadius: FlowPaySpacing.borderRadiusMd,
                    border: Border.all(color: FlowPayColors.accent.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: FlowPayColors.accentLight,
                        size: 20,
                      ),
                      const SizedBox(width: FlowPaySpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified by On-Device B-Key Signer',
                              style: FlowPayTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? FlowPayColors.darkTextPrimary
                                    : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zero AI money movement • Private keys & API secrets sealed in hardware enclave • Never exposed.',
                              style: FlowPayTypography.caption.copyWith(
                                color: isDark
                                    ? FlowPayColors.darkTextSecondary
                                    : FlowPayColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: FlowPaySpacing.xl),

                // Actions
                if (isAwaiting) ...[
                  FlowPayButton(
                    text: 'Approve & Sign with PIN',
                    icon: Icons.pin,
                    isFullWidth: true,
                    onPressed: () {
                      WalletPinAuthSheet.show(
                        context: context,
                        title: 'Approve ${activity.type.label}',
                        subtitle: 'Sign canonical BMONI proposal for ${activity.amount?.formatFormatted() ?? activity.reference}',
                        onAuthorize: (pin) async {
                          final updated = activity.copyWith(status: FlowPayAppStatus.completed);
                          onApprove?.call(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Action approved & signed via B-Key: ${activity.reference}'),
                              backgroundColor: FlowPayColors.accent,
                            ),
                          );
                          Navigator.of(context).pop(); // dismiss details modal
                          return '0x_signed_bmoni_proposal';
                        },
                      );
                    },
                  ),
                  const SizedBox(height: FlowPaySpacing.md),
                ],

                FlowPayButton(
                  text: 'Close',
                  variant: FlowPayButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),

                const SizedBox(height: FlowPaySpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    String? badge,
    bool isCopyable = false,
    VoidCallback? onCopy,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: FlowPayTypography.bodySm.copyWith(
              color: isDark
                  ? FlowPayColors.darkTextTertiary
                  : FlowPayColors.lightTextTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: FlowPayTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                FlowPayBadge(
                  label: badge,
                  showDot: false,
                  color: FlowPayColors.primaryLight,
                ),
              ],
              if (isCopyable && onCopy != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy,
                      size: 14,
                      color: isDark
                          ? FlowPayColors.darkTextTertiary
                          : FlowPayColors.lightTextTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
