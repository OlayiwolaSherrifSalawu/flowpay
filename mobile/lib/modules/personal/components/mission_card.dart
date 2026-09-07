import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/money/currency.dart';
import '../../../core/repositories/mission_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

/// FlowPay Money Mission Card
/// Premium Money Mission card displaying status, progress bar, rule specifications,
/// and fast execution controls.
class MissionCard extends StatelessWidget {
  final MoneyMissionModel mission;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTriggerManual;
  final VoidCallback? onEdit;
  final VoidCallback? onViewActivity;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onToggleActive,
    required this.onTriggerManual,
    this.onEdit,
    this.onViewActivity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Extract allocations summary
    final allocations = mission.allocations;
    final primaryAllocation =
        allocations.isNotEmpty ? allocations.first : null;
    final allocPercent =
        (mission.percentage ?? (primaryAllocation?.percentage ?? 20)).toInt();
    final sourceCur = (mission.targetCurrency ?? Currency.usd).code;
    final destTarget =
        primaryAllocation?.destinationWalletTag ?? 'Smart Vault';

    // Mock progress calculation based on execution count for real visual feedback
    const executionCount = 3;
    final currentAmount = (executionCount * 300.0).clamp(0.0, 2000.0);
    const targetAmount = 2000.0;
    final progressFraction = (currentAmount / targetAmount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: mission.isActive
              ? FlowPayColors.primary.withAlpha(90)
              : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: mission.isActive
                ? FlowPayColors.primary.withAlpha(15)
                : const Color(0x06000000),
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
                      ? FlowPayColors.primary.withAlpha(35)
                      : FlowPayColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt,
                  size: 20,
                  color: mission.isActive
                      ? FlowPayColors.primary
                      : FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            mission.title,
                            style: FlowPayTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? FlowPayColors.darkTextPrimary
                                  : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: mission.isActive
                                ? FlowPayColors.primary.withAlpha(30)
                                : FlowPayColors.darkSurfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: mission.isActive
                                  ? FlowPayColors.primary.withAlpha(70)
                                  : FlowPayColors.darkBorder,
                            ),
                          ),
                          child: Text(
                            mission.isActive ? 'ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: mission.isActive
                                  ? FlowPayColors.primary
                                  : FlowPayColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mission.tagline,
                      style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mission.isActive,
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? FlowPayColors.primary
                      : null,
                ),
                activeTrackColor: FlowPayColors.primary.withAlpha(80),
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar & Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: \$${currentAmount.toStringAsFixed(0)} / \$${targetAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '${(progressFraction * 100).toInt()}% complete',
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? FlowPayColors.darkSurfaceElevated
                      : FlowPayColors.lightSurfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    mission.isActive
                        ? FlowPayColors.primary
                        : FlowPayColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rules Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? FlowPayColors.darkSurfaceElevated
                  : FlowPayColors.lightSurfaceElevated,
              borderRadius: FlowPaySpacing.borderRadiusMd,
              border: Border.all(
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRuleItem('Source', 'Incoming $sourceCur'),
                const Text('•', style: TextStyle(color: FlowPayColors.hairline)),
                _buildRuleItem('Allocation', '$allocPercent% share'),
                const Text('•', style: TextStyle(color: FlowPayColors.hairline)),
                _buildRuleItem('Destination', destTarget),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions Row: Edit, Pause, Run Now
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      icon: const Icon(Icons.tune, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      onPressed: onEdit,
                    ),
                  if (onViewActivity != null)
                    TextButton.icon(
                      icon: const Icon(Icons.history, size: 14),
                      label: const Text('Activity', style: TextStyle(fontSize: 12)),
                      onPressed: onViewActivity,
                    ),
                ],
              ),
              FlowPayButton(
                text: '⚡ Run Now',
                size: FlowPayButtonSize.small,
                onPressed: onTriggerManual,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: FlowPayColors.darkTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FlowPayColors.ink,
          ),
        ),
      ],
    );
  }
}
