import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../../core/repositories/approval_repository.dart';
import '../../../core/theme/colors.dart';

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

  void _showPinApprovalDialog(BuildContext context, PendingApprovalModel approval) {
    final pinController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FlowPayColors.darkSurfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: BMoniColors.warning400, size: 22),
              SizedBox(width: 8),
              Text(
                'Authorize Action',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approval.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                approval.description,
                style: const TextStyle(fontSize: 12, color: BMoniColors.grey400),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlowPayColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlowPayColors.darkBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount to Authorize', style: TextStyle(fontSize: 12, color: BMoniColors.grey400)),
                    Text(
                      approval.amount.formatFormatted(includeSymbol: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter 6-Digit B-Key Signing PIN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BMoniColors.grey300),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 8, color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••••',
                  hintStyle: const TextStyle(color: BMoniColors.grey600, letterSpacing: 8),
                  counterText: '',
                  filled: true,
                  fillColor: FlowPayColors.darkSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: FlowPayColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BMoniColors.brand500, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BMoniColors.grey400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BMoniColors.brand500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final pin = pinController.text.trim();
                      if (pin.length == 6) {
                        setDialogState(() => isSubmitting = true);
                        Navigator.pop(ctx);
                        onApprove(approval, pin);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign & Execute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pendingApprovals.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26180B) : const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: BMoniColors.warning400.withAlpha(120),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: BMoniColors.warning400.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BMoniColors.warning400.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions, color: BMoniColors.warning400, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions Awaiting Your Approval',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : BMoniColors.grey950,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Explicit authorization required prior to BMONI execution',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? BMoniColors.grey400 : BMoniColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BMoniColors.warning400.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BMoniColors.warning400.withAlpha(70)),
                ),
                child: Text(
                  '${pendingApprovals.length} Pending',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: BMoniColors.warning400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items List
          ...pendingApprovals.map((appr) {
            IconData typeIcon = Icons.bolt;
            Color typeColor = BMoniColors.brand400;
            if (appr.type == ApprovalType.transfer) {
              typeIcon = Icons.arrow_outward;
              typeColor = BMoniColors.accent400;
            } else if (appr.type == ApprovalType.fxConversion) {
              typeIcon = Icons.currency_exchange;
              typeColor = BMoniColors.success400;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? FlowPayColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlowPayColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(typeIcon, size: 14, color: typeColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appr.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : BMoniColors.grey950,
                          ),
                        ),
                      ),
                      Text(
                        appr.amount.formatFormatted(includeSymbol: true),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BMoniColors.grey950,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appr.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? BMoniColors.grey400 : BMoniColors.grey700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () => onReject(appr),
                        child: Text(
                          'Reject',
                          style: TextStyle(fontSize: 12, color: isDark ? BMoniColors.grey400 : BMoniColors.grey600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BMoniColors.brand500,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showPinApprovalDialog(context, appr),
                        icon: const Icon(Icons.lock_outline, size: 13, color: Colors.white),
                        label: const Text(
                          'Approve (PIN)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
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
