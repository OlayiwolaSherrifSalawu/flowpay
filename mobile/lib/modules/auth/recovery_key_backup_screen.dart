import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/design_system.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../core/wallet/wallet_service.dart';

/// "Save your recovery key". FlowPay never holds users' keys, so this key is the
/// only way back into the money if the phone is lost. The user confirms the
/// backup by re-typing the key's last four characters.
///
/// Pops `true` once backed up, `false` if the user chose to do it later.
class RecoveryKeyBackupScreen extends StatefulWidget {
  final String recoveryKey;
  final WalletService walletService;
  /// Sign-up offers "later"; from Security the user can simply go back.
  final bool allowLater;

  const RecoveryKeyBackupScreen({
    super.key,
    required this.recoveryKey,
    required this.walletService,
    this.allowLater = true,
  });

  /// PIN → recovery key → this screen. The key is only ever revealed on request.
  /// Returns true if the user confirmed the backup.
  static Future<bool> revealWithPin(BuildContext context, {WalletService walletService = const StellarWalletService()}) async {
    final key = await WalletPinAuthSheet.show(
      context: context,
      title: 'Show recovery key',
      subtitle: 'Enter your PIN to reveal it',
      onAuthorize: (pin) => walletService.exportRecoveryKey(pin: pin),
    );
    if (key == null || !context.mounted) return false;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RecoveryKeyBackupScreen(recoveryKey: key, walletService: walletService, allowLater: false),
    ));
    return saved == true;
  }

  @override
  State<RecoveryKeyBackupScreen> createState() => _RecoveryKeyBackupScreenState();
}

class _RecoveryKeyBackupScreenState extends State<RecoveryKeyBackupScreen> {
  bool _revealed = false;
  bool _saving = false;
  String? _error;
  final _confirm = TextEditingController();

  String get _lastFour => widget.recoveryKey.substring(widget.recoveryKey.length - 4);

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_confirm.text.trim().toUpperCase() != _lastFour) {
      setState(() => _error = "That doesn't match the end of your recovery key.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.walletService.markRecoveryKeyBackedUp();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = FlowPayColors.textPrimaryOf(context);
    final muted = FlowPayColors.textSecondaryOf(context);
    final key = widget.recoveryKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery key'), automaticallyImplyLeading: !widget.allowLater),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('Save your recovery key', style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 10),
            Text(
              "Your money lives in a wallet that only this phone controls. If you lose the phone or forget your PIN, "
              "this key is the only way to get it back. FlowPay can't recover it for you.",
              style: FlowPayTypography.body(color: muted).copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              key: const Key('recovery_key_box'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlowPayColors.surfaceElevatedOf(context),
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(color: FlowPayColors.borderOf(context)),
              ),
              child: _revealed
                  ? SelectableText(key,
                      key: const Key('recovery_key_text'),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 15, height: 1.5, letterSpacing: 0.5, color: text))
                  : Column(
                      children: [
                        Text('•' * 24, style: TextStyle(fontSize: 18, letterSpacing: 2, color: muted)),
                        const SizedBox(height: 10),
                        FlowPayButton(
                          key: const Key('recovery_key_reveal'),
                          text: 'Reveal key',
                          icon: Icons.visibility_rounded,
                          variant: FlowPayButtonVariant.secondary,
                          onPressed: () => setState(() => _revealed = true),
                        ),
                        const SizedBox(height: 6),
                        Text('Make sure no one can see your screen.', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
            ),
            if (_revealed) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('recovery_key_copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: key));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied. Paste it somewhere safe, then clear your clipboard.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (final tip in const [
              'Write it on paper or save it in a password manager.',
              "Never share it. Anyone with this key can move your money.",
              'FlowPay will never ask you for it.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: FlowPayColors.accentTextOf(context)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: TextStyle(fontSize: 13, color: muted))),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Text('To confirm, type the last 4 characters of your key', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('recovery_key_confirm_field'),
              controller: _confirm,
              enabled: _revealed,
              maxLength: 4,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: _revealed ? 'e.g. ${'X' * 4}' : 'Reveal the key first', errorText: _error, counterText: ''),
              onSubmitted: (_) => _done(),
            ),
            const SizedBox(height: 14),
            FlowPayButton(
              key: const Key('recovery_key_done'),
              text: "I've saved it",
              isFullWidth: true,
              isLoading: _saving,
              onPressed: _revealed && !_saving ? _done : null,
            ),
            if (widget.allowLater) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('recovery_key_later'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("I'll do it later (you'll be reminded)"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
