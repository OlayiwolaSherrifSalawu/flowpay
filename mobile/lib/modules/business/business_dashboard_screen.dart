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
/// Conforms to design.md §3.1, §3.4, §3.5, §4.4 & §6:
/// - Light canvas background (#FAFAF7)
/// - Universal pill buttons & chips (9999)
/// - One primary CTA: "Run Payroll" (one verb per action)
/// - 6 employer operating metrics and 7 employee preview attributes
class BusinessDashboardScreen extends StatefulWidget {
  static const String routeName = '/business-dashboard';
  final AppState appState;

  const BusinessDashboardScreen({super.key, required this.appState});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
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
    return AnimatedBuilder(
      animation: widget.appState.businessProvider,
      builder: (context, _) {
        final provider = widget.appState.businessProvider;
        final employees = provider.employees;
        final isLoading = provider.isLoading && employees.isEmpty;

        final filteredEmployees = _selectedCountryFilter == 'ALL'
            ? employees
            : employees.where((e) => e.country.toUpperCase() == _selectedCountryFilter).toList();

        return Scaffold(
          backgroundColor: FlowPayColors.canvas,
          appBar: AppBar(
            backgroundColor: FlowPayColors.canvas,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Dashboard',
                  style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlowPayColors.signal,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'BMONI Global Rails Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: FlowPayColors.signal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_rounded, color: FlowPayColors.ink),
                tooltip: 'Add Employee',
                onPressed: _onAddEmployee,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: FlowPayColors.textSecondary),
                tooltip: 'Refresh',
                onPressed: provider.refresh,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: FlowPayColors.ink))
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  color: FlowPayColors.ink,
                  backgroundColor: FlowPayColors.surface,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          const Icon(Icons.analytics_outlined, size: 18, color: FlowPayColors.ink),
                          const SizedBox(width: 8),
                          Text(
                            'EMPLOYER OPERATING METRICS',
                            style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
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
                                style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${filteredEmployees.length} remote team members linked',
                                style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: FlowPayColors.ink),
                            label: const Text(
                              'Full Roster',
                              style: TextStyle(color: FlowPayColors.ink, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmployeesScreen(appState: widget.appState),
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
                              onSelected: () => setState(() => _selectedCountryFilter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇳🇬 Nigeria (NGN)',
                              isSelected: _selectedCountryFilter == 'NG',
                              onSelected: () => setState(() => _selectedCountryFilter == 'NG'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇲🇽 Mexico (MXN)',
                              isSelected: _selectedCountryFilter == 'MX',
                              onSelected: () => setState(() => _selectedCountryFilter == 'MX'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '🇨🇦 Canada (CAD)',
                              isSelected: _selectedCountryFilter == 'CA',
                              onSelected: () => setState(() => _selectedCountryFilter == 'CA'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Employee Preview List
                      if (filteredEmployees.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No Employees in Selected Filter\nAdd an employee to this jurisdiction or switch filter to All.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FlowPayColors.textSecondary),
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
    return InkWell(
      onTap: onSelected,
      borderRadius: FlowPayRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? FlowPayColors.ink : FlowPayColors.surfaceAlt,
          borderRadius: FlowPayRadii.chip,
          border: Border.all(
            color: isSelected ? FlowPayColors.ink : FlowPayColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : FlowPayColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
