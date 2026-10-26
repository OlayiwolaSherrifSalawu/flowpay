import '../../../core/network/api_client.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/navigation/invite_link.dart';
import '../../../core/repositories/employee_repository.dart';

/// Lets a signed-in user join their employer's payroll with the wallet they
/// already own. Errors (wrong email, wallet not activated, expired link) are
/// shown as the server reports them.
class AcceptInviteSheet extends StatefulWidget {
  final EmployeeRepository repo;
  final String? initialToken;

  /// Used to verify the user's email when the server asks for it.
  final FlowPayApiClient? apiClient;

  const AcceptInviteSheet({super.key, required this.repo, this.initialToken, this.apiClient});

  static Future<EmployeeModel?> show(BuildContext context, {required EmployeeRepository repo, String? token, FlowPayApiClient? apiClient}) {
    return showModalBottomSheet<EmployeeModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.sheet),
      builder: (_) => AcceptInviteSheet(repo: repo, initialToken: token, apiClient: apiClient),
    );
  }

  @override
  State<AcceptInviteSheet> createState() => _AcceptInviteSheetState();
}

class _AcceptInviteSheetState extends State<AcceptInviteSheet> {
  late final TextEditingController _link = TextEditingController(text: widget.initialToken ?? '');
  Map<String, dynamic>? _invite;
  String? _error;
  bool _busy = false;
  bool _needsEmailCode = false;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) _lookup();
  }

  @override
  void dispose() {
    _link.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lookup() => _guard(() async {
        final token = InviteLink.parse(_link.text);
        if (token == null) throw 'Paste the full invite link from your employer.';
        final invite = await widget.repo.getInviteDetails(token);
        setState(() => _invite = invite);
      });

  Future<void> _accept() => _guard(() async {
        try {
          final employee = await widget.repo.acceptInvite(InviteLink.parse(_link.text)!);
          if (mounted) Navigator.of(context).pop(employee);
        } on ApiException catch (e) {
          if (e.code == 'EMAIL_NOT_VERIFIED' && widget.apiClient != null) {
            await widget.apiClient!.post('/api/auth/email/send');
            setState(() => _needsEmailCode = true);
            return;
          }
          rethrow;
        }
      });

  Future<void> _verifyAndAccept() => _guard(() async {
        await widget.apiClient!.post('/api/auth/email/verify', body: {'code': _code.text.trim()});
        setState(() => _needsEmailCode = false);
        final employee = await widget.repo.acceptInvite(InviteLink.parse(_link.text)!);
        if (mounted) Navigator.of(context).pop(employee);
      });

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    String? salary;
    if (invite != null) {
      final currency = Currency.fromCode(invite['targetCurrency']?.toString() ?? 'USD');
      salary = Money.fromMinor(invite['payrollAmountMinor'] ?? 0, currency).formatFormatted();
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Join your employer', style: FlowPayTypography.titleMedium),
          const SizedBox(height: 6),
          const Text('Your salary will be paid to this wallet, which only you control.', style: FlowPayTypography.bodySmall),
          const SizedBox(height: 14),
          if (invite == null) ...[
            TextField(
              key: const Key('accept_invite_link_field'),
              controller: _link,
              decoration: const InputDecoration(labelText: 'Invite link'),
            ),
            const SizedBox(height: 14),
            FlowPayButton(key: const Key('accept_invite_lookup'), text: 'Continue', isLoading: _busy, onPressed: _busy ? null : _lookup),
          ] else ...[
            Text('${invite['companyName']}', key: const Key('accept_invite_company'), style: FlowPayTypography.headingSm),
            const SizedBox(height: 4),
            Text('${invite['firstName']} ${invite['lastName']} · ${invite['email']}', style: FlowPayTypography.bodySmall),
            const SizedBox(height: 4),
            Text('Salary: $salary', style: FlowPayTypography.bodyMedium),
            const SizedBox(height: 14),
            if (_needsEmailCode) ...[
              Text('We emailed a 6-digit code to ${invite['email']}. Enter it to confirm the address is yours.', style: FlowPayTypography.bodySmall),
              TextField(
                key: const Key('accept_invite_email_code'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Email code', counterText: ''),
              ),
              const SizedBox(height: 10),
              FlowPayButton(key: const Key('accept_invite_verify'), text: 'Verify and accept', isLoading: _busy, onPressed: _busy ? null : _verifyAndAccept),
            ] else
              FlowPayButton(key: const Key('accept_invite_accept'), text: 'Accept invitation', isLoading: _busy, onPressed: _busy ? null : _accept),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: FlowPayColors.stateError)),
          ],
        ],
      ),
    );
  }
}
