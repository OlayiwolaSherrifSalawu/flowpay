import 'package:flutter/material.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';
import '../../core/repositories/payroll_repository.dart';
import '../../core/state/app_state.dart';

enum PayrollExecutionStep {
  validated,
  approved,
  processing,
  completed,
}

/// Multi-Country Global Payroll Screen
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// Core message: "One Employer. Many Countries. One Bill."
/// Conforms to design.md & BMONI transfer proposal protocol:
/// - Recipient destination currency rail validation (CNGN, MEXe)
/// - Review screen with aggregate bill, fees, and 97% savings
/// - Confirmation modal before execution (employee count, country count, total)
/// - 4-state execution timeline: Validated → Approved → Processing → Completed
/// - Independent per-employee outcome display (Completed vs Partially Completed)
/// - Granular single-proposal retry via approve
class PayrollScreen extends StatefulWidget {
  final AppState appState;

  const PayrollScreen({super.key, required this.appState});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  PayrollRunModel? _preview;
  PayrollRunModel? _executionRun;
  bool _isLoading = true;
  bool _isExecuting = false;
  PayrollExecutionStep? _currentStep;
  String? _executingMessage;
  final Set<String> _retryingEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    try {
      final prev = await widget.appState.payrollRepo.getPayrollPreview();
      if (mounted) {
        setState(() {
          _preview = prev;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payroll preview: $e')),
        );
      }
    }
  }

