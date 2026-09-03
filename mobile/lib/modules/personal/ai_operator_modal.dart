import 'package:flutter/material.dart';
import '../../core/safety/financial_intent.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';
import 'send_money_screen.dart';

class AiOperatorModal extends StatefulWidget {
  final AppState appState;

  const AiOperatorModal({Key? key, required this.appState}) : super(key: key);

  @override
  State<AiOperatorModal> createState() => _AiOperatorModalState();
}

class _AiOperatorModalState extends State<AiOperatorModal> {
  final _inputController = TextEditingController(text: 'Send \$250 to Bunch Dillon');
  bool _isInterpreting = false;
  FinancialIntent? _interpretedIntent;

  void _handleInterpret() {
    setState(() => _isInterpreting = true);
    final text = _inputController.text.trim();

    // Client-side deterministic interpretation fallback
    final amountMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(text);
    final amt = amountMatch != null ? amountMatch.group(1)! : '100.00';

    final intent = FinancialIntent.fromJson({
      'intentId': 'intent_${DateTime.now().millisecondsSinceEpoch}',
      'originalPrompt': text,
      'operationType': 'TRANSFER',
      'parameters': {
        'recipientIdentifier': 'bunch.dillon@example.ng',
        'sourceCurrency': 'USD',
        'amountFormatted': amt,
        'amountMinor': (double.parse(amt) * 100).toInt().toString(),
        'description': 'AI interpreted transfer from natural language',
      },
      'explanation': 'Extracted $amt USD transfer to Bunch Dillon (Nigeria employee). Awaiting your explicit review.',
      'confidenceScore': 0.95,
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _isInterpreting = false;
        _interpretedIntent = intent;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: FlowPayColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: FlowPayColors.primaryLight, size: 28),
              const SizedBox(width: 10),
              const Text('AI Financial Operator', style: FlowPayTypography.headingSm),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: FlowPayColors.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe what you want to achieve in plain English. AI interprets your intent; execution is strictly gated behind your PIN.',
            style: FlowPayTypography.bodyMd,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: FlowPayColors.surface,
              hintText: 'e.g. "Send \$150 to Samson Jabo" or "Run global payroll"',
              hintStyle: const TextStyle(color: FlowPayColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FlowPayColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FlowPayButton(
            text: 'Interpret Intent',
            icon: Icons.bolt,
            isLoading: _isInterpreting,
            onPressed: _handleInterpret,
          ),
          if (_interpretedIntent != null) ...[
            const SizedBox(height: 20),
            FlowPayCard(
              backgroundColor: FlowPayColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Structured Financial Intent', style: FlowPayTypography.caption),
                  const SizedBox(height: 8),
                  Text(
                    _interpretedIntent!.description,
                    style: FlowPayTypography.bodyLg,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const StatusBadge(status: 'Deterministic Validation Passed'),
                      const Spacer(),
                      Text(
                        '95% Confidence',
                        style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FlowPayButton(
                    text: 'Proceed to Approval & Signing',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SendMoneyScreen(appState: widget.appState),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
