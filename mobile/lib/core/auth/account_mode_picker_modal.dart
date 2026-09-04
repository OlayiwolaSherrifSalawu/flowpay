import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/components.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';
import 'account_capabilities.dart';

/// Modal Bottom Sheet for selecting between Personal and Business modes.
/// Conforms to design.md §4.4 and §2.4: 24dp sheet radius, universal pill buttons,
/// surface luminance shifts, and zero drop shadows.
class AccountModePickerModal extends StatefulWidget {
  final AccountMode initialMode;
  final AccountCapabilities capabilities;
  final ValueChanged<AccountMode> onModeSelected;

  const AccountModePickerModal({
    super.key,
    required this.initialMode,
    required this.capabilities,
    required this.onModeSelected,
  });

  static Future<AccountMode?> show(
    BuildContext context, {
    required AccountMode initialMode,
    required AccountCapabilities capabilities,
  }) {
    return showModalBottomSheet<AccountMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountModePickerModal(
        initialMode: initialMode,
        capabilities: capabilities,
        onModeSelected: (mode) => Navigator.pop(ctx, mode),
      ),
    );
  }

  @override
  State<AccountModePickerModal> createState() => _AccountModePickerModalState();
}

class _AccountModePickerModalState extends State<AccountModePickerModal> {
  late AccountMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FlowPayColors.surface,
        borderRadius: FlowPayRadii.sheet,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FlowPayColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Text(
              'Select Account Mode',
              style: FlowPayTypography.title(),
            ),
            const SizedBox(height: 6),
            const Text(
              'Switch between your personal multi-currency wallet and your business payroll operating layer.',
              style: TextStyle(
                fontSize: 14,
                color: FlowPayColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Personal Mode Tile
            _buildModeTile(
              mode: AccountMode.personal,
              title: 'Personal Account',
              subtitle:
                  'Multi-currency smart wallets, virtual spend cards, and automated money missions.',
              icon: Icons.person_outline,
              badgeText: 'Active',
              isEnabled: widget.capabilities.hasPersonalWallet,
            ),
            const SizedBox(height: 12),

            // Business Mode Tile
            _buildModeTile(
              mode: AccountMode.business,
              title: 'Business Account',
              subtitle:
                  'One Employer. Many Countries. One Bill. Multi-country payroll and team card limits.',
              icon: Icons.business_center_outlined,
              badgeText: widget.capabilities.companyRole ?? 'Admin',
              companyName: widget.capabilities.companyName,
              isEnabled: widget.capabilities.hasBusinessAccess,
            ),
            const SizedBox(height: 28),

            // Confirm Button
            FlowPayButton(
              text: 'Continue in ${_selectedMode.displayName} Mode',
              icon: Icons.arrow_forward,
              onPressed: () {
                widget.onModeSelected(_selectedMode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required AccountMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    String? companyName,
    required bool isEnabled,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: isEnabled ? () => setState(() => _selectedMode = mode) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? FlowPayColors.surfaceAlt : FlowPayColors.surface,
          borderRadius: FlowPayRadii.card,
          border: Border.all(
            color: isSelected ? FlowPayColors.ink : FlowPayColors.hairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isSelected ? FlowPayColors.ink : FlowPayColors.surfaceAlt,
                borderRadius: FlowPayRadii.avatar,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : FlowPayColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        status: badgeText,
                      ),
                    ],
                  ),
                  if (companyName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: FlowPayColors.ink,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FlowPayColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Custom Radio Indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? FlowPayColors.ink
                      : FlowPayColors.textTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: FlowPayColors.ink,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
