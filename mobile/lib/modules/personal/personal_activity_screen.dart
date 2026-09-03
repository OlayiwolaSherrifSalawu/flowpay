import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/state/app_state.dart';

class PersonalActivityScreen extends StatelessWidget {
  final AppState appState;

  const PersonalActivityScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    final activities = [
      {
        'title': 'Emergency Fund Auto-Sweep',
        'desc': 'Mission executed: \$240.00 swept to high-yield NGN wallet',
        'time': '2 hours ago',
        'badge': 'COMPLETED',
        'status': FlowPayAppStatus.completed,
      },
      {
        'title': 'Transfer to Bunch Dillon',
        'desc': 'Sent \$150.00 (settled via BMONI proposal)',
        'time': 'Yesterday',
        'badge': 'SUCCESS',
        'status': FlowPayAppStatus.success,
      },
      {
        'title': 'Virtual Card Spend: AWS Cloud',
        'desc': 'Card 4289 settled \$24.50',
        'time': '3 days ago',
        'badge': 'SETTLED',
        'status': FlowPayAppStatus.completed,
      },
      {
        'title': 'FX Target Sweep (MXN)',
        'desc': 'Triggered auto-conversion on rate threshold',
        'time': '5 days ago',
        'badge': 'PENDING',
        'status': FlowPayAppStatus.pending,
      },
    ];

    Widget content = ListView.builder(
      padding: FlowPaySpacing.insetXl,
      itemCount: activities.length,
      itemBuilder: (ctx, i) {
        final a = activities[i];
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
                  child: const Icon(Icons.history, color: FlowPayColors.primaryLight, size: 20),
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['title'] as String,
                        style: FlowPayTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        a['desc'] as String,
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
                      appStatus: a['status'] as FlowPayAppStatus,
                      showDot: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a['time'] as String,
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
          title: const Text('Personal Activity'),
        ),
        body: content,
      );
    }

    return content;
  }
}
