import 'package:flutter/material.dart';
import '../../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../../core/design_system/amount_display.dart';
import '../../../core/repositories/payroll_repository.dart';
import '../../../core/state/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/typography.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';

/// Modal Bottom Sheet displaying in-depth Payroll Run Detail and Audit Trail.
/// Conforms strictly to FlowPay safety directives:
/// - Never surfaces hashToSign, signature, private key material, or webhook secrets.
/// - Surfaces public/audit references (FlowPay reference, BMONI proposal ID, tx hash).
/// - Uses bkey_uikit's ActivitySectionCard and StatusText components.
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
          'Enter your 6-digit B-Key PIN to retry disbursement for ${item.employeeName}',
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
              'Successfully retried payment for ${item.employeeName}. Settled on ${item.destinationStablecoin} rail.',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
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
    final flowpayRef =
        'FP-PAY-${_currentRun.runId.length > 8 ? _currentRun.runId.substring(_currentRun.runId.length - 8) : _currentRun.runId}';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: FlowPayColors.canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: FlowPayColors.hairline),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: FlowPayColors.hairline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FlowPayColors.brand500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long,
                          color: FlowPayColors.brand400, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentRun.title,
                            style: FlowPayTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: FlowPayColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${_currentRun.runId} · ${_formatDate(_currentRun.executedAt)}',
                            style: FlowPayTypography.caption.copyWith(
                              color: FlowPayColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusText.fromStatusString(_currentRun.status),
                  ],
                ),
              ),
              const Divider(
                  height: 1, thickness: 1, color: FlowPayColors.hairline),

              // Scrollable Content Area
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section 1: Financial Summary Card (using ActivitySectionCard)
                    ActivitySectionCard(
                      header: const SectionHeader(
                        title: 'Payroll Summary',
                        trailing: Icon(Icons.analytics_outlined,
                            color: FlowPayColors.darkTextSecondary, size: 18),
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
                                    style: FlowPayTypography.caption.copyWith(
                                      color: FlowPayColors.darkTextSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FlowPayAmountDisplay(
                                    amount:
                                        _currentRun.totalUsd.formatFormatted(),
                                    size: AmountDisplaySize.large,
                                    color: FlowPayColors.ink,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'BMONI FEES',
                                    style: FlowPayTypography.caption.copyWith(
                                      color: FlowPayColors.darkTextSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentRun.totalFeeUsd.formatted,
                                    style:
                                        FlowPayTypography.titleMedium.copyWith(
                                      color: FlowPayColors.accent,
                                      fontWeight: FontWeight.w700,
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
                                  FlowPayColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: FlowPayColors.accent
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings_outlined,
                                    color: FlowPayColors.accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saved ${_currentRun.totalSavedFeeUsd.formatted} (${_currentRun.savedPercentage.toStringAsFixed(0)}% vs SWIFT Wire)',
                                        style: FlowPayTypography.bodySmall
                                            .copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: FlowPayColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'One aggregate USD bill fan-out saved \$170/country compared to traditional wires.',
                                        style:
                                            FlowPayTypography.caption.copyWith(
                                          color:
                                              FlowPayColors.darkTextSecondary,
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
                              _buildMetaItem('FlowPay Reference', flowpayRef),
                              _buildMetaItem(
                                'BMONI Batch Ref',
                                _currentRun.items.isNotEmpty &&
                                        _currentRun.items.first.proposalId !=
                                            null
                                    ? (_currentRun.items.first.proposalId!
                                                .length >
                                            16
                                        ? '${_currentRun.items.first.proposalId!.substring(0, 16)}...'
                                        : _currentRun.items.first.proposalId!)
                                    : 'BMONI-BATCH-${_currentRun.runId.hashCode.abs().toString().substring(0, 6)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Execution Timeline Card
                    ActivitySectionCard(
                      header: const SectionHeader(
                        title: 'Orchestration Timeline',
                        trailing: Icon(Icons.timeline,
                            color: FlowPayColors.darkTextSecondary, size: 18),
                      ),
                      child: Column(
                        children: [
                          _buildTimelineStep(
                            index: 1,
                            title: 'Rail Validation',
                            subtitle:
                                'Pre-validated employee smart-wallet addresses & active rails (CNGN, MEXe)',
                            status: StepStatus.completed,
                            time: '0.2s',
                          ),
                          _buildTimelineStep(
                            index: 2,
                            title: 'B-Key On-Device PIN Approval',
                            subtitle:
                                'Employer approved proposal batch via hardware Secure Enclave',
                            status: StepStatus.completed,
                            time: '1.1s',
                          ),
                          _buildTimelineStep(
                            index: 3,
                            title: 'Multi-Country Fan-Out',
                            subtitle:
                                'Orchestrated parallel disbursements via BMONI transfer primitives',
                            status: _currentRun.status == 'PROCESSING'
                                ? StepStatus.inProgress
                                : StepStatus.completed,
                            time: '2.4s',
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
                          style: FlowPayTypography.caption.copyWith(
                            color: FlowPayColors.darkTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < _currentRun.items.length;
                              i++) ...[
                            _buildEmployeePaymentRow(_currentRun.items[i]),
                            if (i < _currentRun.items.length - 1)
                              const Divider(
                                  height: 20,
                                  thickness: 1,
                                  color: FlowPayColors.hairline),
                          ],
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

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.darkTextSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: FlowPayTypography.bodySmall.copyWith(
            color: FlowPayColors.ink,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
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
    bool isLast = false,
  }) {
    Color iconColor;
    IconData icon;

    switch (status) {
      case StepStatus.completed:
        iconColor = FlowPayColors.accent;
        icon = Icons.check_circle;
        break;
      case StepStatus.inProgress:
        iconColor = FlowPayColors.info;
        icon = Icons.radio_button_checked;
        break;
      case StepStatus.warning:
        iconColor = FlowPayColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case StepStatus.pending:
        iconColor = FlowPayColors.darkTextTertiary;
        icon = Icons.radio_button_unchecked;
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
                        ? FlowPayColors.accent.withValues(alpha: 0.4)
                        : FlowPayColors.hairline,
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
                        style: FlowPayTypography.bodySmall.copyWith(
                          color: FlowPayColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        time,
                        style: FlowPayTypography.caption.copyWith(
                          color: FlowPayColors.darkTextTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.darkTextSecondary,
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

  Widget _buildEmployeePaymentRow(PayrollItemModel item) {
    final isFailed = item.status == 'FAILED';
    final flag = item.country == 'NG'
        ? '🇳🇬'
        : (item.country == 'MX' ? '🇲🇽' : '🇨🇦');
    final isRetrying = _retryingEmployeeIds.contains(item.employeeId);

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
                    style: FlowPayTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FlowPayColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.destinationStablecoin} (${item.country} Rail) · 1 USD = ${item.exchangeRate.toStringAsFixed(1)} ${item.targetCurrency.code}',
                    style: FlowPayTypography.caption.copyWith(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.targetAmount.formatted} ${item.destinationStablecoin}',
                  style: FlowPayTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FlowPayColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.usdAmount.formatted,
                  style: FlowPayTypography.caption.copyWith(
                    color: FlowPayColors.darkTextTertiary,
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
            // Reused StatusText component for consistent chip rendering
            StatusText.fromStatusString(item.status),

            // Public proposal reference (strictly sanitizes signatures/secrets)
            if (item.proposalId != null)
              Text(
                'Prop: ${item.proposalId!.length > 14 ? item.proposalId!.substring(0, 14) : item.proposalId}...',
                style: FlowPayTypography.caption.copyWith(
                  color: FlowPayColors.darkTextTertiary,
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
              color: FlowPayColors.stateError.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: FlowPayColors.stateError.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: FlowPayColors.stateError, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'FAILURE DETAILS',
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.stateError,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.errorReason ??
                      'Destination smart-wallet rejected proposal execution',
                  style: FlowPayTypography.caption.copyWith(
                    color: FlowPayColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FlowPayButton(
                    text:
                        isRetrying ? 'Retrying...' : 'Retry Payout via Approve',
                    variant: FlowPayButtonVariant.primary,
                    icon: Icons.refresh,
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
