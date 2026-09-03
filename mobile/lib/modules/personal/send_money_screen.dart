import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/safety/operation_preview.dart';
import '../../core/safety/signing_coordinator.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class SendMoneyScreen extends StatefulWidget {
  final AppState appState;

  const SendMoneyScreen({Key? key, required this.appState}) : super(key: key);

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

  Future<void> _handlePreview() async {
    setState(() => _isProcessing = true);
    try {
      final amount = Money.fromMajorString(_amountController.text, _selectedCurrency);
      final preview = await widget.appState.transferRepo.previewTransfer(
        amount: amount,
        recipient: _recipientController.text.trim(),
      );
      setState(() {
        _preview = preview;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleAuthorizeAndSign() async {
    // Prompt PIN dialog for on-device signing
    final pin = await _showPinDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Sign on device via SDK
      final sig = await SigningCoordinator.authorizeAndSign(
        hashToSign: '0x8f5156823a5c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        pin: pin,
      );

      // 2. Submit signed proposal to repository
      final result = await widget.appState.transferRepo.executeTransfer(
        previewId: _preview!.previewId,
        signature: sig,
      );

      setState(() {
        _isProcessing = false;
        _preview = null;
        _successMessage = 'Transfer of ${_amountController.text} ${_selectedCurrency.code} successfully settled on-chain!';
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<String?> _showPinDialog() async {
    final pinCtrl = TextEditingController(text: '123456');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlowPayColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Authorize Transfer', style: FlowPayTypography.headingSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 6-digit B-Key security PIN to sign the transaction hash on-device.',
              style: FlowPayTypography.bodyMd,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
              decoration: const InputDecoration(
                hintText: '••••••',
                hintStyle: TextStyle(color: FlowPayColors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: FlowPayColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FlowPayColors.textTertiary)),
          ),
          FlowPayButton(
            text: 'Sign on Device',
            onPressed: () => Navigator.pop(ctx, pinCtrl.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Send Money', style: FlowPayTypography.headingSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_successMessage != null) ...[
            FlowPayCard(
              backgroundColor: FlowPayColors.accent.withOpacity(0.15),
              border: Border.all(color: FlowPayColors.accent),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: FlowPayColors.accentLight, size: 40),
                  const SizedBox(height: 12),
                  Text(_successMessage!, style: FlowPayTypography.bodyLg, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FlowPayButton(
                    text: 'Done',
                    isSecondary: true,
                    onPressed: () => setState(() => _successMessage = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (_preview == null && _successMessage == null) ...[
            FlowPayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recipient Identifier', style: FlowPayTypography.caption),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _recipientController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'email@example.com or wallet address',
                      hintStyle: TextStyle(color: FlowPayColors.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(color: FlowPayColors.border),
                  const SizedBox(height: 12),
                  Text('Amount', style: FlowPayTypography.caption),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: FlowPayTypography.financialLarge,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                          ),
                        ),
                      ),
                      DropdownButton<Currency>(
                        value: _selectedCurrency,
                        dropdownColor: FlowPayColors.surfaceElevated,
                        underline: const SizedBox(),
                        items: [Currency.usd, Currency.ngn, Currency.mxn].map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.code, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (c) {
                          if (c != null) setState(() => _selectedCurrency = c);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FlowPayButton(
              text: 'Review & Verify',
              isLoading: _isProcessing,
              onPressed: _handlePreview,
            ),
          ],

          if (_preview != null) ...[
            // Explicit Approval & Preview Screen
            FlowPayCard(
              backgroundColor: FlowPayColors.surfaceElevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: FlowPayColors.primaryLight),
                      SizedBox(width: 8),
                      Text('Deterministic Verification', style: FlowPayTypography.headingSm),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewRow('Transfer Amount', _preview!.sourceAmount.formatFormatted()),
                  _buildPreviewRow('Estimated Network Fee', _preview!.estimatedFee.formatFormatted()),
                  const Divider(color: FlowPayColors.border),
                  _buildPreviewRow('Total Settlement', _preview!.totalAmount.formatFormatted(), isBold: true),
                  const SizedBox(height: 12),
                  _buildPreviewRow('Destination', _preview!.recipient),
                  const SizedBox(height: 16),
                  const StatusBadge(status: 'Awaiting On-Device PIN Sign'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FlowPayButton(
              text: 'Approve & Sign with PIN',
              isLoading: _isProcessing,
              onPressed: _handleAuthorizeAndSign,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _preview = null),
                child: const Text('Cancel', style: TextStyle(color: FlowPayColors.textTertiary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: FlowPayTypography.bodyMd),
          Text(
            value,
            style: isBold ? FlowPayTypography.headingSm : FlowPayTypography.bodyLg,
          ),
        ],
      ),
    );
  }
}
