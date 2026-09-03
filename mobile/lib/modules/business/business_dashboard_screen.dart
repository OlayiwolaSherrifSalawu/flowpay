import 'package:flutter/material.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';
import 'employees_screen.dart';
import 'payroll_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  final AppState appState;

  const BusinessDashboardScreen({Key? key, required this.appState}) : super(key: key);

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  List<EmployeeModel> employees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final emps = await widget.appState.employeeRepo.getEmployees();
    setState(() {
      employees = emps;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FlowPay Business', style: FlowPayTypography.headingSm),
            Text(
              widget.appState.isDemo ? '● Demo Provider' : '● BMONI Sandbox Live',
              style: TextStyle(
                fontSize: 12,
                color: widget.appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 10x Hook Banner Card
                  FlowPayCard(
                    backgroundColor: FlowPayColors.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.public, color: FlowPayColors.accentLight),
                            SizedBox(width: 8),
                            Text('One Employer, Many Countries, One Bill', style: FlowPayTypography.headingSm),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Disburse international payroll to Nigeria (NGN) & Mexico (MXN) with instant spend cards — funded in one aggregate USD click.',
                          style: FlowPayTypography.bodyMd,
                        ),
                        const SizedBox(height: 16),
                        FlowPayButton(
                          text: 'Open Payroll Orchestrator',
                          icon: Icons.payments_outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PayrollScreen(appState: widget.appState),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: FlowPayCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active Team', style: FlowPayTypography.caption),
                              const SizedBox(height: 8),
                              Text('${employees.length} Members', style: FlowPayTypography.headingSm),
                              const SizedBox(height: 4),
                              Text('2 Countries (NG, MX)', style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FlowPayCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Run', style: FlowPayTypography.caption),
                              const SizedBox(height: 8),
                              Text('\$4,000.00', style: FlowPayTypography.headingSm),
                              const SizedBox(height: 4),
                              Text('Fee: \$12 (Saved \$328)', style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Team Roster Preview Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Linked Team Members', style: FlowPayTypography.headingSm),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmployeesScreen(appState: widget.appState),
                            ),
                          );
                        },
                        child: const Text('View All', style: TextStyle(color: FlowPayColors.primaryLight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...employees.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FlowPayCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: FlowPayColors.surfaceElevated,
                              child: Text(
                                e.country,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.fullName, style: FlowPayTypography.bodyLg),
                                  Text(e.email, style: FlowPayTypography.caption),
                                ],
                              ),
                            ),
                            StatusBadge(status: e.status),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
