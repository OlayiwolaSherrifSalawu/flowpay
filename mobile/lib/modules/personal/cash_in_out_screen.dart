import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/design_system.dart';
import '../../core/state/app_state.dart';
import '../../core/stellar/anchors/anchor_service.dart';
import '../../core/stellar/stellar_api.dart';
import '../../core/stellar/stellar_network.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';

/// Move money between a bank and this wallet through a Stellar anchor (SEP-24).
///
/// The anchor runs its own page for identity checks (KYC) and bank details;
/// FlowPay only authenticates the wallet (SEP-10), tracks the transfer, and
/// signs the payment the anchor asks for on withdrawals.
class CashInOutScreen extends StatefulWidget {
  final AppState appState;
  const CashInOutScreen({super.key, required this.appState});

  @override
  State<CashInOutScreen> createState() => _CashInOutScreenState();
}

class _CashInOutScreenState extends State<CashInOutScreen> {
  late final AnchorService _anchors = AnchorService(api: StellarApi(widget.appState.apiClient));
  final _amount = TextEditingController(text: '5');
  final List<AnchorAsset> _assets = AnchorConfig.forNetwork(StellarNetwork.current);
  late AnchorAsset? _asset = _assets.isNotEmpty ? _assets.first : null;

  String? _jwt;
  String? _transferId;
  String? _interactiveUrl;
  AnchorTransfer? _transfer;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _start({required bool deposit}) async {
    final asset = _asset;
    if (asset == null) return;
    setState(() {
      _error = null;
      _transfer = null;
    });
    final ok = await WalletPinAuthSheet.show(
      context: context,
      title: deposit ? 'Add money from your bank' : 'Send money to your bank',
      subtitle: 'Your PIN signs you in to ${asset.domain}.',
      onAuthorize: (pin) async {
        final jwt = await _anchors.authenticate(asset, pin: pin);
        await _anchors.ensureTrustline(asset, pin: pin);
        final started = deposit
            ? await _anchors.startDeposit(asset, jwt, amount: _amount.text.trim())
            : await _anchors.startWithdraw(asset, jwt, amount: _amount.text.trim());
        _jwt = jwt;
        _transferId = started.id;
        _interactiveUrl = started.url;
        return 'started';
      },
    );
    if (ok == null || !mounted) return;
    await _openAnchorPage();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    await _refresh();
  }

  Future<void> _openAnchorPage() async {
    final url = _interactiveUrl;
    if (url == null) return;
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      setState(() => _error = 'Could not open the anchor page. Copy this link into your browser:\n$url');
    }
  }

  Future<void> _refresh() async {
    final asset = _asset, jwt = _jwt, id = _transferId;
    if (asset == null || jwt == null || id == null) return;
    try {
      final t = await _anchors.status(asset, jwt, id);
      if (!mounted) return;
      setState(() => _transfer = t);
      if (t.isFinal) _poll?.cancel();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read the transfer status: $e');
    }
  }

  Future<void> _payAnchor() async {
    final asset = _asset, t = _transfer;
    if (asset == null || t == null) return;
    setState(() => _busy = true);
    try {
      final hash = await WalletPinAuthSheet.show(
        context: context,
        title: 'Send ${t.amountIn} ${asset.code} to the anchor',
        subtitle: 'This pays out to your bank.',
        onAuthorize: (pin) => _anchors.sendWithdrawalPayment(asset, t, pin: pin),
      );
      if (hash != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent on Stellar (${hash.substring(0, 8)}…). The anchor will pay your bank.')));
        await _refresh();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _transfer;
    return Scaffold(
      appBar: AppBar(title: const Text('Bank transfers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_assets.isEmpty)
            const Text(
              'Bank transfers are not available on this network yet. FlowPay will list licensed anchors here.',
              key: Key('cash_no_anchors'),
            )
          else ...[
            const Text('Move money between your bank and FlowPay', style: FlowPayTypography.titleMedium),
            const SizedBox(height: 6),
            Text(
              'A licensed Stellar anchor handles the bank side, including identity checks. '
              '${StellarNetwork.current.isTestnet ? 'On testnet this is the Stellar test anchor: a simulated bank with test USDC (up to 10).' : ''}',
              style: FlowPayTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButton<AnchorAsset>(
              value: _asset,
              isExpanded: true,
              items: [for (final a in _assets) DropdownMenuItem(value: a, child: Text(a.label))],
              onChanged: (a) => setState(() => _asset = a),
            ),
            TextField(
              key: const Key('cash_amount_field'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount (${_asset?.code})'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FlowPayButton(key: const Key('cash_deposit'), text: 'Add money', onPressed: () => _start(deposit: true))),
              const SizedBox(width: 12),
              Expanded(
                child: FlowPayButton(
                  key: const Key('cash_withdraw'),
                  text: 'Cash out',
                  variant: FlowPayButtonVariant.secondary,
                  onPressed: () => _start(deposit: false),
                ),
              ),
            ]),
          ],
          if (t != null) ...[
            const SizedBox(height: 24),
            Text('${t.kind == 'deposit' ? 'Deposit' : 'Withdrawal'} status', style: FlowPayTypography.titleMedium),
            const SizedBox(height: 6),
            Text(t.status.replaceAll('_', ' '), key: const Key('cash_status')),
            if (t.message != null) Text(t.message!, style: FlowPayTypography.bodySmall),
            const SizedBox(height: 10),
            if (!t.isFinal && _interactiveUrl != null)
              TextButton(onPressed: _openAnchorPage, child: const Text('Open the anchor page again')),
            if (t.awaitingUserPayment)
              FlowPayButton(
                key: const Key('cash_pay_anchor'),
                text: 'Send ${t.amountIn} ${_asset?.code}',
                isLoading: _busy,
                onPressed: _busy ? null : _payAnchor,
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: FlowPayColors.stateError)),
          ],
        ],
      ),
    );
  }
}
