import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/repositories/payroll_repository.dart';
import '../../../core/state/app_state.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../../core/wallet/wallet_signer.dart';

/// Payday guarantee (Soroban PayrollVault): the employer locks next payday's
/// payroll on-chain; employees can see it's reserved; it's released on payday.
class PaydayGuaranteeSection extends StatefulWidget {
  final AppState appState;
  const PaydayGuaranteeSection({super.key, required this.appState});

  @override
  State<PaydayGuaranteeSection> createState() => _PaydayGuaranteeSectionState();
}

class _PaydayGuaranteeSectionState extends State<PaydayGuaranteeSection> {
  List<PayrollGuaranteeModel> _guarantees = const [];
  bool _loading = true;
  String? _error;
  int? _releasingId;

  PayrollRepository get _repo => widget.appState.payrollRepo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getGuarantees();
      if (mounted) setState(() => _guarantees = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<PayrollGuaranteeModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.sheet),
      builder: (_) => _GuaranteeSheet(appState: widget.appState),
    );
    if (created != null) await _load();
  }

  Future<void> _release(PayrollGuaranteeModel g) async {
    setState(() => _releasingId = g.payrollId);
    try {
      final results = await _repo.releaseGuarantee(g.payrollId);
      final failed = results.where((r) => r.status == 'FAILED' || r.status == 'PENDING').toList();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed.isEmpty
            ? 'Payday released: ${results.where((r) => r.status == 'COMPLETED').length} salaries paid.'
            : '${failed.length} not paid yet: ${failed.map((r) => '${r.name} (${r.error ?? r.status})').join(', ')}'),
      ));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _releasingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = FlowPayColors.textPrimaryOf(context);
    final muted = FlowPayColors.textSecondaryOf(context);

    return Container(
      key: const Key('payday_guarantee_section'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlowPayColors.surfaceOf(context),
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: FlowPayColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: FlowPayColors.accentTextOf(context), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Payday guarantee',
                    style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: text)),
              ),
              Text(widget.appState.isDemo ? 'DEMO' : 'SOROBAN',
                  style: FlowPayTypography.eyebrow(color: FlowPayColors.accentTextOf(context))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Lock next payday's salaries in a Stellar smart contract. Your team can see their pay is reserved, and you can't take it back before payday.",
            style: FlowPayTypography.captionStyle(color: muted).copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          FlowPayButton(
            key: const Key('guarantee_create_button'),
            text: 'Guarantee next payday',
            icon: Icons.verified_user_outlined,
            isFullWidth: true,
            onPressed: _create,
          ),
          if (_loading) ...[
            const SizedBox(height: 14),
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ] else if (_error != null) ...[
            const SizedBox(height: 12),
            Text('Could not load guarantees: $_error', style: const TextStyle(color: FlowPayColors.stateError, fontSize: 12)),
          ] else
            for (final g in _guarantees) ...[
              const SizedBox(height: 12),
              _GuaranteeTile(
                guarantee: g,
                isDark: isDark,
                releasing: _releasingId == g.payrollId,
                onRelease: g.isUnlocked && !g.isFullyPaid ? () => _release(g) : null,
              ),
            ],
        ],
      ),
    );
  }
}

String _when(DateTime t) {
  final local = t.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${months[local.month - 1]} ${local.day}, $hh:$mm';
}

Future<void> _openExplorer(BuildContext context, String? url) async {
  if (url == null) return;
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
  }
}

class _GuaranteeTile extends StatelessWidget {
  final PayrollGuaranteeModel guarantee;
  final bool isDark;
  final bool releasing;
  final VoidCallback? onRelease;

  const _GuaranteeTile({required this.guarantee, required this.isDark, required this.releasing, this.onRelease});

