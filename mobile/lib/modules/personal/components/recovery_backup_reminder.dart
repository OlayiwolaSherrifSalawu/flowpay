import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/stellar/stellar_key_vault.dart';
import '../../auth/recovery_key_backup_screen.dart';

/// Shown until the user has saved their recovery key. Without it, losing this
/// phone means losing the money in the wallet.
class RecoveryBackupReminder extends StatefulWidget {
  const RecoveryBackupReminder({super.key});

  @override
  State<RecoveryBackupReminder> createState() => _RecoveryBackupReminderState();
}

class _RecoveryBackupReminderState extends State<RecoveryBackupReminder> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final vault = StellarKeyVault.instance;
      final show = await vault.hasWallet() && !await vault.isBackedUp();
      if (mounted) setState(() => _show = show);
    } catch (_) {
      // If storage can't be read, the Security screen still shows the status.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Container(
      key: const Key('recovery_backup_reminder'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowPayColors.warning.withValues(alpha: 0.12),
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: FlowPayColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: FlowPayColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Back up your recovery key',
                    style: TextStyle(fontWeight: FontWeight.w800, color: FlowPayColors.textPrimaryOf(context))),
                const SizedBox(height: 2),
                Text("It's the only way to get your money back if you lose this phone.",
                    style: TextStyle(fontSize: 12, color: FlowPayColors.textSecondaryOf(context))),
              ],
            ),
          ),
          TextButton(
            key: const Key('recovery_backup_reminder_button'),
            onPressed: () async {
              await RecoveryKeyBackupScreen.revealWithPin(context);
              await _check();
            },
            child: const Text('Back up'),
          ),
        ],
      ),
    );
  }
}
