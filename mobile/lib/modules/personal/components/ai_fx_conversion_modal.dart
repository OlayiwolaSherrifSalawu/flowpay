import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/repositories/activity_repository.dart';
import '../../../core/state/personal_provider.dart';
import '../../../core/stellar/stellar_api.dart';
import '../../../core/stellar/stellar_batch_api.dart';
import '../../../core/stellar/stellar_key_vault.dart';
import '../../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../../core/wallet/wallet_signer.dart';

/// Convert between your own currencies.
///
/// Live: the quote IS a server-built Stellar path payment to yourself — the
/// numbers shown ("you receive at least …") are exactly what you sign.
/// Demo ([apiClient] == null): a clearly-labelled simulation at reference rates.
class AiFxConversionModal extends StatefulWidget {
  final PersonalProvider personalProvider;
  final Money initialAmount;
  final FlowPayApiClient? apiClient;
  final Currency initialTarget;

  const AiFxConversionModal({
    super.key,
    required this.personalProvider,
    required this.initialAmount,
    this.apiClient,
    this.initialTarget = Currency.ngn,
  });

  @override
  State<AiFxConversionModal> createState() => _AiFxConversionModalState();
}

class _AiFxConversionModalState extends State<AiFxConversionModal> {
  late final TextEditingController _amountController;
  late Currency _from;
  late Currency _to;
  BatchProposal? _quote;
  bool _busy = false;
  String? _error;

  /// Demo-only reference rates (units per 1 USD).
  static const _demoRates = {
    Currency.usd: 1.0,
    Currency.cad: 1.375,
    Currency.mxn: 17.5,
    Currency.gbp: 0.78,
    Currency.ngn: 1550.0,
  };

  bool get _isDemo => widget.apiClient == null;

