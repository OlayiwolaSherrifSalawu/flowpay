import 'package:flutter/material.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class MoneyMissionsScreen extends StatefulWidget {
  final AppState appState;

  const MoneyMissionsScreen({Key? key, required this.appState}) : super(key: key);

  @override
  State<MoneyMissionsScreen> createState() => _MoneyMissionsScreenState();
}

class _MoneyMissionsScreenState extends State<MoneyMissionsScreen> {
  final List<Map<String, dynamic>> missions = [
    {
      'id': 'm1',
      'title': '20% Emergency Fund Auto-Sweep',
      'tagline': 'Auto-sweeps 20% of incoming international USD to high-yield NGN savings.',
      'type': 'AUTO_SWEEP',
      'active': true,
      'stats': '\$1,420 swept this month',
    },
    {
      'id': 'm2',
      'title': 'Contractor Card Monthly Cap',
      'tagline': 'Enforce a strict \$500/month spending ceiling on contractor virtual cards.',
      'type': 'SPEND_CAP',
      'active': true,
      'stats': 'Protected \$2,100 from overdrafts',
    },
    {
      'id': 'm3',
      'title': 'FX Rate Alert & Dip Conversion',
      'tagline': 'Auto-convert USD to MXN when exchange rate hits favorable threshold (>18.0).',
      'type': 'FX_TARGET',
      'active': false,
      'stats': 'Standing order active',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Money Missions', style: FlowPayTypography.headingSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner
          FlowPayCard(
            backgroundColor: FlowPayColors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: FlowPayColors.primaryLight),
                    const SizedBox(width: 8),
                    Text(
                      'Your money. Your rules. AI executes.',
                      style: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.primaryLight),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Set autonomous financial directives. FlowPay monitors your multi-currency cashflow and executes deterministic BMONI operations when conditions are met.',
                  style: FlowPayTypography.bodyMd,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Active Missions', style: FlowPayTypography.headingSm),
          const SizedBox(height: 12),
          ...missions.map((m) {
            final isActive = m['active'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FlowPayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m['title'], style: FlowPayTypography.headingSm),
                        ),
                        Switch.adaptive(
                          value: isActive,
                          activeColor: FlowPayColors.primary,
                          onChanged: (val) {
                            setState(() {
                              m['active'] = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(m['tagline'], style: FlowPayTypography.bodyMd),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        StatusBadge(status: isActive ? 'ACTIVE' : 'PAUSED'),
                        const Spacer(),
                        Text(
                          m['stats'],
                          style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
