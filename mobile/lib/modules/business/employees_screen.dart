import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';
import 'employee_detail_screen.dart';

class EmployeesScreen extends StatefulWidget {
  final AppState appState;

  const EmployeesScreen({Key? key, required this.appState}) : super(key: key);

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
    setState(() {
      employees = emps;
      isLoading = false;
    });
  }

  void _showInviteDialog() {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String country = 'NG';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlowPayColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Invite Employee to FlowPay', style: FlowPayTypography.headingSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'First Name',
                labelStyle: TextStyle(color: FlowPayColors.textSecondary),
              ),
            ),
            TextField(
              controller: lastCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Last Name',
                labelStyle: TextStyle(color: FlowPayColors.textSecondary),
              ),
            ),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Work Email',
                labelStyle: TextStyle(color: FlowPayColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: country,
              dropdownColor: FlowPayColors.surfaceElevated,
              items: const [
                DropdownMenuItem(value: 'NG', child: Text('Nigeria (NGN / CNGN)')),
                DropdownMenuItem(value: 'MX', child: Text('Mexico (MXN / MEXe)')),
              ],
              onChanged: (val) => country = val ?? 'NG',
              decoration: const InputDecoration(
                labelText: 'Country & Rail',
                labelStyle: TextStyle(color: FlowPayColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FlowPayColors.textTertiary)),
          ),
          FlowPayButton(
            text: 'Send Invite',
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.appState.employeeRepo.inviteEmployee(
                firstName: firstCtrl.text.trim(),
                lastName: lastCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                country: country,
                targetCurrency: country == 'NG' ? Currency.ngn : Currency.mxn,
              );
              _load();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Global Team', style: FlowPayTypography.headingSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: FlowPayColors.primaryLight),
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : ListView.builder(
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
                          backgroundColor: FlowPayColors.surfaceElevated,
                          child: Text(
                            emp.country,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(emp.fullName, style: FlowPayTypography.bodyLg),
                              const SizedBox(height: 2),
                              Text(emp.email, style: FlowPayTypography.caption),
                              const SizedBox(height: 2),
                              Text('Disbursement: ${emp.targetCurrency.code}', style: FlowPayTypography.caption.copyWith(color: FlowPayColors.textTertiary)),
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
    );
  }
}