  @override
  void initState() {
    super.initState();
    _from = stellarCurrencies.contains(widget.initialAmount.currency) ? widget.initialAmount.currency : Currency.usd;
    _to = widget.initialTarget == _from ? (_from == Currency.usd ? Currency.ngn : Currency.usd) : widget.initialTarget;
    _amountController = TextEditingController(text: widget.initialAmount.toMajorString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Null when the amount isn't a positive number — never a silent default.
  Money? get _amount {
    final text = _amountController.text.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
    final m = Money.fromMajorString(text, _from);
    return m.minorUnits > 0 ? m : null;
  }

  void _invalidateQuote() => setState(() {
        _quote = null;
        _error = null;
      });

  Future<void> _getQuote() async {
    final amount = _amount;
    if (amount == null) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await StellarBatchApi(widget.apiClient!).propose(
        legs: [
          {
            'label': 'Convert ${_from.code} → ${_to.code}',
            'to': 'self',
            'mode': 'exact_send',
            'amount': {'amountMinor': amount.amountMinor.toString(), 'currency': _from.code},
            'destCurrency': _to.code,
          },
        ],
        memo: 'FX ${_from.code}>${_to.code}',
        purpose: 'FX_CONVERT',
      );
      setState(() => _quote = quote);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not get a quote: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert() async {
    final amount = _amount;
    if (amount == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isDemo) {
      final ok = await WalletPinAuthSheet.show(
        context: context,
        title: 'Confirm conversion (demo)',
        subtitle: 'Demo mode — no real money moves.',
        onAuthorize: (pin) async {
          if (!await StellarKeyVault.instance.verifyPin(pin)) {
            throw const StellarVaultException(StellarVaultErrorCode.pinMismatch, 'Incorrect PIN.');
          }
          return 'ok';
        },
      );
      if (ok == null) return;
      final received = amount.majorUnits / _demoRates[_from]! * _demoRates[_to]!;
      widget.personalProvider.addActivity(ActivityModel(
        id: 'fx_demo_${DateTime.now().millisecondsSinceEpoch}',
        type: ActivityType.conversion,
        title: 'Demo FX: ${amount.formatFormatted()} → ${_to.code}',
        description: 'Simulated at demo reference rates (${received.toStringAsFixed(2)} ${_to.code})',
        amount: amount,
        currency: _from,
        status: FlowPayAppStatus.completed,
        timestamp: DateTime.now(),
      ));
      navigator.pop();
      return;
    }

    final quote = _quote;
    if (quote == null) return;
    BatchSettlement? settlement;
    final signed = await WalletPinAuthSheet.show(
      context: context,
      title: 'Confirm conversion',
      subtitle: 'Convert ${amount.formatFormatted()} to ${_to.code}',
      amountDisplay: amount.formatFormatted(),
      onAuthorize: (pin) => const StellarWalletSigner().signTransactionXdr(quote.signPayload, pin: pin),
    );
    if (signed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      settlement = await StellarBatchApi(widget.apiClient!).execute(proposalId: quote.proposalId, signedXdr: signed);
      await widget.personalProvider.refresh();
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        backgroundColor: FlowPayColors.primary,
        content: Text(settlement.isPending
            ? 'Conversion submitted — waiting for Stellar to confirm.'
            : 'Converted ${amount.formatFormatted()} to ${_to.code} on Stellar.'),
      ));
    } on ApiException catch (e) {
      setState(() => _error = 'Nothing was converted: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Nothing was converted: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _currencyPicker(Currency value, ValueChanged<Currency> onChanged, Key key) {
    return DropdownButton<Currency>(
      key: key,
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (final c in stellarCurrencies) DropdownMenuItem(value: c, child: Text('${c.flagEmoji} ${c.code}')),
      ],
      onChanged: (c) {
        if (c == null) return;
        onChanged(c);
        _invalidateQuote();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final leg = _quote?.legs.isNotEmpty == true ? _quote!.legs.first : null;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Convert currency', style: FlowPayTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                _isDemo ? 'Demo mode — simulated at reference rates.' : 'Settles instantly on Stellar using live market rates.',
                style: FlowPayTypography.captionStyle(color: muted),
              ),
              const SizedBox(height: 18),
              Text('YOU CONVERT', style: FlowPayTypography.caption.copyWith(color: muted)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('fx_amount_field'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: FlowPayTypography.amount(color: isDark ? Colors.white : FlowPayColors.lightTextPrimary),
                      onChanged: (_) => _invalidateQuote(),
                    ),
                  ),
                  _currencyPicker(_from, (c) => setState(() => _from = c), const Key('fx_from_picker')),
                ],
              ),
              const SizedBox(height: 12),
              Text('YOU RECEIVE', style: FlowPayTypography.caption.copyWith(color: muted)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      leg != null ? '≈ ${leg['destAmount']}' : (_isDemo ? 'Simulated on confirm' : 'Get a quote'),
                      key: const Key('fx_receive_amount'),
                      style: FlowPayTypography.amount(color: isDark ? Colors.white : FlowPayColors.lightTextPrimary),
                    ),
                  ),
                  _currencyPicker(_to, (c) => setState(() => _to = c), const Key('fx_to_picker')),
                ],
              ),
              if (leg != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Guaranteed at least ${leg['minDestAmount']} ${_to.code} (1% price protection). Quote valid until '
                  '${TimeOfDay.fromDateTime(_quote!.expiresAt.toLocal()).format(context)}.',
                  style: FlowPayTypography.captionStyle(color: muted),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: FlowPayColors.stateError)),
              ],
              const SizedBox(height: 20),
              if (_from == _to)
                Text('Choose two different currencies.', style: FlowPayTypography.captionStyle(color: muted))
              else
                FlowPayButton(
                  key: const Key('fx_primary_button'),
                  text: _isDemo || _quote != null ? 'Convert' : 'Get live quote',
                  isLoading: _busy,
                  size: FlowPayButtonSize.large,
                  onPressed: _busy ? null : (_isDemo || _quote != null ? _convert : _getQuote),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
