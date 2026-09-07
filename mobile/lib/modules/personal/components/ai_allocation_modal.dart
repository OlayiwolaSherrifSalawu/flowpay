import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/missions/mission_intent.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/repositories/mission_repository.dart';
import '../../../core/state/personal_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class AiAllocationModal extends StatefulWidget {
  final PersonalProvider personalProvider;
  final Money initialAmount;

  const AiAllocationModal({
    super.key,
    required this.personalProvider,
    required this.initialAmount,
  });

  @override
  State<AiAllocationModal> createState() => _AiAllocationModalState();
}

class _AiAllocationModalState extends State<AiAllocationModal> {
  late TextEditingController _amountController;
  bool _isExecuting = false;

  // Suggested allocation splits
  final double _savingsPct = 50.0;
  final double _payrollPct = 30.0;
  final double _reservePct = 20.0;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.initialAmount.majorUnits.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountController.text) ?? 2000.0;
  }

  Future<void> _handleExecuteAllocation() async {
    setState(() => _isExecuting = true);
    final amt = _currentAmount;

    final rule = MoneyMissionModel(
      id: 'mission_ai_split_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Incoming Split: \$${amt.toStringAsFixed(0)}',
      tagline:
          '${_savingsPct.toInt()}% Savings, ${_payrollPct.toInt()}% Expenses, ${_reservePct.toInt()}% Tax Reserve',
      ruleType: MissionRuleType.splitIncoming,
      isActive: true,
      stats: 'Executed 0 times • Autonomous',
      conditionSummary: 'Incoming transfers > \$${amt.toStringAsFixed(0)}',
      actionSummary: 'Split into Savings, Expenses, and Tax Reserve',
      thresholdAmount:
          Money.fromMajorString(amt.toStringAsFixed(2), Currency.usd),
      targetCurrency: Currency.usd,
      percentage: _savingsPct,
      createdAt: DateTime.now(),
      allocations: [
        MissionAllocation(
          id: 'alloc_savings_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.savings,
          label: 'High-Yield Savings',
          percentage: _savingsPct,
          targetCurrency: Currency.usd,
          sourceAmountMinor: '${(amt * _savingsPct).toInt() * 100}',
          sourceAmountFormatted:
              '\$${(amt * _savingsPct / 100).toStringAsFixed(2)}',
          destinationWalletTag: 'USD Savings Vault',
          actionType: MissionActionType.sweepVault,
        ),
        MissionAllocation(
          id: 'alloc_expenses_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.expenses,
          label: 'Local Expenses (NGN)',
          percentage: _payrollPct,
          targetCurrency: Currency.ngn,
          sourceAmountMinor: '${(amt * _payrollPct).toInt() * 100}',
          sourceAmountFormatted:
              '\$${(amt * _payrollPct / 100).toStringAsFixed(2)}',
          destinationWalletTag: 'NGN Expenses Vault',
          actionType: MissionActionType.convertFx,
        ),
        MissionAllocation(
          id: 'alloc_tax_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.tax,
          label: 'Tax Reserve',
          percentage: _reservePct,
          targetCurrency: Currency.usd,
          sourceAmountMinor: '${(amt * _reservePct).toInt() * 100}',
          sourceAmountFormatted:
              '\$${(amt * _reservePct / 100).toStringAsFixed(2)}',
          destinationWalletTag: 'USD Tax Reserve',
          actionType: MissionActionType.sweepVault,
        ),
      ],
    );

    try {
      await widget.personalProvider.addMission(rule);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Allocation Rule "${rule.title}" activated!'),
            backgroundColor: FlowPayColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExecuting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate rule: $e'),
            backgroundColor: FlowPayColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amt = _currentAmount;
    final savingsAmt = amt * (_savingsPct / 100);
    final expensesAmt = amt * (_payrollPct / 100);
    final reserveAmt = amt * (_reservePct / 100);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlowPayColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pie_chart_outline,
                        color: FlowPayColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Capital Allocation',
                        style: FlowPayTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const Text(
                        'Task Workflow: Autonomous Split & Sweep',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlowPayColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'AI autonomously executes this distribution whenever new funds arrive into your wallet.',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input Field
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurfaceElevated,
                  borderRadius: FlowPaySpacing.borderRadiusMd,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('\$',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '2000.00',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const Text('USD Inflow',
                        style: TextStyle(
                            fontSize: 12,
                            color: FlowPayColors.darkTextSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text('DISTRIBUTION PREVIEW',
                  style: FlowPayTypography.caption.copyWith(
                      letterSpacing: 0.8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              _DistributionRow(
                label: 'High-Yield Savings (${_savingsPct.toInt()}%)',
                sublabel: 'Autonomous treasury reserve',
                amount: '\$${savingsAmt.toStringAsFixed(2)}',
                color: FlowPayColors.primary,
                icon: Icons.savings_outlined,
              ),
              const SizedBox(height: 8),

              _DistributionRow(
                label: 'Operating Expenses (${_payrollPct.toInt()}%)',
                sublabel: 'Converted to local NGN liquidity',
                amount: '\$${expensesAmt.toStringAsFixed(2)}',
                color: FlowPayColors.accent,
                icon: Icons.currency_exchange,
              ),
              const SizedBox(height: 8),

              _DistributionRow(
                label: 'Tax Reserve (${_reservePct.toInt()}%)',
                sublabel: 'Secure locked tax buffer',
                amount: '\$${reserveAmt.toStringAsFixed(2)}',
                color: FlowPayColors.amber,
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 20),

              FlowPayButton(
                text: 'Activate Allocation Rule',
                icon: Icons.bolt,
                isFullWidth: true,
                size: FlowPayButtonSize.large,
                isLoading: _isExecuting,
                onPressed: _handleExecuteAllocation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final String amount;
  final Color color;
  final IconData icon;

  const _DistributionRow({
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusMd,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: FlowPayTypography.amount(
              color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
