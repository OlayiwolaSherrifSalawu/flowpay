import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/missions/mission_intent.dart';
import '../../../core/money/currency.dart';
import '../../../core/repositories/mission_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// FlowPay Money Mission Card
/// Premium Dribbble-inspired card displaying status, progress bar, rule specifications,
/// and fast execution controls.
class MissionCard extends StatelessWidget {
  final MoneyMissionModel mission;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTriggerManual;
  final VoidCallback? onEdit;
  final VoidCallback? onViewActivity;
  final VoidCallback? onDelete;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onToggleActive,
    required this.onTriggerManual,
    this.onEdit,
    this.onViewActivity,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Extract allocations summary
    final allocations = mission.allocations;
    final primaryAllocation =
        allocations.isNotEmpty ? allocations.first : null;
    final allocPercent =
        (mission.percentage ?? (primaryAllocation?.percentage ?? 100)).toInt();
    final sourceCur = (mission.targetCurrency ?? Currency.usd).code;

    // Dynamic destination and allocation display
    String destTarget = 'Smart Vault';
    if (primaryAllocation != null &&
        primaryAllocation.destinationWalletTag.isNotEmpty) {
      destTarget = primaryAllocation.destinationWalletTag;
    } else if (mission.allocations.length > 1) {
      destTarget = 'Multi-Vault';
    }

    String allocLabel = '$allocPercent% share';
    if (mission.allocations.length > 1) {
      allocLabel = '${mission.allocations.length} Allocations';
    } else if (mission.ruleType == MissionRuleType.autoSweep) {
      allocLabel = '$allocPercent% sweep';
    } else if (primaryAllocation?.actionType == MissionActionType.transfer) {
      allocLabel = '100% transfer';
    }

    // Dynamic target & execution amount calculation
    double targetAmount = 2000.0;
    if (mission.thresholdAmount != null) {
      targetAmount = mission.thresholdAmount!.minorUnits / 100.0;
    } else if (allocations.isNotEmpty) {
      double sum = 0;
      for (final a in allocations) {
        sum += double.tryParse(a.sourceAmountFormatted) ??
            ((int.tryParse(a.sourceAmountMinor) ?? 0) / 100.0);
      }
      if (sum > 0) targetAmount = sum;
    }

    double currentAmount = 0.0;
    if (mission.executedAmount != null) {
      currentAmount = mission.executedAmount!.minorUnits / 100.0;
    } else if (mission.executionCount > 0) {
      currentAmount =
          (mission.executionCount * targetAmount).clamp(0.0, targetAmount);
    } else if (mission.stats.contains('\$')) {
      final statMatch = RegExp(r'\$([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{2})?)')
          .firstMatch(mission.stats);
      if (statMatch != null) {
        currentAmount =
            double.tryParse(statMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
    }

    final progressFraction = targetAmount > 0
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : Colors.white,
        borderRadius: FlowPayRadii.card,
        border: Border.all(
          color: mission.isActive
              ? FlowPayColors.primary.withAlpha(80)
              : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: mission.isActive
                ? FlowPayColors.primary.withAlpha(16)
                : (isDark ? Colors.black26 : const Color(0x06000000)),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mission.isActive
                      ? FlowPayColors.primary.withAlpha(25)
                      : (isDark
                          ? FlowPayColors.darkSurfaceElevated
                          : FlowPayColors.lightSurfaceElevated),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: mission.isActive
                        ? FlowPayColors.primary.withAlpha(50)
                        : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
                  ),
                ),
                child: Icon(
                  Icons.bolt,
                  size: 22,
                  color: mission.isActive
                      ? FlowPayColors.primary
                      : (isDark
                          ? FlowPayColors.darkTextSecondary
                          : FlowPayColors.lightTextSecondary),
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: mission.isActive
                                ? FlowPayColors.primary.withAlpha(24)
                                : (isDark
                                    ? FlowPayColors.darkSurfaceElevated
                                    : FlowPayColors.lightSurfaceElevated),
                            borderRadius: FlowPayRadii.chip,
                            border: Border.all(
                              color: mission.isActive
                                  ? FlowPayColors.primary.withAlpha(60)
                                  : (isDark
                                      ? FlowPayColors.darkBorder
                                      : FlowPayColors.lightBorder),
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
                                  : (isDark
                                      ? FlowPayColors.darkTextSecondary
                                      : FlowPayColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mission.tagline,
                      style: FlowPayTypography.captionStyle(
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary,
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
                    currentAmount == 0
                        ? 'Ready to run'
                        : '${(progressFraction * 100).toInt()}% complete',
                    style: FlowPayTypography.captionStyle(
                      color: mission.isActive
                          ? FlowPayColors.primary
                          : (isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: FlowPayRadii.chip,
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 7,
                  backgroundColor: isDark
                      ? FlowPayColors.darkSurfaceElevated
                      : FlowPayColors.lightSurfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    mission.isActive
                        ? FlowPayColors.primary
                        : (isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rules Summary Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? FlowPayColors.darkSurfaceElevated
                  : FlowPayColors.lightSurfaceElevated,
              borderRadius: FlowPayRadii.cardSmall,
              border: Border.all(
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRuleItem('Source', 'Incoming $sourceCur', isDark),
                Text('•',
                    style: TextStyle(
                        color: isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder)),
                _buildRuleItem('Allocation', allocLabel, isDark),
                Text('•',
                    style: TextStyle(
                        color: isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder)),
                _buildRuleItem('Destination', destTarget, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions Row: Edit, Activity, Delete, Run Now
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
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: FlowPayColors.error),
                      tooltip: 'Delete Mission',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
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

  Widget _buildRuleItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isDark
                ? FlowPayColors.darkTextSecondary
                : FlowPayColors.lightTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark
                ? FlowPayColors.darkTextPrimary
                : FlowPayColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
