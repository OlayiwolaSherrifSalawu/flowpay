import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/design_system.dart';
import '../../stellar/stellar_key_vault.dart';

/// Bottom sheet that collects and confirms a new 6-digit wallet PIN.
/// Returns the PIN, or null when cancelled. The PIN is handed straight to the
/// key vault by the caller and never stored.
class CreatePinSheet extends StatefulWidget {
  const CreatePinSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FlowPayRadii.sheetValue)),
      ),
      builder: (_) => const CreatePinSheet(),
    );
  }

  @override
  State<CreatePinSheet> createState() => _CreatePinSheetState();
}

class _CreatePinSheetState extends State<CreatePinSheet> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinCtrl.text;
    if (pin.length != StellarKeyVault.pinLength) {
      setState(() => _error = 'PIN must be ${StellarKeyVault.pinLength} digits.');
      return;
    }
    if (pin != _confirmCtrl.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  Widget _field(TextEditingController ctrl, String label, Key key) {
    return TextField(
      key: key,
      controller: ctrl,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: StellarKeyVault.pinLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: (_) => setState(() => _error = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create your wallet PIN', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your PIN encrypts your wallet key on this device. FlowPay never sees it and cannot reset it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _field(_pinCtrl, 'New PIN', const Key('create_pin_field')),
          const SizedBox(height: 12),
          _field(_confirmCtrl, 'Confirm PIN', const Key('create_pin_confirm_field')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: FlowPayColors.stateError)),
          ],
          const SizedBox(height: 20),
          FlowPayButton(
            key: const Key('create_pin_submit'),
            text: 'Create wallet',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
