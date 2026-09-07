import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/repositories/approval_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class PendingApprovalsCard extends StatelessWidget {
  final List<PendingApprovalModel> pendingApprovals;
  final Function(PendingApprovalModel approval, String pin) onApprove;
  final Function(PendingApprovalModel approval) onReject;

  const PendingApprovalsCard({
    super.key,
    required this.pendingApprovals,
    required this.onApprove,
    required this.onReject,
  });

  void _showPinApprovalDialog(
      BuildContext context, PendingApprovalModel approval) {
    final pinController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FlowPayColors.darkSurfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: FlowPaySpacing.borderRadiusXl,
            side: const BorderSide(color: FlowPayColors.darkBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: FlowPayColors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'Authorize Action',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approval.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                approval.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter 6-Digit B-Key Signing PIN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 8,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '••••••',
                  hintStyle: const TextStyle(
                      color: FlowPayColors.darkTextMuted, letterSpacing: 8),
                  counterText: '',
                  filled: true,
                  fillColor: FlowPayColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FlowPayColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FlowPayColors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: FlowPayColors.darkTextSecondary)),
            ),
            FlowPayButton(
              text: 'Sign & Execute',
              icon: Icons.check,
              isLoading: isSubmitting,
              size: FlowPayButtonSize.small,
              onPressed: () async {
                if (pinController.text.length == 6) {
                  setDialogState(() => isSubmitting = true);
                  Navigator.pop(ctx);
                  onApprove(approval, pinController.text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pendingApprovals.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: FlowPayColors.amber.withAlpha(18),
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: FlowPayColors.amber.withAlpha(90),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FlowPayColors.amber.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      size: 16, color: FlowPayColors.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions Awaiting Your Approval',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Explicit authorization required prior to BMONI execution',
                        style: TextStyle(
                          fontSize: 11,
                          color: FlowPayColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: FlowPayColors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FlowPayColors.amber.withAlpha(70)),
                  ),
                  child: Text(
                    '${pendingApprovals.length} Pending',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: FlowPayColors.hairline),
          ...pendingApprovals.map((approval) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          approval.title,
                          style: FlowPayTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        approval.amount.formatted,
                        style: FlowPayTypography.amount(
                          color: FlowPayColors.amber,
                        ).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    approval.description,
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => onReject(approval),
                        child: const Text('Reject',
                            style: TextStyle(
                                color: FlowPayColors.error, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      FlowPayButton(
                        text: 'Approve (PIN)',
                        icon: Icons.key_rounded,
                        size: FlowPayButtonSize.small,
                        onPressed: () =>
                            _showPinApprovalDialog(context, approval),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
