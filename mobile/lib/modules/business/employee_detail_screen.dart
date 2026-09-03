import 'package:flutter/material.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final AppState appState;
  final EmployeeModel employee;

  const EmployeeDetailScreen({
    Key? key,
    required this.appState,
    required this.employee,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: Text(employee.fullName, style: FlowPayTypography.headingSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: FlowPayColors.surfaceElevated,
                      child: Text(
                        employee.country,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employee.fullName, style: FlowPayTypography.headingSm),
                          const SizedBox(height: 4),
                          Text(employee.email, style: FlowPayTypography.bodyMd),
                        ],
                      ),
                    ),
                    StatusBadge(status: employee.status),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: FlowPayColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Country / Region', style: FlowPayTypography.bodyMd),
                    const Spacer(),
                    Text(
                      employee.country == 'NG' ? 'Nigeria (NGN Rail)' : 'Mexico (MXN SPEI Rail)',
                      style: FlowPayTypography.bodyLg,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Disbursement Currency', style: FlowPayTypography.bodyMd),
                    const Spacer(),
                    Text(employee.targetCurrency.code, style: FlowPayTypography.headingSm),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Smart Wallet & Virtual Card Section
          Text('Infrastructure & Spend Cards', style: FlowPayTypography.headingSm),
          const SizedBox(height: 12),
          FlowPayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.credit_card, color: FlowPayColors.primaryLight),
                    SizedBox(width: 10),
                    Text('Linked BMONI Virtual Card', style: FlowPayTypography.headingSm),
                    Spacer(),
                    StatusBadge(status: 'ACTIVE'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Automated payroll dispatches are instantly spendable by the employee through their localized virtual card.',
                  style: FlowPayTypography.bodyMd,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Card Number', style: FlowPayTypography.caption),
                    const Spacer(),
                    Text('•••• •••• •••• 4289', style: FlowPayTypography.financialSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Monthly Spend Ceiling', style: FlowPayTypography.caption),
                    const Spacer(),
                    Text('\$5,000 / month', style: FlowPayTypography.financialSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
