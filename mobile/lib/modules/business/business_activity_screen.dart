import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/state/app_state.dart';

class BusinessActivityScreen extends StatelessWidget {
  final AppState appState;

  const BusinessActivityScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    final businessActivities = [
      {
        'title': 'Global Payroll Fan-Out',
        'desc': 'Disbursed \$4,000 USD to 2 employees in Nigeria & Mexico',
        'time': 'Today, 10:45 AM',
        'status': FlowPayAppStatus.completed,
      },
      {
        'title': 'Employee Onboarding Verified',
        'desc': 'Samson Jabo completed KYC via Mexico SPEI rail',
        'time': 'Yesterday',
        'status': FlowPayAppStatus.success,
      },
      {
        'title': 'Virtual Card Issued',
        'desc': 'Issued virtual NGN spend card for Bunch Dillon',
        'time': '3 days ago',
        'status': FlowPayAppStatus.completed,
      },
      {
        'title': 'Compliance Tax Filing',
        'desc': 'Submitted aggregate FX compliance ledger',
        'time': '1 week ago',
        'status': FlowPayAppStatus.pending,
      },
    ];

    Widget content = ListView.builder(
      padding: FlowPaySpacing.insetXl,
      itemCount: businessActivities.length,
      itemBuilder: (ctx, i) {
        final item = businessActivities[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: FlowPaySpacing.md),
          child: FlowPayCard(
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
                  child: const Icon(Icons.corporate_fare,
                      color: FlowPayColors.accentLight, size: 20),
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: FlowPayTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['desc'] as String,
                        style: FlowPayTypography.caption.copyWith(
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FlowPaySpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FlowPayStatusBadge(
                      appStatus: item['status'] as FlowPayAppStatus,
                      showDot: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['time'] as String,
                      style: FlowPayTypography.caption.copyWith(
                        color: isDark
                            ? FlowPayColors.darkTextTertiary
                            : FlowPayColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Corporate Audit Log'),
        ),
        body: content,
      );
    }

    return content;
  }
}
