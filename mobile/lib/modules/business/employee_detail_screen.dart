import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/components.dart';

/// Employee Detail Screen
/// Conforms strictly to design.md §3.1, §3.4, §3.5 & §4.5:
/// Displays employee attributes, BMONI infrastructure details, and the physical
/// VirtualCardObject (1.586 aspect ratio, FlowPay Amber fill, soft physical shadow).
class EmployeeDetailScreen extends StatelessWidget {
  final AppState appState;
  final EmployeeModel employee;

  const EmployeeDetailScreen({
    super.key,
    required this.appState,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          employee.fullName,
          style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: FlowPaySpacing.insetXl,
        children: [
          // 1. Employee Virtual Card Face (Physical Card Object)
          VirtualCardObject(
            cardLast4: employee.cardLast4 ?? '4289',
            countryFlag: employee.flagEmoji,
            cardHolderName: employee.fullName,
            isFrozen: employee.cardStatus.toUpperCase() == 'FROZEN',
          ),
          const SizedBox(height: 24),

          // 2. Profile Overview Card
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: FlowPayColors.surfaceAlt,
                      child: Text(
                        employee.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName,
                            style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.email,
                            style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: employee.onboardingStatus),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: FlowPayColors.hairline, height: 1),
                const SizedBox(height: 14),

                _DetailRow(
                  label: 'Country / Jurisdiction',
                  value: '${employee.flagEmoji} ${employee.resolvedCountryName}',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Disbursement Currency',
                  value: '${employee.targetCurrency.code} (${employee.targetCurrency.stablecoinToken})',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Monthly Net Salary',
                  value: employee.payrollAmount?.formatFormatted() ?? '${employee.targetCurrency.symbol}2,000.00',
                  isAccent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.xl),

          // 3. Smart Wallet & Virtual Card Infrastructure Card
          Text(
            'INFRASTRUCTURE & CARD CONTROLS',
            style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: FlowPayColors.ink, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'BMONI Smart Wallet',
                      style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 15),
                    ),
                    const Spacer(),
                    StatusBadge(status: employee.walletStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Address: ${employee.walletAddress ?? "0x...Provisioned"}',
                  style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary).copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: FlowPayColors.hairline, height: 1),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, color: FlowPayColors.amber, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Virtual Mastercard',
                      style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 15),
                    ),
                    const Spacer(),
                    StatusBadge(status: employee.cardStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Automated payroll disbursements are instantly available on the employee\'s localized virtual card.',
                  style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary).copyWith(height: 1.4),
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Card Number',
                  value: '•••• •••• •••• ${employee.cardLast4 ?? "4289"}',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Monthly Spend Ceiling',
                  value: '${employee.targetCurrency.symbol}5,000 / month',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: isAccent
              ? FlowPayTypography.amount(color: FlowPayColors.signal).copyWith(
                  fontWeight: FontWeight.w700,
                )
              : FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
        ),
      ],
    );
  }
}
