import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/radii.dart';
import '../../core/theme/typography.dart';
import 'employee_detail_screen.dart';

/// Global Team Screen
/// Conforms to design.md §3.1, §3.4 & §4.4
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
        backgroundColor: FlowPayColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.card),
        title: Text(
          'Invite Employee to FlowPay',
          style: FlowPayTypography.title(color: FlowPayColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstCtrl,
              style: const TextStyle(color: FlowPayColors.ink),
              decoration: const InputDecoration(
                labelText: 'First Name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lastCtrl,
              style: const TextStyle(color: FlowPayColors.ink),
              decoration: const InputDecoration(
                labelText: 'Last Name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: FlowPayColors.ink),
              decoration: const InputDecoration(
                labelText: 'Work Email',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: country,
              dropdownColor: FlowPayColors.surface,
              items: const [
                DropdownMenuItem(value: 'NG', child: Text('🇳🇬 Nigeria (NGN / CNGN)')),
                DropdownMenuItem(value: 'MX', child: Text('🇲🇽 Mexico (MXN / MEXe)')),
                DropdownMenuItem(value: 'CA', child: Text('🇨🇦 Canada (CAD / CADC)')),
              ],
              onChanged: (val) => country = val ?? 'NG',
              decoration: const InputDecoration(
                labelText: 'Country & Rail',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: FlowPayColors.textSecondary),
            ),
          ),
          FlowPayButton(
            text: 'Send Invite',
            onPressed: () async {
              Navigator.pop(ctx);
              final curr = country == 'NG'
                  ? Currency.ngn
                  : country == 'MX'
                      ? Currency.mxn
                      : Currency.cad;
              await widget.appState.employeeRepo.inviteEmployee(
                firstName: firstCtrl.text.trim(),
                lastName: lastCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                country: country,
                targetCurrency: curr,
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
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.ink))
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
    );
  }
}
