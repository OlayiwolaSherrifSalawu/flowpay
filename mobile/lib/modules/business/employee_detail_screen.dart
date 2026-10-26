import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/design_system.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/stellar/stellar_network.dart';

/// One employee: profile, how they get paid, and where they are in joining.
///
/// INVITED   → share / resend their invite link (they create their own wallet)
/// READY     → paid on Stellar to the account they proved they own
/// SUSPENDED → skipped by payroll until resumed
class EmployeeDetailScreen extends StatefulWidget {
  final AppState appState;
  final EmployeeModel employee;

  const EmployeeDetailScreen({super.key, required this.appState, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late EmployeeModel _emp = widget.employee;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: FlowPayColors.error, content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied')));
  }

  Future<void> _resendInvite() => _run(() async {
        final url = await widget.appState.employeeRepo.resendInvite(_emp.id);
        final fresh = await widget.appState.employeeRepo.getEmployeeById(_emp.id);
        setState(() => _emp = fresh);
        _copy(url, 'New invite link');
      });

  Future<void> _setStatus(String status) => _run(() async {
        final updated = await widget.appState.employeeRepo.setEmployeeStatus(_emp.id, status);
        setState(() => _emp = updated);
        await widget.appState.businessProvider.refresh();
      });

  Widget _row(String label, String value, {Key? key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: FlowPayTypography.captionStyle(color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary)),
          ),
          Expanded(child: Text(value, key: key, style: FlowPayTypography.bodyMedium)),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : Colors.white,
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _statusCard() {
    final status = _emp.status.toUpperCase();
    if (status == EmployeeLifecycleStages.ready && _emp.walletAddress != null) {
      final network = StellarNetwork.current;
      return _card([
        const Text('Paid on Stellar', style: FlowPayTypography.titleMedium),
        const SizedBox(height: 6),
        Text('Salary goes straight to the wallet ${_emp.firstName} created and controls.', style: FlowPayTypography.bodySmall),
        const SizedBox(height: 10),
        _row('Account', _emp.walletAddress!, key: const Key('employee_detail_account')),
        Wrap(spacing: 8, children: [
          TextButton.icon(
            onPressed: () => _copy(_emp.walletAddress!, 'Account'),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () => _copy(network.accountUrl(_emp.walletAddress!), 'Explorer link'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Explorer link'),
          ),
        ]),
      ]);
    }
    if (status == EmployeeLifecycleStages.suspended) {
      return _card([
        const Text('Suspended', style: FlowPayTypography.titleMedium),
        const SizedBox(height: 6),
        Text('Payroll skips ${_emp.firstName} until you resume them.', style: FlowPayTypography.bodySmall),
      ]);
    }
    return _card([
      Text('Waiting for ${_emp.firstName} to join', style: FlowPayTypography.titleMedium),
      const SizedBox(height: 6),
      Text(
        '${_emp.firstName} signs up with ${_emp.email}, creates a wallet on their own phone, then opens this link to accept. '
        'You never hold their keys.',
        style: FlowPayTypography.bodySmall,
      ),
      if (_emp.inviteUrl != null) ...[
        const SizedBox(height: 10),
        SelectableText(_emp.inviteUrl!, key: const Key('employee_detail_invite_url'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_emp.inviteUrl != null)
          FlowPayButton(text: 'Copy invite link', size: FlowPayButtonSize.small, onPressed: () => _copy(_emp.inviteUrl!, 'Invite link')),
        FlowPayButton(
          key: const Key('employee_detail_resend_invite'),
          text: 'New invite link',
          size: FlowPayButtonSize.small,
          variant: FlowPayButtonVariant.secondary,
          isLoading: _busy,
          onPressed: _busy ? null : _resendInvite,
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final status = _emp.status.toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(_emp.fullName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            Row(children: [
              Text(_emp.flagEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_emp.fullName, style: FlowPayTypography.titleMedium),
                  Text(_emp.email, style: FlowPayTypography.bodySmall),
                ]),
              ),
              FlowPayStatusBadge(status: _emp.simpleStatusLabel),
            ]),
            const SizedBox(height: 12),
            _row('Country', _emp.resolvedCountryName),
            _row('Paid in', _emp.targetCurrency.code),
            _row('Salary', _emp.payrollAmount?.formatFormatted() ?? '—', key: const Key('employee_detail_salary')),
          ]),
          _statusCard(),
          if (status == EmployeeLifecycleStages.ready)
            FlowPayButton(
              key: const Key('employee_detail_suspend'),
              text: 'Suspend from payroll',
              variant: FlowPayButtonVariant.secondary,
              isLoading: _busy,
              onPressed: _busy ? null : () => _setStatus(EmployeeLifecycleStages.suspended),
            ),
          if (status == EmployeeLifecycleStages.suspended)
            FlowPayButton(
              key: const Key('employee_detail_resume'),
              text: 'Resume payroll',
              isLoading: _busy,
              onPressed: _busy ? null : () => _setStatus(_emp.walletAddress != null ? EmployeeLifecycleStages.ready : EmployeeLifecycleStages.invited),
            ),
        ],
      ),
    );
  }
}
