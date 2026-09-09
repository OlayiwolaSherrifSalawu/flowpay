import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class FlowPayTextField extends StatelessWidget {
  final String? label;
  final String? labelText;
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
  final bool disabled;
  final VoidCallback? onTap;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const FlowPayTextField({
    super.key,
    this.label,
    this.labelText,
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
    this.disabled = false,
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
        if ((label ?? labelText) != null) ...[
          Text(
            label ?? labelText!,
            style: FlowPayTypography.caption.copyWith(
              color: isDark
                  ? FlowPayColors.darkTextSecondary
                  : FlowPayColors.lightTextSecondary,
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
          readOnly: readOnly || disabled,
          enabled: !disabled,
          onTap: onTap,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark
                ? FlowPayColors.darkTextPrimary
                : FlowPayColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark
                  ? FlowPayColors.darkTextMuted
                  : FlowPayColors.lightTextMuted,
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 12,
              color: isDark
                  ? FlowPayColors.darkTextTertiary
                  : FlowPayColors.lightTextTertiary,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              color: FlowPayColors.error,
            ),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurfaceElevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FlowPaySpacing.lg,
              vertical: FlowPaySpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: isDark
                    ? FlowPayColors.darkBorder
                    : FlowPayColors.lightBorder,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: isDark
                    ? FlowPayColors.darkBorder
                    : FlowPayColors.lightBorder,
                width: 1,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: FlowPayColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: FlowPayColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
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
            color: isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurfaceElevated,
            borderRadius: FlowPayRadii.input,
            border: Border.all(
              color: errorText != null
                  ? FlowPayColors.error
                  : (isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.lightBorder),
              width: errorText != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Currency Selector Pill
              InkWell(
                onTap: onCurrencyTap,
                borderRadius: FlowPayRadii.chip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceSubtle
                        : FlowPayColors.lightSurface,
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                      color: isDark
                          ? FlowPayColors.darkBorderLight
                          : FlowPayColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencySymbol,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currencyCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: FlowPayTypography.financialLarge.copyWith(
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: FlowPayTypography.financialLarge.copyWith(
                      color: isDark
                          ? FlowPayColors.darkTextMuted
                          : FlowPayColors.lightTextMuted,
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

/// Size variant for FlowPay / BMoni form fields
enum BMoniTextFieldSize { small, medium, large }

/// Backwards compatibility wrapper for form fields styled with FlowPay tokens
class BMoniTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final BMoniTextFieldSize size;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  const BMoniTextFormField({
    super.key,
    this.controller,
    this.label,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.size = BMoniTextFieldSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  const BMoniTextFormField.filled({
    super.key,
    this.controller,
    this.label,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.size = BMoniTextFieldSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel = label ?? labelText;

    double verticalPadding;
    switch (size) {
      case BMoniTextFieldSize.small:
        verticalPadding = 10;
        break;
      case BMoniTextFieldSize.large:
        verticalPadding = 18;
        break;
      case BMoniTextFieldSize.medium:
        verticalPadding = 14;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (displayLabel != null) ...[
          Text(
            displayLabel,
            style: FlowPayTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? FlowPayColors.darkTextSecondary
                  : FlowPayColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onTap: onTap,
          autofocus: autofocus,
          focusNode: focusNode,
          style: FlowPayTypography.bodyMd.copyWith(
            color: isDark
                ? FlowPayColors.darkTextPrimary
                : FlowPayColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefixText: prefixText,
            suffixText: suffixText,
            filled: true,
            fillColor: isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: verticalPadding,
            ),
            hintStyle: FlowPayTypography.bodyMd.copyWith(
              color: isDark
                  ? FlowPayColors.darkTextMuted
                  : FlowPayColors.lightTextMuted,
            ),
            border: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: isDark
                    ? FlowPayColors.darkBorder
                    : FlowPayColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: isDark
                    ? FlowPayColors.darkBorder
                    : FlowPayColors.lightBorder,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: FlowPayColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: BorderSide(
                color: FlowPayColors.error,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

