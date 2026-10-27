import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/money/currency.dart';
import '../../../core/network/api_client.dart';
import '../../../core/stellar/stellar_api.dart';
import '../../../core/stellar/stellar_network.dart';

/// Receive money: shows this wallet's real Stellar account ID as text + QR.
/// Money only arrives when someone actually pays it. On testnet, offers a
/// clearly-labelled "Get test funds" button.
class ReceiveSheet extends StatefulWidget {
  final String accountId;
  final Currency currency;
  final StellarApi? api;
  final VoidCallback? onFunded;

  const ReceiveSheet({super.key, required this.accountId, required this.currency, this.api, this.onFunded});

  static Future<void> show(BuildContext context, {required String accountId, required Currency currency, StellarApi? api, VoidCallback? onFunded}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.sheet),
      builder: (_) => ReceiveSheet(accountId: accountId, currency: currency, api: api, onFunded: onFunded),
    );
  }

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  bool _claiming = false;
  String? _message;
  bool _messageIsError = false;

  PaymentName? _name;
  bool _savingName = false;
  String? _nameError;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final name = await api.paymentName();
      if (mounted) setState(() => _name = name);
    } catch (_) {
      // Optional feature: the account address below still works without it.
    }
  }

  Future<void> _claimName() async {
    final api = widget.api;
    if (api == null) return;
    setState(() {
      _savingName = true;
      _nameError = null;
    });
    try {
      final name = await api.claimPaymentName(_nameController.text);
      if (mounted) setState(() => _name = name);
    } on ApiException catch (e) {
      if (mounted) setState(() => _nameError = e.message);
    } catch (e) {
      if (mounted) setState(() => _nameError = 'Could not save your payment name: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Widget _buildPaymentName(Color textColor, Color mutedColor) {
    final name = _name;
    if (name == null) return const SizedBox.shrink();
    final address = name.stellarAddress;
    if (address != null) {
      return Column(
        children: [
          Text('Your payment address', style: FlowPayTypography.captionStyle(color: mutedColor)),
          const SizedBox(height: 4),
          InkWell(
            key: const Key('receive_payment_name'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$address copied')));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(address,
                        style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: textColor)),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded, size: 16, color: mutedColor),
                ],
              ),
            ),
          ),
          Text('Anyone on Stellar can pay this address.', style: FlowPayTypography.captionStyle(color: mutedColor)),
          const SizedBox(height: 14),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Claim a payment address', style: FlowPayTypography.captionStyle(color: mutedColor)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('receive_payment_name_field'),
                controller: _nameController,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'yourname',
                  suffixText: name.homeDomain != null ? '*${name.homeDomain}' : null,
                  errorText: _nameError,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FlowPayButton(
              key: const Key('receive_payment_name_claim'),
              text: 'Claim',
              isLoading: _savingName,
              onPressed: _savingName ? null : _claimName,
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Future<void> _claimTestFunds() async {
    final api = widget.api;
    if (api == null) return;
    setState(() {
      _claiming = true;
      _message = null;
    });
    try {
      final amount = await api.claimTestFunds(widget.accountId, widget.currency);
      setState(() {
        _message = 'Added ${amount.formatFormatted()} of TEST funds (testnet only — not real money).';
        _messageIsError = false;
      });
      widget.onFunded?.call();
    } on ApiException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Could not get test funds: $e';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final network = StellarNetwork.current;
    final textColor = isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary;
    final mutedColor = isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Receive ${widget.currency.code}',
                  style: FlowPayTypography.headingSm.copyWith(fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 6),
              Text(
                'Share your FlowPay address. Senders on Stellar can pay any currency you hold.',
                textAlign: TextAlign.center,
                style: FlowPayTypography.captionStyle(color: mutedColor),
              ),
              const SizedBox(height: 16),
              _buildPaymentName(textColor, mutedColor),
              Container(
                key: const Key('receive_qr'),
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: FlowPayRadii.input),
                child: QrImageView(data: widget.accountId, size: 200),
              ),
              const SizedBox(height: 14),
              SelectableText(
                widget.accountId,
                key: const Key('receive_account_id'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textColor),
              ),
              const SizedBox(height: 10),
              FlowPayButton(
                key: const Key('receive_copy_address'),
                text: 'Copy address',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.accountId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
                },
              ),
              if (network.isTestnet && widget.api != null) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                Text('Testnet', style: FlowPayTypography.captionStyle(color: FlowPayColors.warning)),
                const SizedBox(height: 6),
                FlowPayButton(
                  key: const Key('receive_get_test_funds'),
                  text: _claiming ? 'Requesting…' : 'Get test ${widget.currency.code}',
                  isLoading: _claiming,
                  onPressed: _claiming ? null : _claimTestFunds,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _messageIsError ? FlowPayColors.stateError : FlowPayColors.success, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
