import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/state/app_state.dart';

class MoneyMissionsScreen extends StatefulWidget {
  final AppState appState;

  const MoneyMissionsScreen({super.key, required this.appState});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // 10x Banner Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF421045), Color(0xFF220824)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BMoniColors.brand500.withAlpha(90)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: BMoniColors.brand400, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Your money. Your rules. AI executes.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: BMoniColors.brand300,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Set autonomous financial directives. FlowPay monitors your multi-currency cashflow and executes deterministic BMONI operations when conditions are met.',
                style: TextStyle(
                  fontSize: 13,
                  color: BMoniColors.grey300,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SectionHeader(
          title: 'Active Autonomous Missions',
          backgroundColor: Colors.transparent,
          showBottomDivider: false,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          titleStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? BMoniColors.grey50 : BMoniColors.grey950,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BMoniColors.accent400.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BMoniColors.accent400.withAlpha(70)),
            ),
            child: Text(
              '${missions.where((m) => m['active'] == true).length} Active',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: BMoniColors.accent400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        ...missions.map((m) {
          final isActive = m['active'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BMoniColors.offbrand900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? BMoniColors.brand500.withAlpha(80)
                    : BMoniColors.offbrand700,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m['title'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: BMoniColors.grey50,
                        ),
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeThumbColor: BMoniColors.brand500,
                      onChanged: (v) {
                        setState(() => m['active'] = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  m['tagline'],
                  style: const TextStyle(fontSize: 12, color: BMoniColors.grey400, height: 1.3),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BMoniColors.offbrand800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 14, color: BMoniColors.brand400),
                      const SizedBox(width: 6),
                      Text(
                        m['stats'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BMoniColors.brand300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        BMoniButton(
          text: '+ Create New Mission',
          variant: BMoniButtonVariant.secondary,
          size: BMoniButtonSize.large,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening AI Money Mission Builder...')),
            );
          },
        ),
      ],
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Money Missions'),
        ),
        body: content,
      );
    }

    return content;
  }
}
