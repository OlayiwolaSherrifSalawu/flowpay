import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/safety/operation_preview.dart';
import '../../core/safety/signing_coordinator.dart';
import '../../core/state/app_state.dart';

class SendMoneyScreen extends StatefulWidget {
  final AppState appState;

  const SendMoneyScreen({super.key, required this.appState});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _amountController = TextEditingController(text: '150.00');
  final _recipientController = TextEditingController(text: 'bunch.dillon@example.ng');
  Currency _selectedCurrency = Currency.usd;

  bool _isProcessing = false;
  OperationPreview? _preview;
  String? _successMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _handlePreview() async {
    setState(() => _isProcessing = true);
    try {
      final amount = Money.fromMajorString(_amountController.text, _selectedCurrency);
      final preview = await widget.appState.transferRepo.previewTransfer(
        amount: amount,
        recipient: _recipientController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleAuthorizeAndSign() async {
    final pin = await _showPinDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final sig = await SigningCoordinator.authorizeAndSign(
        hashToSign: '0x8f5156823a5c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        pin: pin,
      );

      await widget.appState.transferRepo.executeTransfer(
        previewId: _preview!.previewId,
        signature: sig,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _preview = null;
        _successMessage =
            'Transfer of ${_amountController.text} ${_selectedCurrency.code} successfully settled on-chain!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<String?> _showPinDialog() async {
    final pinCtrl = TextEditingController(text: '123456');

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMoniColors.offbrand900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: BMoniColors.offbrand700),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: BMoniColors.brand400, size: 22),
            SizedBox(width: 8),
            Text(
              'Authorize Transfer',
              style: TextStyle(
                color: BMoniColors.grey50,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 6-digit B-Key security PIN to sign the transaction hash on-device.',
              style: TextStyle(color: BMoniColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BMoniColors.grey50,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: BMoniColors.offbrand800,
                hintText: '••••••',
                hintStyle: const TextStyle(
                  color: BMoniColors.grey600,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BMoniColors.offbrand700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: BMoniColors.brand500, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BMoniColors.grey400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BMoniColors.brand500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, pinCtrl.text),
            child: const Text('Sign on Device'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    Widget content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Top BMONI Security Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF38103A), Color(0xFF1E0720)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: BMoniColors.brand400, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMONI Deterministic Safety Rail',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BMoniColors.grey50,
                      ),
                    ),
                    Text(
                      'Zero AI money movement • PIN hardware signed',
                      style: TextStyle(fontSize: 11, color: BMoniColors.grey400),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BMoniColors.brand500.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EVM Live',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: BMoniColors.brand300,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_successMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BMoniColors.offbrand900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BMoniColors.success400),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: BMoniColors.success400, size: 48),
                const SizedBox(height: 12),
                Text(
                  _successMessage!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BMoniColors.grey50,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                BMoniButton(
                  text: 'Make Another Transfer',
                  variant: BMoniButtonVariant.secondary,
                  onPressed: () => setState(() => _successMessage = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_preview == null && _successMessage == null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BMoniColors.offbrand900,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BMoniColors.offbrand700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recipient Identifier',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BMoniColors.grey400,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipientController,
                  style: const TextStyle(
                    color: BMoniColors.grey50,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search_outlined, color: BMoniColors.brand400, size: 20),
                    hintText: 'bunch.dillon@example.ng or 0x...',
                    hintStyle: const TextStyle(color: BMoniColors.grey600, fontSize: 14),
                    filled: true,
                    fillColor: BMoniColors.offbrand800,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BMoniColors.offbrand700),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BMoniColors.offbrand700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BMoniColors.brand500, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transfer Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BMoniColors.grey400,
                  ),
                ),
                const SizedBox(height: 8),
                FlowPayAmountField(
                  controller: _amountController,
                  currencyCode: _selectedCurrency.code,
                  currencySymbol: _selectedCurrency.symbol,
                  onCurrencyTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: BMoniColors.offbrand900,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SectionHeader(
                              title: 'Select Transfer Currency',
                              backgroundColor: Colors.transparent,
                              showBottomDivider: true,
                              titleStyle: TextStyle(
                                color: BMoniColors.grey50,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...[Currency.usd, Currency.ngn, Currency.mxn].map((c) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: BMoniColors.offbrand800,
                                  child: Text(
                                    c.symbol,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: BMoniColors.brand300,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(
                                    color: BMoniColors.grey50,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'BMONI ${c.stablecoinToken}',
                                  style: const TextStyle(color: BMoniColors.grey400, fontSize: 12),
                                ),
                                trailing: _selectedCurrency == c
                                    ? const Icon(Icons.check_circle, color: BMoniColors.brand400)
                                    : null,
                                onTap: () {
                                  setState(() => _selectedCurrency = c);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BMoniButton(
            text: 'Review & Verify',
            variant: BMoniButtonVariant.primary,
            size: BMoniButtonSize.large,
            isLoading: _isProcessing,
            onPressed: _handlePreview,
          ),
        ],

        if (_preview != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BMoniColors.offbrand900,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BMoniColors.brand500.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_outlined, color: BMoniColors.brand400, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Deterministic Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BMoniColors.grey50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPreviewRow('Transfer Amount', _preview!.sourceAmount.formatFormatted()),
                _buildPreviewRow('Estimated Network Fee', _preview!.estimatedFee.formatFormatted()),
                const Divider(color: BMoniColors.offbrand700, height: 24),
                _buildPreviewRow(
                  'Total Settlement',
                  _preview!.totalAmount.formatFormatted(),
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildPreviewRow('Destination', _preview!.recipient),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BMoniColors.warning400.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BMoniColors.warning400.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: BMoniColors.warning400),
                      SizedBox(width: 6),
                      Text(
                        'Awaiting On-Device PIN Signature',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BMoniColors.warning400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BMoniButton(
            text: 'Approve & Sign with PIN',
            variant: BMoniButtonVariant.primary,
            size: BMoniButtonSize.large,
            isLoading: _isProcessing,
            onPressed: _handleAuthorizeAndSign,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _preview = null),
              child: const Text('Cancel Transfer', style: TextStyle(color: BMoniColors.grey400)),
            ),
          ),
        ],
      ],
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Send Money'),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: BMoniColors.grey400, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: isBold ? BMoniColors.brand300 : BMoniColors.grey50,
              fontSize: isBold ? 17 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
