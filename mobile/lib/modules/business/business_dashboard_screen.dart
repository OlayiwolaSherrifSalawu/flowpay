import 'package:flutter/material.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/radii.dart';
import '../../core/theme/typography.dart';
import 'components/add_employee_modal.dart';
import 'components/business_metrics_grid.dart';
import 'components/employee_preview_card.dart';
import 'components/hero_bill_card.dart';
import 'employee_detail_screen.dart';
import 'employees_screen.dart';
import 'payroll_screen.dart';

/// FlowPay Business — Employer Dashboard Screen
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - Theme-adaptive canvas (paper / darkBackground)
/// - Universal pill buttons & chips (FlowPayRadii.chip / FlowPayRadii.button)
/// - One primary CTA: "Run Payroll" with secondary "Add Employee"
/// - 6 employer operating metrics and 7 employee preview attributes
/// - Preserves all callbacks, routes, and test semantics
class BusinessDashboardScreen extends StatefulWidget {
  static const String routeName = '/business-dashboard';
  final AppState appState;

  const BusinessDashboardScreen({super.key, required this.appState});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  String _selectedCountryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    // Load deterministic business data through BusinessProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.businessProvider.loadDashboard();
    });
  }

  void _onRunPayroll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayrollScreen(appState: widget.appState),
      ),
    );
  }

  void _onAddEmployee() {
    AddEmployeeModal.show(context, widget.appState.businessProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final surfaceColor =
        isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;

    return AnimatedBuilder(
      animation: widget.appState.businessProvider,
      builder: (context, _) {
        final provider = widget.appState.businessProvider;
        final employees = provider.employees;
        final isLoading = provider.isLoading && employees.isEmpty;

        final filteredEmployees = _selectedCountryFilter == 'ALL'
            ? employees
            : employees
                .where((e) => e.country.toUpperCase() == _selectedCountryFilter)
                .toList();

        return Scaffold(
          backgroundColor: canvasColor,
          appBar: AppBar(
            backgroundColor: canvasColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Dashboard',
                  style: FlowPayTypography.title(color: inkColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlowPayColors.signal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Global Rails Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FlowPayColors.signal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.person_add_rounded, color: inkColor),
                tooltip: 'Add Employee',
                onPressed: _onAddEmployee,
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: textSecondaryColor),
                tooltip: 'Refresh',
                onPressed: provider.refresh,
              ),
            ],
          ),
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: FlowPayColors.primary))
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  color: FlowPayColors.primary,
                  backgroundColor: surfaceColor,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    children: [
                      // 1. Core Hook Hero Card: "One Employer. Many Countries. One Bill."
                      HeroBillCard(
                        businessProvider: provider,
                        onRunPayroll: _onRunPayroll,
                      ),
                      const SizedBox(height: 20),

                      // 2. Action Controls Bar (Primary: Run Payroll, Secondary: Add Employee)
                      Row(
                        children: [
                          Expanded(
                            child: FlowPayButton(
                              text: 'Run Payroll',
                              icon: Icons.payments_rounded,
                              onPressed: _onRunPayroll,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FlowPayButton(
                              text: 'Add Employee',
                              isSecondary: true,
                              icon: Icons.person_add_rounded,
                              onPressed: _onAddEmployee,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Core Employer Metrics Grid
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: FlowPayColors.primary.withValues(alpha: 0.12),
                              borderRadius: FlowPayRadii.avatar,
                            ),
                            child: const Center(
                              child: Icon(Icons.analytics_outlined,
                                  size: 16, color: FlowPayColors.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'EMPLOYER OPERATING METRICS',
                            style: FlowPayTypography.captionStyle(
                                    color: textTertiaryColor)
                                .copyWith(
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BusinessMetricsGrid(businessProvider: provider),
                      const SizedBox(height: 28),

                      // 4. Employee Preview Header with Country Filters
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EMPLOYEE PREVIEW',
                                style: FlowPayTypography.title(color: inkColor)
                                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${filteredEmployees.length} remote team members linked',
                                style: FlowPayTypography.captionStyle(
                                    color: textSecondaryColor),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 14, color: FlowPayColors.primary),
                            label: const Text(
                              'Full Roster',
                              style: TextStyle(
                                  color: FlowPayColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmployeesScreen(
                                      appState: widget.appState),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Country Filter Pills (Universal pill radius 9999)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All (${employees.length})',
                              isSelected: _selectedCountryFilter == 'ALL',
                              onSelected: () => setState(
                                  () => _selectedCountryFilter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇳🇬 Nigeria (NGN)',
                              isSelected: _selectedCountryFilter == 'NG',
                              onSelected: () => setState(
                                  () => _selectedCountryFilter == 'NG'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇲🇽 Mexico (MXN)',
                              isSelected: _selectedCountryFilter == 'MX',
                              onSelected: () => setState(
                                  () => _selectedCountryFilter == 'MX'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇨🇦 Canada (CAD)',
                              isSelected: _selectedCountryFilter == 'CA',
                              onSelected: () => setState(
                                  () => _selectedCountryFilter == 'CA'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Employee Preview List
                      if (filteredEmployees.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No Employees in Selected Filter\nAdd an employee to this jurisdiction or switch filter to All.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondaryColor),
                            ),
                          ),
                        ),
                      ] else ...[
                        ...filteredEmployees.map((emp) {
                          return EmployeePreviewCard(
                            employee: emp,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmployeeDetailScreen(
                                    appState: widget.appState,
                                    employee: emp,
                                  ),
                                ),
                              );
                            },
                            onRetry: emp.status.toUpperCase() == 'FAILED'
                                ? () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    try {
                                      await widget.appState.businessProvider
                                          .retryEmployeeUserCreation(emp.id);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Retry succeeded — employee is now invited.'),
                                        ),
                                      );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Retry failed: $e')),
                                      );
                                    }
                                  }
                                : null,
                          );
                        }),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeBg = FlowPayColors.primary;
    final inactiveBg =
        isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface;
    const activeFg = Colors.white;
    final inactiveFg =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final borderColor = isSelected
        ? FlowPayColors.primary
        : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder);

    return InkWell(
      onTap: onSelected,
      borderRadius: FlowPayRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: FlowPayRadii.chip,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeFg : inactiveFg,
          ),
        ),
      ),
    );
  }
}
