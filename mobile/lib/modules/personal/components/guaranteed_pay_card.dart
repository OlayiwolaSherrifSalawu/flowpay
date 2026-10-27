import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/repositories/payroll_repository.dart';
import '../../../core/state/app_state.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../../core/wallet/wallet_signer.dart';

/// "Your pay is guaranteed": salary an employer locked for this user in the
/// Soroban PayrollVault. Hidden when nothing is reserved.
class GuaranteedPayCard extends StatefulWidget {
  final AppState appState;
  const GuaranteedPayCard({super.key, required this.appState});

  @override
  State<GuaranteedPayCard> createState() => _GuaranteedPayCardState();
}

class _GuaranteedPayCardState extends State<GuaranteedPayCard> {
  List<GuaranteedPayModel> _pay = const [];
  int? _claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pay = await widget.appState.payrollRepo.getMyGuaranteedPay();
      if (mounted) setState(() => _pay = pay.where((p) => !p.paid).toList());
    } catch (_) {
      // Optional card: if it can't load, the rest of the dashboard is unaffected.
    }
  }

  Future<void> _claim(GuaranteedPayModel p) async {
    final repo = widget.appState.payrollRepo;
    setState(() => _claimingId = p.payrollId);
    try {
      final proposal = await repo.proposeGuaranteeClaim(p.payrollId);
      if (!mounted) return;
      const signer = StellarWalletSigner();
      final signed = await WalletPinAuthSheet.show(
        context: context,
        title: 'Claim your pay',
        subtitle: 'Signs the claim on this device',
        amountDisplay: '\$${p.amountUsd}',
        onAuthorize: (pin) => signer.signTransactionXdr(proposal.signPayload!, pin: pin),
      );
      if (signed == null) return;
      final r = await repo.executeGuaranteeClaim(proposalId: proposal.proposalId, signedPayload: signed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\$${r.amountUsd ?? p.amountUsd} received.')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  String _when(DateTime t) {
    final d = t.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_pay.isEmpty) return const SizedBox.shrink();
    final text = FlowPayColors.textPrimaryOf(context);
    final muted = FlowPayColors.textSecondaryOf(context);
    return Column(
      children: [
        for (final p in _pay)
          Container(
            key: Key('guaranteed_pay_${p.payrollId}'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FlowPayColors.surfaceOf(context),
              borderRadius: FlowPayRadii.card,
              border: Border.all(color: FlowPayColors.accentTextOf(context).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: FlowPayColors.accentTextOf(context), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.isUnlocked ? "It's payday" : 'Your pay is guaranteed',
                          style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: text)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('\$${p.amountUsd}', style: FlowPayTypography.headingSm.copyWith(fontSize: 26, fontWeight: FontWeight.w800, color: text)),
                Text('≈ ${p.coversFormatted} at the rate when it was locked', style: FlowPayTypography.captionStyle(color: muted)),
                const SizedBox(height: 6),
                Text(
                  p.isUnlocked
                      ? 'Unlocked. Claim it now, or it will be sent to you automatically.'
                      : 'Locked in a Stellar smart contract until ${_when(p.unlockAt)}. Your employer can\'t take it back.',
                  style: FlowPayTypography.captionStyle(color: muted).copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (p.explorerUrl != null)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(p.explorerUrl!), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('See it on-chain'),
                      ),
                    if (p.isUnlocked)
                      FlowPayButton(
                        key: Key('guaranteed_pay_claim_${p.payrollId}'),
                        text: 'Claim \$${p.amountUsd}',
                        isLoading: _claimingId == p.payrollId,
                        onPressed: _claimingId == null ? () => _claim(p) : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
