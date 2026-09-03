import 'package:flutter/material.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class BusinessActivityScreen extends StatelessWidget {
  final AppState appState;

  const BusinessActivityScreen({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final businessActivities = [
      {
        'title': 'Global Payroll Fan-Out',
        'desc': 'Disbursed \$4,000 USD to 2 employees in Nigeria & Mexico',
        'time': 'Today, 10:45 AM',
        'status': 'SETTLED',
      },
      {
        'title': 'Employee Onboarding Verified',
        'desc': 'Samson Jabo completed KYC via Mexico SPEI rail',
        'time': 'Yesterday',
        'status': 'LINKED',
      },
      {
        'title': 'Virtual Card Issued',
        'desc': 'Issued virtual NGN spend card for Bunch Dillon',
        'time': '3 days ago',
        'status': 'ACTIVE',
      },
    ];

    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Corporate Audit Log', style: FlowPayTypography.headingSm),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: businessActivities.length,
        itemBuilder: (ctx, i) {
          final item = businessActivities[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FlowPayCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlowPayColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.corporate_fare, color: FlowPayColors.accentLight, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title']!, style: FlowPayTypography.bodyLg),
                        const SizedBox(height: 4),
                        Text(item['desc']!, style: FlowPayTypography.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: item['status']!),
                      const SizedBox(height: 4),
                      Text(item['time']!, style: FlowPayTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