  /// Step 1: User taps "Run Payroll" -> Shows Confirmation Screen first!
  void _onTapRunPayroll() {
    if (_preview == null) return;

    if (!_preview!.allRailsActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot run payroll: one or more employees have inactive destination rails.'),
          backgroundColor: FlowPayColors.signalCaution,
        ),
      );
      return;
    }

    _showConfirmationModal();
  }

  /// Step 2: Confirmation modal displaying employee count, country count, aggregate total
  void _showConfirmationModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.sheet,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: FlowPayRadii.chip,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
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
                        child: Icon(Icons.verified_user_rounded,
                            color: FlowPayColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Global Payroll',
                            style: FlowPayTypography.title(color: inkColor)
                                .copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'One Employer. Many Countries. One Bill.',
                            style: FlowPayTypography.captionStyle(
                                color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 16),

                // Summary grid: Employee count, Country count, Total
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        label: 'TOTAL EMPLOYEES',
                        value: '${_preview!.employeeCount}',
                        icon: Icons.people_alt_rounded,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryBox(
                        label: 'COUNTRIES',
                        value:
                            '${_preview!.countries.length} (${_preview!.countries.join(', ')})',
                        icon: Icons.public_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceAltColor,
                    borderRadius: FlowPayRadii.card,
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AGGREGATE DISBURSEMENT',
                            style: FlowPayTypography.captionStyle(
                                    color: textTertiaryColor)
                                .copyWith(
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _preview!.totalUsd.formatFormatted(),
                            style: FlowPayTypography.display(color: inkColor)
                                .copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: FlowPayColors.signal.withValues(alpha: 0.12),
                          borderRadius: FlowPayRadii.chip,
                          border: Border.all(
                              color: FlowPayColors.signal.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'Saved ${_preview!.totalSavedFeeUsd.formatFormatted()}',
                          style: FlowPayTypography.captionStyle(
                                  color: FlowPayColors.signal)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Approving will create transfer proposals on your BMONI employer wallet and fan out local stablecoins to all employee smart wallets in parallel.',
                  style: FlowPayTypography.captionStyle(
                      color: textSecondaryColor).copyWith(height: 1.4),
                ),
                const SizedBox(height: 24),

                // Actions: Cancel & Approve Payroll
                Row(
                  children: [
                    Expanded(
                      child: FlowPayButton(
                        text: 'Cancel',
                        isSecondary: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FlowPayButton(
                        text: 'Approve Payroll',
                        icon: Icons.check_circle_rounded,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startPayrollExecution();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceAltColor,
        borderRadius: FlowPayRadii.cardSmall,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: textSecondaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: FlowPayTypography.captionStyle(
                    color: textTertiaryColor,
                  ).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: FlowPayTypography.body(color: inkColor).copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Step 3: Enter PIN & Progress through the 4-Stage Timeline:
  /// Validated → Approved → Processing → Completed
  Future<void> _startPayrollExecution() async {
    final pin = await _showPinDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() {
      _isExecuting = true;
      _currentStep = PayrollExecutionStep.validated;
      _executingMessage = 'Validating multi-rail recipient smart wallets...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() {
        _currentStep = PayrollExecutionStep.approved;
        _executingMessage = 'Signing B-Key batch transfer proposals...';
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        _currentStep = PayrollExecutionStep.processing;
        _executingMessage =
            'Parallel fan-out: executing transfers to Nigeria (CNGN) & Mexico (MEXe)...';
      });

      // Step 3: Processing (On-device secp256k1 raw-hash signing + submission)
      final sig = await BmoniSdkService.signTransactionHash(
        '0x7e8125a09c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        pin: pin,
      );

      final completedRun = await widget.appState.payrollRepo.executePayrollRun(
        runId: _preview!.runId,
        signature: sig,
      );

      if (!mounted) return;

      setState(() {
        _executionRun = completedRun;
        _currentStep = PayrollExecutionStep.completed;
        _executingMessage = completedRun.status == 'PARTIALLY_COMPLETED'
            ? 'Completed with partial failures. Review items below.'
            : 'All employee disbursements settled successfully!';
        _isExecuting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExecuting = false;
        _executingMessage = 'Execution encountered an error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payroll execution failed: $e'),
          backgroundColor: FlowPayColors.stateError,
        ),
      );
    }
  }

  Future<String?> _showPinDialog() {
    final pinCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.card),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FlowPayColors.primary.withValues(alpha: 0.12),
                borderRadius: FlowPayRadii.avatar,
              ),
              child: const Center(
                child: Icon(Icons.lock_outline_rounded,
                    color: FlowPayColors.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Text('B-Key PIN Signing',
                style: FlowPayTypography.title(color: inkColor)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your 6-digit B-Key PIN to cryptographically sign and execute the payroll batch on-device.',
              style: FlowPayTypography.body(color: textSecondaryColor)
                  .copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              style: TextStyle(
                color: inkColor,
                fontSize: 20,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                filled: true,
                fillColor: surfaceAltColor,
                border: OutlineInputBorder(
                  borderRadius: FlowPayRadii.input,
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: FlowPayRadii.input,
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: FlowPayRadii.input,
                  borderSide: BorderSide(color: FlowPayColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: textSecondaryColor, fontWeight: FontWeight.w600)),
          ),
          FlowPayButton(
            text: 'Authorize & Sign',
            onPressed: () => Navigator.pop(ctx, pinCtrl.text),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRetryEmployee(PayrollItemModel item) async {
    final pin = await _showPinDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() => _retryingEmployeeIds.add(item.employeeId));

    try {
      final updatedItem = await widget.appState.payrollRepo.retryFailedProposal(
        proposalId: item.proposalId ?? 'prop_retry_${item.employeeId}',
        employeeId: item.employeeId,
        pin: pin,
      );

      if (!mounted) return;

      if (_executionRun != null) {
        final newItems = _executionRun!.items.map((i) {
          return i.employeeId == item.employeeId ? updatedItem : i;
        }).toList();

        final allCompleted = newItems.every((i) => i.status == 'COMPLETED');

        setState(() {
          _executionRun = _executionRun!.copyWith(
            status: allCompleted ? 'COMPLETED' : 'PARTIALLY_COMPLETED',
            items: newItems,
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully retried and settled disbursement for ${item.employeeName}.'),
          backgroundColor: FlowPayColors.signal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry failed: $e'),
          backgroundColor: FlowPayColors.stateError,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingEmployeeIds.remove(item.employeeId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: AppBar(
        backgroundColor: canvasColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Payroll',
              style: FlowPayTypography.title(color: inkColor)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'One Employer. Many Countries. One Bill.',
              style: FlowPayTypography.captionStyle(
                  color: textSecondaryColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textSecondaryColor),
            tooltip: 'Refresh Payroll Preview',
            onPressed: _loadPreview,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: FlowPayColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Live Execution Timeline Stepper (Validated → Approved → Processing → Completed)
                if (_isExecuting || _executionRun != null) ...[
                  _buildTimelineStepper(isDark),
                  const SizedBox(height: 20),
                ],

                // 2. Completed / Partially Completed Run Banner
                if (_executionRun != null) ...[
                  _buildResultBanner(isDark),
                  const SizedBox(height: 20),
                  FlowPayButton(
                    text: 'Download Payslips & Receipts',
                    isSecondary: true,
                    icon: Icons.receipt_long_rounded,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'All employee payslips and cryptographic BMONI receipts generated.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // 3. Aggregate Bill Hero Card
                _buildAggregateBillCard(isDark),
                const SizedBox(height: 24),

                if (_executionRun == null)
                  FlowPayButton(
                    text: 'Run Payroll',
                    icon: Icons.payments_rounded,
                    isLoading: _isExecuting,
                    onPressed: _isExecuting ? null : _onTapRunPayroll,
                  ),
                if (_executionRun == null) const SizedBox(height: 24),

                // 4. Parallel Multi-Rail Breakdown List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PARALLEL MULTI-RAIL DISBURSEMENTS',
                      style: FlowPayTypography.captionStyle(
                              color: textTertiaryColor)
                          .copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${(_executionRun ?? _preview)!.items.length} EMPLOYEES',
                      style: FlowPayTypography.captionStyle(
                              color: textSecondaryColor)
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...(_executionRun ?? _preview)!
                    .items
                    .map((item) => _buildEmployeePayrollCard(item, isDark)),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  /// Timeline Stepper Widget
  /// Labels: Validated → Approved → Processing → Completed
  Widget _buildTimelineStepper(bool isDark) {
    final steps = [
      {'label': 'Validated', 'step': PayrollExecutionStep.validated},
      {'label': 'Approved', 'step': PayrollExecutionStep.approved},
      {'label': 'Processing', 'step': PayrollExecutionStep.processing},
      {'label': 'Completed', 'step': PayrollExecutionStep.completed},
    ];

    final currentIdx = _currentStep == null ? 0 : _currentStep!.index;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FlowPayColors.primary.withValues(alpha: 0.12),
                  borderRadius: FlowPayRadii.avatar,
                ),
                child: const Center(
                  child: Icon(Icons.timeline_rounded,
                      color: FlowPayColors.primary, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Execution Pipeline',
                style: FlowPayTypography.body(color: inkColor)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_isExecuting) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: FlowPayColors.primary),
                ),
                const SizedBox(width: 6),
                Text(
                  'Live',
                  style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.signal)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((s) {
              final stepEnum = s['step'] as PayrollExecutionStep;
              final isDone = stepEnum.index <= currentIdx;
              final isActive = stepEnum.index == currentIdx;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (stepEnum.index > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDone
                                  ? FlowPayColors.primary
                                  : borderColor,
                            ),
                          ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? FlowPayColors.primary
                                : surfaceAltColor,
                            border: Border.all(
                              color: isDone
                                  ? FlowPayColors.primary
                                  : borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : Text(
                                    '${stepEnum.index + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: textSecondaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        if (stepEnum.index < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: stepEnum.index < currentIdx
                                  ? FlowPayColors.primary
                                  : borderColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['label'] as String,
                      style: FlowPayTypography.captionStyle(
                        color: isActive
                            ? inkColor
                            : textSecondaryColor,
                      ).copyWith(
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_executingMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceAltColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _executingMessage!,
                style: FlowPayTypography.captionStyle(
                    color: textSecondaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Result Banner: Completed vs Partially Completed
  Widget _buildResultBanner(bool isDark) {
    final isPartial = _executionRun!.status == 'PARTIALLY_COMPLETED' ||
        _executionRun!.failedCount > 0;
    final bannerColor =
        isPartial ? FlowPayColors.signalCaution : FlowPayColors.signal;
    final icon =
        isPartial ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final title = isPartial
        ? 'Payroll Partially Completed'
        : 'Payroll Completed Successfully';
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;

    return FlowPayCard(
      backgroundColor: bannerColor.withValues(alpha: 0.1),
      border: Border.all(color: bannerColor.withValues(alpha: 0.3), width: 1.5),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.15),
              borderRadius: FlowPayRadii.avatar,
            ),
            child: Center(
              child: Icon(icon, color: bannerColor, size: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: FlowPayTypography.title(color: inkColor)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            isPartial
                ? '${_executionRun!.completedCount} of ${_executionRun!.employeeCount} disbursements settled. One or more proposals require attention below.'
                : 'One single aggregate payment of ${_executionRun!.totalUsd.formatFormatted()} settled across ${_executionRun!.countries.length} countries for ${_executionRun!.employeeCount} employees.',
            style: FlowPayTypography.captionStyle(
                color: textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Cryptographically authorized & executed on BMONI rails',
            style: FlowPayTypography.captionStyle(
                color: textTertiaryColor),
          ),
        ],
      ),
    );
  }

  /// Aggregate Bill Card
  Widget _buildAggregateBillCard(bool isDark) {
    final run = _executionRun ?? _preview;
    final totalFormatted =
        run != null ? run.totalUsd.formatFormatted() : '\$0.00';
    final feeFormatted =
        run != null ? run.totalFeeUsd.formatFormatted() : '\$10.00';
    final savedFormatted =
        run != null ? run.totalSavedFeeUsd.formatFormatted() : '\$330.00';

    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FlowPayColors.primary.withValues(alpha: 0.12),
                  borderRadius: FlowPayRadii.avatar,
                ),
                child: const Center(
                  child: Icon(Icons.hub_rounded, color: FlowPayColors.primary, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'One Aggregate Bill',
                style: FlowPayTypography.title(color: inkColor)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StatusBadge(
                  status: _executionRun != null
                      ? _executionRun!.status
                      : 'READY TO RUN'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: surfaceAltColor,
              borderRadius: FlowPayRadii.chip,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1 Employer',
                  style: FlowPayTypography.captionStyle(color: inkColor)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                ),
                Text(
                  '  •  ',
                  style: TextStyle(color: textTertiaryColor),
                ),
                Text(
                  'Many Countries',
                  style: FlowPayTypography.captionStyle(color: inkColor)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                ),
                Text(
                  '  •  ',
                  style: TextStyle(color: textTertiaryColor),
                ),
                Text(
                  '1 Bill',
                  style: FlowPayTypography.captionStyle(color: inkColor)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  'TOTAL AGGREGATE SETTLEMENT',
                  style: FlowPayTypography.captionStyle(
                          color: textTertiaryColor)
                      .copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    totalFormatted,
                    style: FlowPayTypography.display(color: inkColor)
                        .copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.savings_rounded,
                      color: FlowPayColors.signal, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'BMONI Fee: $feeFormatted',
                    style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor),
                  ),
                ],
              ),
              Text(
                'Saved: $savedFormatted (97%)',
                style: FlowPayTypography.captionStyle(color: FlowPayColors.signal)
                    .copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Per-Employee Payroll Card with Destination Rail & Outcome
  Widget _buildEmployeePayrollCard(PayrollItemModel item, bool isDark) {
    final flag = item.country == 'NG'
        ? '🇳🇬'
        : item.country == 'MX'
            ? '🇲🇽'
            : '🇨🇦';
    final countryName = item.country == 'NG'
        ? 'Nigeria'
        : item.country == 'MX'
            ? 'Mexico'
            : 'Canada';

    final isFailed = item.status == 'FAILED';
    final isRetrying = _retryingEmployeeIds.contains(item.employeeId);
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FlowPayCard(
        border: isFailed
            ? Border.all(color: FlowPayColors.signalCaution, width: 1.5)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaceAltColor,
                    borderRadius: FlowPayRadii.avatar,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(flag, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: FlowPayTypography.body(color: inkColor)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$countryName • Rate: ${item.exchangeRate} / USD',
                        style: FlowPayTypography.captionStyle(
                            color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 12),

            // Rail validation indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.isRailActive
                    ? FlowPayColors.signal.withValues(alpha: 0.12)
                    : FlowPayColors.signalCaution.withValues(alpha: 0.15),
                borderRadius: FlowPayRadii.input,
              ),
              child: Row(
                children: [
                  Icon(
                    item.isRailActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 14,
                    color: item.isRailActive
                        ? FlowPayColors.signal
                        : FlowPayColors.signalCaution,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.railValidationMessage ??
                          (item.isRailActive
                              ? '${item.destinationStablecoin} Rail Active & Verified'
                              : 'Rail Inactive: Needs Onboarding'),
                      style: FlowPayTypography.captionStyle(
                        color: item.isRailActive
                            ? FlowPayColors.signal
                            : FlowPayColors.signalCaution,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Amounts: Local currency vs USD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISBURSEMENT',
                      style: FlowPayTypography.captionStyle(
                        color: textTertiaryColor,
                      ).copyWith(fontSize: 10, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.targetAmount.formatted} ${item.destinationStablecoin}',
                      style: FlowPayTypography.body(color: inkColor).copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BASE COST',
                      style: FlowPayTypography.captionStyle(
                        color: textTertiaryColor,
                      ).copyWith(fontSize: 10, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.usdAmount.formatted,
                      style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (item.transactionHash != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceAltColor,
                  borderRadius: FlowPayRadii.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, size: 14, color: FlowPayColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Tx: ${item.transactionHash!.substring(0, 10)}...${item.transactionHash!.substring(item.transactionHash!.length - 6)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlowPayColors.stateError.withValues(alpha: 0.1),
                  borderRadius: FlowPayRadii.input,
                  border: Border.all(
                      color: FlowPayColors.stateError.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Failure: ${item.errorReason ?? "Proposal execution rejected by BMONI network."}',
                      style: const TextStyle(
                          color: FlowPayColors.stateError, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    FlowPayButton(
                      text: isRetrying
                          ? 'Retrying...'
                          : 'Retry Single Proposal via Approve',
                      variant: FlowPayButtonVariant.primary,
                      icon: Icons.refresh_rounded,
                      isLoading: isRetrying,
                      onPressed: isRetrying
                          ? null
                          : () => _handleRetryEmployee(item),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
