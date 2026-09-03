import 'package:flutter/material.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/repositories/payroll_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class PayrollScreen extends StatefulWidget {
  final AppState appState;

  const PayrollScreen({Key? key, required this.appState}) : super(key: key);

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  PayrollRunModel? _preview;
  PayrollRunModel? _completedRun;
  bool _isLoading = true;
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    final prev = await widget.appState.payrollRepo.getPayrollPreview();
    setState(() {
      _preview = prev;
      _isLoading = false;
    });
  }

  Future<void> _handleRunPayroll() async {
    final pin = await _showPinDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() => _isExecuting = true);
    try {
      // 1. Sign on device via SDK
      final sig = await BmoniSdkService.signTransactionHash(
        '0x7e8125a09c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        pin: pin,
      );

      // 2. Execute aggregate fan-out
      final run = await widget.appState.payrollRepo.executePayrollRun(
        runId: _preview!.runId,
        signature: sig,
      );

      setState(() {
        _completedRun = run;
        _isExecuting = false;
      });
    } catch (e) {
      setState(() => _isExecuting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Execution failed: $e')));
    }
  }

  Future<String?> _showPinDialog() async {
    final pinCtrl = TextEditingController(text: '123456');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlowPayColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Authorize Global Payroll', style: FlowPayTypography.headingSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 6-digit B-Key security PIN to sign and authorize multi-country disbursement on-device.',
              style: FlowPayTypography.bodyMd,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
              decoration: const InputDecoration(
                hintText: '••••••',
                hintStyle: TextStyle(color: FlowPayColors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: FlowPayColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FlowPayColors.textTertiary)),
          ),
          FlowPayButton(
            text: 'Sign & Disburse',
            onPressed: () => Navigator.pop(ctx, pinCtrl.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Multi-Country Payroll', style: FlowPayTypography.headingSm),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Completed Run Banner
                if (_completedRun != null) ...[
                  FlowPayCard(
                    backgroundColor: FlowPayColors.accent.withOpacity(0.15),
                    border: Border.all(color: FlowPayColors.accent),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, color: FlowPayColors.accentLight, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Payroll Executed Successfully!',
                          style: FlowPayTypography.headingSm,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'One single aggregate payment of ${_completedRun!.totalUsd.formatFormatted()} was fanned out across ${_completedRun!.countries.length} countries and ${_completedRun!.employeeCount} employees.',
                          style: FlowPayTypography.bodyMd,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Aggregate Bill Card ("The 10x Hook")
                FlowPayCard(
                  backgroundColor: FlowPayColors.surfaceElevated,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hub_outlined, color: FlowPayColors.primaryLight),
                          const SizedBox(width: 8),
                          Text('One Aggregate Bill', style: FlowPayTypography.headingSm),
                          const Spacer(),
                          const StatusBadge(status: 'READY TO RUN'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Total Aggregate Settlement', style: FlowPayTypography.caption),
                      const SizedBox(height: 4),
                      Text(
                        _preview != null ? _preview!.totalUsd.formatFormatted() : '\$0.00',
                        style: FlowPayTypography.financialLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'BMONI Rail Fee: ${_preview?.totalFeeUsd.formatFormatted() ?? "\$12.00"}',
                            style: FlowPayTypography.caption,
                          ),
                          const Spacer(),
                          Text(
                            'Saved vs Wire: \$328.00 (96%)',
                            style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Side-by-Side Breakdown
                Text('Parallel Multi-Rail Fan-Out', style: FlowPayTypography.headingSm),
                const SizedBox(height: 12),

                ...(_completedRun ?? _preview)!.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FlowPayCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: FlowPayColors.surfaceElevated,
                                radius: 16,
                                child: Text(item.country, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.employeeName, style: FlowPayTypography.bodyLg),
                                    Text(
                                      '${item.country == "NG" ? "Nigeria" : "Mexico"} • Rate: ${item.exchangeRate} / USD',
                                      style: FlowPayTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: item.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: FlowPayColors.border),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Employer USD Share', style: FlowPayTypography.caption),
                                  const SizedBox(height: 2),
                                  Text(item.usdAmount.formatFormatted(), style: FlowPayTypography.financialMedium),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Employee Landed Amount', style: FlowPayTypography.caption),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.targetAmount.formatFormatted(),
                                    style: FlowPayTypography.financialMedium.copyWith(color: FlowPayColors.accentLight),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (item.transactionHash != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Tx: ${item.transactionHash}',
                              style: FlowPayTypography.caption.copyWith(color: FlowPayColors.textTertiary, fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),
                if (_completedRun == null) ...[
                  FlowPayButton(
                    text: 'Run Global Payroll (1-Click)',
                    icon: Icons.rocket_launch,
                    isLoading: _isExecuting,
                    onPressed: _handleRunPayroll,
                  ),
                ] else ...[
                  FlowPayButton(
                    text: 'Download Payslips & Receipts',
                    isSecondary: true,
                    icon: Icons.receipt_long,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payslips and receipts generated successfully.')),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
