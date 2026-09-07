import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/design_system/buttons.dart';

/// FlowPay AI Financial Command Center
/// "What should your money do?"
///
/// Directives:
/// 1. This is NOT a chatbot. It turns plain English intentions into structured financial actions.
/// 2. Primary command center interface with quick action suggestions:
///    - "Send $500 to Mom"
///    - "Keep $300 aside for tax"
///    - "Split my next payment between savings and expenses"
///    - "How much can I safely spend this month?"
///    - "Pay my designer $500"
class AiCommandBar extends StatefulWidget {
  final ValueChanged<String> onCommandSubmit;
  final VoidCallback onAllocateTap;
  final VoidCallback onSendMoneyTap;
  final VoidCallback onConvertTap;

  const AiCommandBar({
    super.key,
    required this.onCommandSubmit,
    required this.onAllocateTap,
    required this.onSendMoneyTap,
    required this.onConvertTap,
  });

  @override
  State<AiCommandBar> createState() => _AiCommandBarState();
}

class _AiCommandBarState extends State<AiCommandBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onCommandSubmit(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: _isFocused
              ? FlowPayColors.primary.withAlpha(150)
              : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? FlowPayColors.primary.withAlpha(20)
                : const Color(0x0C000000),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: AI Operator Glow + Headline
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FlowPayColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: FlowPayColors.primary.withAlpha(60),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: FlowPayColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What should your money do?',
                      style: FlowPayTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tell FlowPay what you want in plain English.',
                      style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Command Input Box
          Focus(
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurfaceElevated,
                borderRadius: FlowPaySpacing.borderRadiusLg,
                border: Border.all(
                  color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded,
                      size: 18, color: FlowPayColors.darkTextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Send \$500 to Mom"',
                        hintStyle: TextStyle(
                          color: FlowPayColors.darkTextMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FlowPayButton(
                    text: 'Execute',
                    icon: Icons.arrow_forward_rounded,
                    size: FlowPayButtonSize.small,
                    onPressed: _handleSubmit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Suggestion Chips
          const Text(
            'SUGGESTED ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: FlowPayColors.darkTextMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SuggestionChip(
                  icon: Icons.pie_chart_outline,
                  label: 'Allocate my \$2,000',
                  accentColor: FlowPayColors.primary,
                  onTap: widget.onAllocateTap,
                ),
                const SizedBox(width: 8),
                _SuggestionChip(
                  icon: Icons.send_outlined,
                  label: 'Send \$500 to my designer',
                  accentColor: FlowPayColors.accent,
                  onTap: widget.onSendMoneyTap,
                ),
                const SizedBox(width: 8),
                _SuggestionChip(
                  icon: Icons.currency_exchange,
                  label: 'Convert \$1,000 to Naira',
                  accentColor: FlowPayColors.primaryLight,
                  onTap: widget.onConvertTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? FlowPayColors.darkBorder
                  : FlowPayColors.lightBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: FlowPayTypography.captionStyle(
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
