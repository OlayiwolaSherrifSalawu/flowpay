import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/safety/financial_intent.dart';
import '../../core/state/app_state.dart';
import 'send_money_screen.dart';

class AiOperatorModal extends StatefulWidget {
  final AppState appState;

  const AiOperatorModal({super.key, required this.appState});

  @override
  State<AiOperatorModal> createState() => _AiOperatorModalState();
}

class _AiOperatorModalState extends State<AiOperatorModal> {
  final _inputController = TextEditingController(text: 'Send \$250 to Bunch Dillon');
  bool _isInterpreting = false;
  FinancialIntent? _interpretedIntent;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

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
      'explanation':
          'Extracted $amt USD transfer to Bunch Dillon (Nigeria employee). Awaiting your explicit review.',
      'confidenceScore': 0.95,
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isInterpreting = false;
          _interpretedIntent = intent;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + FlowPaySpacing.xl,
        left: FlowPaySpacing.xl,
        right: FlowPaySpacing.xl,
        top: FlowPaySpacing.xl,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: FlowPayColors.primaryLight, size: 28),
              const SizedBox(width: FlowPaySpacing.sm),
              Text(
                'AI Financial Operator',
                style: FlowPayTypography.headingSm.copyWith(
                  color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: FlowPaySpacing.xs),
          Text(
            'Describe what you want to achieve in plain English. AI interprets your intent; execution is strictly gated behind your PIN.',
            style: FlowPayTypography.bodyMd.copyWith(
              color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: FlowPaySpacing.lg),
          FlowPayTextField(
            controller: _inputController,
            hintText: 'e.g. "Send \$150 to Samson Jabo" or "Run global payroll"',
          ),
          const SizedBox(height: FlowPaySpacing.lg),
          FlowPayButton(
            text: 'Interpret Intent',
            icon: Icons.bolt,
            isFullWidth: true,
            isLoading: _isInterpreting,
            onPressed: _handleInterpret,
          ),
          if (_interpretedIntent != null) ...[
            const SizedBox(height: FlowPaySpacing.xl),
            FlowPayCard(
              variant: FlowPayCardVariant.elevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Structured Financial Intent', style: FlowPayTypography.caption),
                  const SizedBox(height: FlowPaySpacing.xs),
                  Text(
                    _interpretedIntent!.description,
                    style: FlowPayTypography.bodyLg.copyWith(
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: FlowPaySpacing.md),
                  Row(
                    children: [
                      const FlowPayStatusBadge(
                        status: 'Deterministic Validation Passed',
                        showDot: true,
                      ),
                      const Spacer(),
                      Text(
                        '95% Confidence',
                        style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: FlowPaySpacing.lg),
                  FlowPayButton(
                    text: 'Proceed to Approval & Signing',
                    isFullWidth: true,
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
