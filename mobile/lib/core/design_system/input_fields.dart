import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class FlowPayTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefix;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const FlowPayTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: FlowPayTypography.caption.copyWith(
              color: isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FlowPaySpacing.xs),
        ],
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? FlowPayColors.darkTextMuted : FlowPayColors.lightTextMuted,
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 12,
              color: isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              color: FlowPayColors.error,
            ),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FlowPaySpacing.lg,
              vertical: FlowPaySpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: FlowPaySpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: FlowPaySpacing.borderRadiusMd,
              borderSide: BorderSide(
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: FlowPaySpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: FlowPayColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: FlowPaySpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: FlowPayColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: FlowPaySpacing.borderRadiusMd,
              borderSide: const BorderSide(
                color: FlowPayColors.error,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FlowPayAmountField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String currencySymbol;
  final String currencyCode;
  final VoidCallback? onCurrencyTap;
  final String? errorText;
  final bool autoFocus;

  const FlowPayAmountField({
    super.key,
    this.controller,
    this.onChanged,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
    this.onCurrencyTap,
    this.errorText,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated,
            borderRadius: FlowPaySpacing.borderRadiusLg,
            border: Border.all(
              color: errorText != null
                  ? FlowPayColors.error
                  : (isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
              width: errorText != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Currency Selector Pill
              InkWell(
                onTap: onCurrencyTap,
                borderRadius: FlowPaySpacing.borderRadiusSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? FlowPayColors.darkSurfaceSubtle : FlowPayColors.lightSurface,
                    borderRadius: FlowPaySpacing.borderRadiusSm,
                    border: Border.all(
                      color: isDark ? FlowPayColors.darkBorderLight : FlowPayColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencySymbol,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currencyCode,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (onCurrencyTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Large Numeric Amount Input
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  autofocus: autoFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: FlowPayTypography.financialLarge.copyWith(
                    color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: FlowPayTypography.financialLarge.copyWith(
                      color: isDark ? FlowPayColors.darkTextMuted : FlowPayColors.lightTextMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: FlowPayColors.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
