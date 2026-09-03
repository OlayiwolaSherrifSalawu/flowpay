import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum AmountDisplaySize { large, medium, small, micro }

class FlowPayAmountDisplay extends StatelessWidget {
  final String amount;
  final String? currencySymbol;
  final String? currencyCode;
  final AmountDisplaySize size;
  final String? secondaryAmount;
  final Color? color;
  final bool isCredit;
  final bool isDebit;

  const FlowPayAmountDisplay({
    super.key,
    required this.amount,
    this.currencySymbol = '\$',
    this.currencyCode,
    this.size = AmountDisplaySize.medium,
    this.secondaryAmount,
    this.color,
    this.isCredit = false,
    this.isDebit = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color fg;
    if (color != null) {
      fg = color!;
    } else if (isCredit) {
      fg = FlowPayColors.accent;
    } else if (isDebit) {
      fg = isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary;
    } else {
      fg = isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary;
    }

    TextStyle mainStyle;
    double symbolSize;

    switch (size) {
      case AmountDisplaySize.large:
        mainStyle = FlowPayTypography.financialLarge;
        symbolSize = 22;
        break;
      case AmountDisplaySize.medium:
        mainStyle = FlowPayTypography.financialMedium;
        symbolSize = 16;
        break;
      case AmountDisplaySize.small:
        mainStyle = FlowPayTypography.financialSmall;
        symbolSize = 14;
        break;
      case AmountDisplaySize.micro:
        mainStyle = FlowPayTypography.financialMicro;
        symbolSize = 12;
        break;
    }

    final sign = isCredit ? '+' : (isDebit ? '-' : '');

    // Format amount into integer and decimal parts while preserving commas
    String cleanAmount = amount.replaceAll(RegExp(r'[^0-9.,]'), '');
    String intPart = cleanAmount;
    String decPart = '';
    if (cleanAmount.contains('.')) {
      final parts = cleanAmount.split('.');
      intPart = parts[0];
      decPart = '.${parts[1]}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (sign.isNotEmpty)
              Text(
                sign,
                style: mainStyle.copyWith(color: fg),
              ),
            if (currencySymbol != null)
              Text(
                currencySymbol!,
                style: TextStyle(
                  fontSize: symbolSize,
                  fontWeight: FontWeight.w600,
                  color: fg.withAlpha(200),
                ),
              ),
            Text(
              intPart.isEmpty ? '0' : intPart,
              style: mainStyle.copyWith(color: fg),
            ),
            if (decPart.isNotEmpty)
              Text(
                decPart,
                style: TextStyle(
                  fontSize: symbolSize,
                  fontWeight: FontWeight.w600,
                  color: fg.withAlpha(180),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (currencyCode != null) ...[
              const SizedBox(width: 4),
              Text(
                currencyCode!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary,
                ),
              ),
            ],
          ],
        ),
        if (secondaryAmount != null) ...[
          const SizedBox(height: 2),
          Text(
            secondaryAmount!,
            style: FlowPayTypography.caption.copyWith(
              color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
