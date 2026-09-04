import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// A prominent, unconfusing Role Switcher for toggling between Personal and Business modes.
class FlowPayRoleSwitcher extends StatelessWidget {
  final AppRole activeRole;
  final ValueChanged<AppRole> onRoleChanged;

  const FlowPayRoleSwitcher({
    super.key,
    required this.activeRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPersonal = activeRole == AppRole.personal;

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurfaceElevated,
        borderRadius: FlowPaySpacing.borderRadiusPill,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPill(
            context: context,
            isSelected: isPersonal,
            icon: Icons.person_outline,
            label: 'Personal',
            selectedColor: FlowPayColors.primary,
            onTap: () => onRoleChanged(AppRole.personal),
          ),
          const SizedBox(width: 2),
          _buildPill(
            context: context,
            isSelected: !isPersonal,
            icon: Icons.business_center_outlined,
            label: 'Business',
            selectedColor: FlowPayColors.accent,
            onTap: () => onRoleChanged(AppRole.business),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required bool isSelected,
    required IconData icon,
    required String label,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: FlowPaySpacing.borderRadiusPill,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? FlowPayColors.darkTextSecondary
                      : FlowPayColors.lightTextSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? FlowPayColors.darkTextSecondary
                        : FlowPayColors.lightTextSecondary),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
