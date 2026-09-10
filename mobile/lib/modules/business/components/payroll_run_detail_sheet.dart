import 'package:flutter/material.dart';
import '../../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/repositories/payroll_repository.dart';
import '../../../core/state/business_provider.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';

/// Modal Bottom Sheet displaying in-depth Payroll Run Detail and Audit Trail.
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - 28dp sheet radius (FlowPayRadii.sheet)
/// - Theme-adaptive canvas with drag handle
/// - Never surfaces hashToSign, signature, private key material, or webhook secrets.
/// - Surfaces public/audit references (FlowPay reference, BMONI proposal ID, tx hash).
/// - Supports granular retry of failed proposal items via on-device PIN authorization.
class PayrollRunDetailSheet extends StatefulWidget {
  final PayrollRunModel run;
  final BusinessProvider businessProvider;

  const PayrollRunDetailSheet({
    super.key,
    required this.run,
    required this.businessProvider,
  });

  static Future<void> show(
    BuildContext context, {
    required PayrollRunModel run,
    required BusinessProvider businessProvider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayrollRunDetailSheet(
        run: run,
        businessProvider: businessProvider,
      ),
    );
  }

  @override
  State<PayrollRunDetailSheet> createState() => _PayrollRunDetailSheetState();
}

class _PayrollRunDetailSheetState extends State<PayrollRunDetailSheet> {
  late PayrollRunModel _currentRun;
  final Set<String> _retryingEmployeeIds = {};
  int _paymentsPage = 1;
  static const int _paymentsPageSize = 5;

