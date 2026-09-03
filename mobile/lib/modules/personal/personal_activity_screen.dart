import 'package:flutter/material.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class PersonalActivityScreen extends StatelessWidget {
  final AppState appState;

  const PersonalActivityScreen({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activities = [
      {
        'title': 'Emergency Fund Auto-Sweep',
        'desc': 'Mission executed: \$240.00 swept to high-yield NGN wallet',
        'time': '2 hours ago',
        'badge': 'MISSION_RUN',
      },
      {
        'title': 'Transfer to Bunch Dillon',
        'desc': 'Sent \$150.00 (settled via BMONI proposal)',
        'time': 'Yesterday',
        'badge': 'COMPLETED',
      },
      {
        'title': 'Virtual Card Spend: AWS Cloud',
        'desc': 'Card 4289 settled \$24.50',
        'time': '3 days ago',
        'badge': 'SETTLED',
      },
    ];

    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Personal Activity', style: FlowPayTypography.headingSm),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: activities.length,
        itemBuilder: (ctx, i) {
          final a = activities[i];
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
                    child: const Icon(Icons.history, color: FlowPayColors.primaryLight, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['title']!, style: FlowPayTypography.bodyLg),
                        const SizedBox(height: 4),
                        Text(a['desc']!, style: FlowPayTypography.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: a['badge']!),
                      const SizedBox(height: 4),
                      Text(a['time']!, style: FlowPayTypography.caption),
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