  @override
  Widget build(BuildContext context) {
    final g = guarantee;
    final text = FlowPayColors.textPrimaryOf(context);
    final muted = FlowPayColors.textSecondaryOf(context);
    final status = g.isFullyPaid
        ? 'All paid'
        : g.isUnlocked
            ? 'Payday — ready to release'
            : 'Locked until ${_when(g.unlockAt)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FlowPayColors.surfaceElevatedOf(context), borderRadius: FlowPayRadii.cardSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('\$${g.totalUsd} for ${g.entries.length} ${g.entries.length == 1 ? 'person' : 'people'}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: text)),
              ),
              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g.isFullyPaid ? FlowPayColors.success : FlowPayColors.accentTextOf(context))),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in g.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(e.paid ? Icons.check_circle_rounded : Icons.lock_rounded, size: 14, color: e.paid ? FlowPayColors.success : muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.name, style: TextStyle(fontSize: 13, color: text))),
                  Text('\$${e.amountUsd}', style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (g.explorerUrl != null)
                TextButton.icon(
                  onPressed: () => _openExplorer(context, g.explorerUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View on-chain'),
                ),
              if (onRelease != null)
                FlowPayButton(
                  key: Key('guarantee_release_${g.payrollId}'),
                  text: 'Release payday',
                  isLoading: releasing,
                  onPressed: releasing ? null : onRelease,
                ),
            ],
          ),
          if (g.isDemo) Text('Demo mode: nothing is locked on Stellar.', style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

/// Pick a payday → review the real contract call → sign with PIN → locked.
class _GuaranteeSheet extends StatefulWidget {
  final AppState appState;
  const _GuaranteeSheet({required this.appState});

  @override
  State<_GuaranteeSheet> createState() => _GuaranteeSheetState();
}

class _GuaranteeSheetState extends State<_GuaranteeSheet> {
  // A 2-minute payday exists only on testnet, for demos and testing.
  static final _choices = <(String, Duration)>[
    if (StellarNetwork.current.isTestnet) ('In 2 minutes (testnet)', const Duration(minutes: 2)),
    ('In 10 minutes', const Duration(minutes: 10)),
    ('In 7 days', const Duration(days: 7)),
    ('In 14 days', const Duration(days: 14)),
    ('In 30 days', const Duration(days: 30)),
  ];
  // Default: one week out.
  int _choice = _choices.indexWhere((c) => c.$2 == const Duration(days: 7));
  PayrollGuaranteeProposal? _proposal;
  bool _busy = false;
  String? _error;

  Future<void> _review() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await widget.appState.payrollRepo.proposeGuarantee(DateTime.now().add(_choices[_choice].$2));
      if (mounted) setState(() => _proposal = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lock() async {
    final p = _proposal!;
    const signer = StellarWalletSigner();
    final signed = await WalletPinAuthSheet.show(
      context: context,
      title: 'Lock payday on Stellar',
      subtitle: 'Signs the contract call on this device',
      amountDisplay: '\$${p.totalUsd}',
      onAuthorize: (pin) async {
        if (p.signPayload == null) {
          await signer.signMessage('demo-guarantee:${p.proposalId}', pin: pin);
          return 'demo';
        }
        return signer.signTransactionXdr(p.signPayload!, pin: pin);
      },
    );
    if (signed == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = await widget.appState.payrollRepo.executeGuarantee(proposalId: p.proposalId, signedPayload: p.signPayload == null ? null : signed);
      if (mounted) Navigator.of(context).pop(g);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = FlowPayColors.textPrimaryOf(context);
    final muted = FlowPayColors.textSecondaryOf(context);
    final p = _proposal;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Guarantee next payday', style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: text)),
              const SizedBox(height: 6),
              Text('Salaries are reserved in USD at today\'s rates and released to each employee on payday.',
                  style: FlowPayTypography.captionStyle(color: muted)),
              const SizedBox(height: 14),
              if (p == null) ...[
                Text('Payday', style: FlowPayTypography.eyebrow(color: muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _choices.length; i++)
                      ChoiceChip(
                        key: Key('guarantee_choice_$i'),
                        label: Text(_choices[i].$1),
                        selected: _choice == i,
                        onSelected: _busy ? null : (_) => setState(() => _choice = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FlowPayButton(
                  key: const Key('guarantee_review_button'),
                  text: 'Review',
                  isFullWidth: true,
                  isLoading: _busy,
                  onPressed: _busy ? null : _review,
                ),
              ] else ...[
                Text('Unlocks ${_when(p.unlockAt)}', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
                const SizedBox(height: 10),
                for (final e in p.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.name, style: TextStyle(color: text))),
                        Text('\$${e.amountUsd}', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
                        const SizedBox(width: 6),
                        Text('≈ ${e.coversFormatted}', style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ),
                  ),
                for (final s in p.skipped) Text('Not included — $s', style: TextStyle(fontSize: 12, color: muted)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: Text('Total to lock', style: TextStyle(color: muted))),
                    Text('\$${p.totalUsd}', style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: text)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "You can't withdraw it before payday. Anything unclaimed comes back to you 30 days after payday.",
                  style: FlowPayTypography.captionStyle(color: muted),
                ),
                const SizedBox(height: 14),
                FlowPayButton(
                  key: const Key('guarantee_lock_button'),
                  text: 'Lock \$${p.totalUsd}',
                  icon: Icons.lock_rounded,
                  isFullWidth: true,
                  isLoading: _busy,
                  onPressed: _busy ? null : _lock,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: FlowPayColors.stateError, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
