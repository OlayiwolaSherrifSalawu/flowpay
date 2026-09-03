import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import 'components/add_employee_modal.dart';
import 'employee_detail_screen.dart';

/// Global Team Screen
/// Conforms to design.md §3.1, §3.4 & §4.4
class EmployeesScreen extends StatefulWidget {
  final AppState appState;

  const EmployeesScreen({super.key, required this.appState});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
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
    if (mounted) {
      setState(() {
        employees = emps;
        isLoading = false;
      });
    }
  }

  void _showInviteDialog() {
    AddEmployeeModal.show(context, widget.appState.businessProvider);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Global Team',
          style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: FlowPayColors.ink),
            tooltip: 'Invite Employee',
            onPressed: _showInviteDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.ink))
          : RefreshIndicator(
              onRefresh: _load,
              color: FlowPayColors.ink,
              backgroundColor: FlowPayColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: employees.length,
                itemBuilder: (ctx, i) {
                  final emp = employees[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FlowPayCard(
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
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: FlowPayColors.surfaceAlt,
                            child: Text(
                              emp.flagEmoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp.fullName,
                                  style: FlowPayTypography.body(color: FlowPayColors.ink).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  emp.email,
                                  style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rail: ${emp.targetCurrency.code} • ${emp.resolvedCountryName}',
                                  style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: emp.status),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
