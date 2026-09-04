import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../../core/missions/mission_intent.dart';
import '../../../core/repositories/mission_repository.dart';

class MissionCard extends StatelessWidget {
  final MoneyMissionModel mission;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTriggerManual;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onToggleActive,
    required this.onTriggerManual,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? BMoniColors.offbrand900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mission.isActive
              ? BMoniColors.brand500.withAlpha(90)
              : (isDark ? BMoniColors.offbrand700 : BMoniColors.grey200),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: mission.isActive
                ? BMoniColors.brand500.withAlpha(15)
                : Colors.black.withAlpha(5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Mission Title + Active Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mission.isActive
                      ? BMoniColors.brand500.withAlpha(35)
                      : BMoniColors.grey700.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt,
                  size: 18,
                  color: mission.isActive ? BMoniColors.brand300 : BMoniColors.grey400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? BMoniColors.grey50 : BMoniColors.grey950,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mission.tagline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BMoniColors.grey400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mission.isActive,
                activeThumbColor: BMoniColors.brand400,
                activeTrackColor: BMoniColors.brand500.withAlpha(120),
                onChanged: onToggleActive,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Condition / Rule Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? BMoniColors.offbrand800 : BMoniColors.grey100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.rule_folder_outlined, size: 14, color: BMoniColors.brand400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mission.conditionSummary.isNotEmpty
                        ? mission.conditionSummary
                        : 'Rule: Autonomous execution on BMONI rails',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? BMoniColors.grey200 : BMoniColors.grey800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Allocations Breakdown Chips
          if (mission.allocations.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mission.allocations.map((alloc) {
                Color chipBg;
                Color chipText;
                switch (alloc.category) {
                  case MissionAllocationCategory.reserve:
                    chipBg = BMoniColors.brand500.withAlpha(30);
                    chipText = BMoniColors.brand300;
                    break;
                  case MissionAllocationCategory.expenses:
                    chipBg = BMoniColors.success400.withAlpha(30);
                    chipText = BMoniColors.success400;
                    break;
                  case MissionAllocationCategory.tax:
                    chipBg = BMoniColors.accent400.withAlpha(30);
                    chipText = BMoniColors.accent400;
                    break;
                  default:
                    chipBg = BMoniColors.offbrand700;
                    chipText = BMoniColors.grey300;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: chipText.withAlpha(60), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${alloc.percentage.toInt()}% ${alloc.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: chipText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(\$${alloc.sourceAmountFormatted})',
                        style: TextStyle(
                          fontSize: 10,
                          color: chipText.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Execution Info & Status Row
          Row(
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: mission.isActive
                      ? BMoniColors.success400.withAlpha(25)
                      : BMoniColors.grey700.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mission.isActive ? BMoniColors.success400 : BMoniColors.grey400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mission.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: mission.isActive ? BMoniColors.success400 : BMoniColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mission.lastExecution != null
                      ? 'Last run: ${mission.lastExecution}'
                      : 'Never executed yet',
                  style: const TextStyle(
                    fontSize: 11,
                    color: BMoniColors.grey400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Manual Trigger Button for Hackathon Testing
              InkWell(
                onTap: mission.isActive ? onTriggerManual : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: mission.isActive
                        ? BMoniColors.brand500.withAlpha(30)
                        : BMoniColors.grey800,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: mission.isActive
                          ? BMoniColors.brand400.withAlpha(80)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 14,
                        color: mission.isActive ? BMoniColors.brand300 : BMoniColors.grey500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '⚡ Run Now',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: mission.isActive ? BMoniColors.brand300 : BMoniColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
