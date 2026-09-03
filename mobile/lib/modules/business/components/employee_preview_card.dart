import 'package:flutter/material.dart';
import '../../../core/repositories/employee_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Employee Preview Card
/// Conforms to design.md §3.1, §3.2, §3.4 & §3.5:
/// Displays all 7 employee preview attributes with 20dp card radius,
/// universal pill badges, and tabular figures for all salaries.
class EmployeePreviewCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback? onTap;

  const EmployeePreviewCard({
    super.key,
    required this.employee,
    this.onTap,
  });

  Color _getCurrencyBg(String code) {
    switch (code.toUpperCase()) {
      case 'NGN':
        return FlowPayColors.ngnBadge;
      case 'MXN':
        return FlowPayColors.mxnBadge;
      case 'CAD':
        return FlowPayColors.cadBadge;
      default:
        return FlowPayColors.usdBadge;
    }
  }

  Color _getCurrencyFg(String code) {
    switch (code.toUpperCase()) {
      case 'NGN':
        return const Color(0xFF065F46);
      case 'MXN':
        return const Color(0xFF86198F);
      case 'CAD':
        return const Color(0xFF991B1B);
      default:
        return FlowPayColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollFormatted = employee.payrollAmount != null
        ? employee.payrollAmount!.formatFormatted()
        : '${employee.targetCurrency.symbol}2,000.00';

    final usdFormatted = employee.usdPayrollAmount != null
        ? employee.usdPayrollAmount!.formatFormatted()
        : '\$2,000.00 USD';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FlowPayCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Name, Email, and Onboarding Status
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: FlowPayColors.surfaceAlt,
                  child: Text(
                    employee.flagEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
            const SizedBox(height: 14),
            const Divider(color: FlowPayColors.hairline, height: 1),
            const SizedBox(height: 12),

            // Row 2: Country, Currency, and Payroll Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country & Currency Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COUNTRY & RAIL',
                        style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${employee.flagEmoji} ${employee.resolvedCountryName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: FlowPayColors.ink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getCurrencyBg(employee.targetCurrency.code),
                              borderRadius: FlowPayRadii.chip,
                            ),
                            child: Text(
                              employee.targetCurrency.code,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getCurrencyFg(employee.targetCurrency.code),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Payroll Amount (Target Currency + USD Equivalent)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PAYROLL AMOUNT',
                      style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payrollFormatted,
                      style: FlowPayTypography.amount(color: FlowPayColors.ink).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      usdFormatted,
                      style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Wallet Status & Card Status Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: FlowPayColors.surfaceAlt,
                borderRadius: FlowPayRadii.input,
              ),
              child: Row(
                children: [
                  // Wallet Status Chip
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 14, color: FlowPayColors.ink),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WALLET STATUS',
                                style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(fontSize: 9),
                              ),
                              Text(
                                '${employee.walletStatus} • ${employee.walletAddress ?? "0x...Ready"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FlowPayColors.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: FlowPayColors.hairline,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Card Status Chip
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 14, color: FlowPayColors.amber),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD STATUS',
                                style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(fontSize: 9),
                              ),
                              Text(
                                '${employee.cardStatus} • •••• ${employee.cardLast4 ?? "4289"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FlowPayColors.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