  @override
  void initState() {
    super.initState();
    _currentRun = widget.run;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRetryItem(PayrollItemModel item) async {
    final pin = await WalletPinAuthSheet.show(
      context: context,
      title: 'Authorize Payout Retry',
      subtitle:
          'Enter your 6-digit PIN to retry payment to ${item.employeeName}',
      onAuthorize: (pin) => BmoniSdkService.signMessage(
        'Retry payroll proposal ${item.proposalId ?? item.employeeId}',
        pin: pin,
      ),
    );

    if (pin == null || pin.length != BmoniSdkService.pinLength) return;

    setState(() => _retryingEmployeeIds.add(item.employeeId));

    try {
      final updatedItem = await widget.businessProvider.retryPayrollProposal(
        proposalId: item.proposalId ?? 'prop_retry_${item.employeeId}',
        employeeId: item.employeeId,
        pin: pin,
      );

      final updatedItems = _currentRun.items.map((i) {
        if (i.employeeId == item.employeeId) {
          return updatedItem;
        }
        return i;
      }).toList();

      final allCompleted = updatedItems
          .every((i) => i.status == 'COMPLETED' || i.status == 'SUCCESS');

      setState(() {
        _currentRun = _currentRun.copyWith(
          status: allCompleted ? 'COMPLETED' : 'PARTIALLY_COMPLETED',
          items: updatedItems,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FlowPayColors.stateSuccess,
            content: Text(
              'Payment resent successfully to ${item.employeeName}.',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FlowPayColors.stateError,
            content: Text('Retry failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retryingEmployeeIds.remove(item.employeeId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    final flowpayRef =
        'FP-PAY-${_currentRun.runId.length > 8 ? _currentRun.runId.substring(_currentRun.runId.length - 8) : _currentRun.runId}';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.sheet,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: FlowPayRadii.chip,
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: FlowPayColors.primary.withValues(alpha: 0.12),
                        borderRadius: FlowPayRadii.avatar,
                        border: Border.all(
                          color: FlowPayColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.receipt_long_rounded,
                            color: FlowPayColors.primary, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentRun.title,
                            style: FlowPayTypography.title(color: inkColor).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${_currentRun.runId} · ${_formatDate(_currentRun.executedAt)}',
                            style: FlowPayTypography.captionStyle(
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: _currentRun.status),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderColor),

              // Scrollable Content Area
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section 1: Financial Summary Card (using ActivitySectionCard)
                    ActivitySectionCard(
                      header: SectionHeader(
                        title: 'Payroll Summary',
                        trailing: Icon(Icons.analytics_outlined,
                            color: textSecondaryColor, size: 18),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOTAL DISBURSED (USD EQUIV)',
                                    style: FlowPayTypography.captionStyle(
                                      color: textTertiaryColor,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FlowPayAmountDisplay(
                                    amount:
                                        _currentRun.totalUsd.formatFormatted(),
                                    size: AmountDisplaySize.large,
                                    color: inkColor,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'FEES',
                                    style: FlowPayTypography.captionStyle(
                                      color: textTertiaryColor,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentRun.totalFeeUsd.formatted,
                                    style: const TextStyle(
                                      color: FlowPayColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Cost Transparency & Savings Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  FlowPayColors.primary.withValues(alpha: 0.1),
                              borderRadius: FlowPayRadii.input,
                              border: Border.all(
                                  color: FlowPayColors.primary
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings_outlined,
                                    color: FlowPayColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saved ${_currentRun.totalSavedFeeUsd.formatted} (${_currentRun.savedPercentage.toStringAsFixed(0)}% vs SWIFT Wire)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: inkColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'One aggregate USD bill fan-out saved \$170/country compared to traditional wires.',
                                        style: FlowPayTypography.captionStyle(
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Audit Reference Data (FlowPay reference & BMONI reference - ZERO secrets!)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem('FlowPay Reference', flowpayRef, isDark),
                              _buildMetaItem(
                                'Batch Reference',
                                _currentRun.items.isNotEmpty &&
                                        _currentRun.items.first.proposalId !=
                                            null
                                    ? (_currentRun.items.first.proposalId!
                                                .length >
                                            16
                                        ? '${_currentRun.items.first.proposalId!.substring(0, 16)}...'
                                        : _currentRun.items.first.proposalId!)
                                    : 'BATCH-${_currentRun.runId.hashCode.abs().toString().substring(0, 6)}',
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Execution Timeline Card
                    ActivitySectionCard(
                      header: SectionHeader(
                        title: 'Orchestration Timeline',
                        trailing: Icon(Icons.timeline_rounded,
                            color: textSecondaryColor, size: 18),
                      ),
                      child: Column(
                        children: [
                          _buildTimelineStep(
                            index: 1,
                            title: 'Account Verification',
                            subtitle:
                                'Verified employee accounts in Nigeria & Mexico',
                            status: StepStatus.completed,
                            time: '0.2s',
                            isDark: isDark,
                          ),
                          _buildTimelineStep(
                            index: 2,
                            title: 'PIN Approval',
                            subtitle:
                                'Approved with your 6-digit PIN on this device',
                            status: StepStatus.completed,
                            time: '1.1s',
                            isDark: isDark,
                          ),
                          _buildTimelineStep(
                            index: 3,
                            title: 'Multi-Country Delivery',
                            subtitle:
                                'Sent simultaneous payments to all employees',
                            status: _currentRun.status == 'PROCESSING'
                                ? StepStatus.inProgress
                                : StepStatus.completed,
                            time: '2.4s',
                            isDark: isDark,
                          ),
                          _buildTimelineStep(
                            index: 4,
                            title: 'Settlement & Webhook Sync',
                            subtitle: _currentRun.failedCount > 0
                                ? '${_currentRun.completedCount} succeeded · ${_currentRun.failedCount} requires retry'
                                : 'All employee accounts funded in local stablecoins',
                            status: _currentRun.failedCount > 0
                                ? StepStatus.warning
                                : (_currentRun.status == 'COMPLETED'
                                    ? StepStatus.completed
                                    : StepStatus.pending),
                            time: 'Finished',
                            isLast: true,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Employee Payments & Individual Status (ActivitySectionCard)
                    ActivitySectionCard(
                      header: SectionHeader(
                        title:
                            'Employee Payments (${_currentRun.items.length})',
                        trailing: Text(
                          '${_currentRun.countries.length} Countries',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          ...() {
                            final paginated = PaginatedResult.paginateList(
                              _currentRun.items,
                              page: _paymentsPage,
                              limit: _paymentsPageSize,
                            );
                            return [
                              for (int i = 0;
                                  i < paginated.items.length;
                                  i++) ...[
                                _buildEmployeePaymentRow(
                                    paginated.items[i], isDark),
                                if (i < paginated.items.length - 1)
                                  Divider(
                                      height: 20,
                                      thickness: 1,
                                      color: borderColor),
                              ],
                              if (_currentRun.items.length >
                                  _paymentsPageSize) ...[
                                const SizedBox(height: 12),
                                FlowPayPaginationBar(
                                  currentPage: _paymentsPage,
                                  totalPages: paginated.totalPages,
                                  totalItems: _currentRun.items.length,
                                  pageSize: _paymentsPageSize,
                                  itemLabel: 'payments',
                                  onPageChanged: (newPage) {
                                    setState(() => _paymentsPage = newPage);
                                  },
                                ),
                              ],
                            ];
                          }(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaItem(String label, String value, bool isDark) {
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: textTertiaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: inkColor,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required int index,
    required String title,
    required String subtitle,
    required StepStatus status,
    required String time,
    required bool isDark,
    bool isLast = false,
  }) {
    Color iconColor;
    IconData icon;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    switch (status) {
      case StepStatus.completed:
        iconColor = FlowPayColors.primary;
        icon = Icons.check_circle_rounded;
        break;
      case StepStatus.inProgress:
        iconColor = FlowPayColors.info;
        icon = Icons.radio_button_checked_rounded;
        break;
      case StepStatus.warning:
        iconColor = FlowPayColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case StepStatus.pending:
        iconColor = textTertiaryColor;
        icon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicator column
          Column(
            children: [
              Icon(icon, color: iconColor, size: 18),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: status == StepStatus.completed
                        ? FlowPayColors.primary.withValues(alpha: 0.4)
                        : borderColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: inkColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: textTertiaryColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FlowPayTypography.captionStyle(
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeePaymentRow(PayrollItemModel item, bool isDark) {
    final isFailed = item.status == 'FAILED';
    final flag = item.country == 'NG'
        ? '🇳🇬'
        : (item.country == 'MX' ? '🇲🇽' : '🇨🇦');
    final isRetrying = _retryingEmployeeIds.contains(item.employeeId);
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.employeeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: inkColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.country == 'NG' ? 'Nigeria' : (item.country == 'MX' ? 'Mexico' : item.country)} · 1 USD = ${item.exchangeRate.toStringAsFixed(1)} ${item.targetCurrency.code}',
                    style: FlowPayTypography.captionStyle(
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.targetAmount.formatted,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: inkColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.usdAmount.formatted,
                  style: TextStyle(
                    color: textTertiaryColor,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Reused StatusBadge component for consistent chip rendering
            StatusBadge(status: item.status),

            // Public proposal reference (strictly sanitizes signatures/secrets)
            if (item.proposalId != null)
              Text(
                'Prop: ${item.proposalId!.length > 14 ? item.proposalId!.substring(0, 14) : item.proposalId}...',
                style: TextStyle(
                  color: textTertiaryColor,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),

        // Failure Details and Granular Retry Action
        if (isFailed) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlowPayColors.stateError.withValues(alpha: 0.1),
              borderRadius: FlowPayRadii.input,
              border: Border.all(
                  color: FlowPayColors.stateError.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: FlowPayColors.stateError, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'FAILURE DETAILS',
                      style: TextStyle(
                        color: FlowPayColors.stateError,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.errorReason ??
                      'Destination smart-wallet rejected proposal execution',
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FlowPayButton(
                    text:
                        isRetrying ? 'Retrying...' : 'Retry Payout via Approve',
                    variant: FlowPayButtonVariant.primary,
                    icon: Icons.refresh_rounded,
                    isLoading: isRetrying,
                    onPressed: isRetrying ? null : () => _handleRetryItem(item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum StepStatus {
  completed,
  inProgress,
  warning,
  pending,
}
