import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/design_system/states.dart';
import '../../core/repositories/mission_repository.dart';
import '../../core/state/app_state.dart';

class MoneyMissionsScreen extends StatefulWidget {
  final AppState appState;

  const MoneyMissionsScreen({super.key, required this.appState});

  @override
  State<MoneyMissionsScreen> createState() => _MoneyMissionsScreenState();
}

class _MoneyMissionsScreenState extends State<MoneyMissionsScreen> {
  List<MoneyMissionModel> missions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() => isLoading = true);
    final list = await widget.appState.missionRepo.getMissions();
    if (mounted) {
      setState(() {
        missions = list;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleMission(String id) async {
    final updated = await widget.appState.missionRepo.toggleMission(id);
    if (mounted) {
      setState(() {
        final idx = missions.indexWhere((m) => m.id == id);
        if (idx != -1) {
          missions[idx] = updated;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = isLoading
        ? const FlowPayLoadingState(message: 'Loading Money Missions...')
        : RefreshIndicator(
            onRefresh: _loadMissions,
            child: ListView(
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
                      '${missions.where((m) => m.isActive).length} Active',
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BMoniColors.offbrand900,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: m.isActive
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
                                m.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: BMoniColors.grey50,
                                ),
                              ),
                            ),
                            Switch(
                              value: m.isActive,
                              activeThumbColor: BMoniColors.brand500,
                              onChanged: (_) => _toggleMission(m.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.tagline,
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
                                m.stats,
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
            ),
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
