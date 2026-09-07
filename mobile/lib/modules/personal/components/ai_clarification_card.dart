import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/design_system/buttons.dart';

class ClarificationQuestion {
  final String id;
  final String question; // e.g. "Who is Mom?"
  final String description; // e.g. "Select a verified contact or register a new recipient"
  final List<ClarificationOption> options;
  final String? selectedOptionId;

  const ClarificationQuestion({
    required this.id,
    required this.question,
    this.description = '',
    required this.options,
    this.selectedOptionId,
  });

  ClarificationQuestion copyWith({
    String? selectedOptionId,
  }) {
    return ClarificationQuestion(
      id: id,
      question: question,
      description: description,
      options: options,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    );
  }
}

class ClarificationOption {
  final String id;
  final String label; // e.g. "Mary Fashola (NGN)"
  final String? subtitle; // e.g. "0123456789 • Nigeria 🇳🇬"
  final IconData? icon;
  final VoidCallback? onCustomAction;

  const ClarificationOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
    this.onCustomAction,
  });
}

/// FlowPay Smart Clarification UI
/// A reusable, premium component displayed when the AI detects ambiguous or missing parameters.
/// Allows answering naturally or selecting through structured 1-tap controls.
class AiClarificationCard extends StatelessWidget {
  final String title;
  final List<ClarificationQuestion> questions;
  final ValueChanged<ClarificationQuestion>? onOptionSelected;
  final VoidCallback? onProceed;
  final VoidCallback? onCancel;

  const AiClarificationCard({
    super.key,
    this.title = 'I need a few details to continue',
    required this.questions,
    this.onOptionSelected,
    this.onProceed,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: FlowPayColors.accent.withAlpha(90),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: FlowPayColors.accent.withAlpha(18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: AI Operator Sparkle + Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FlowPayColors.accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: FlowPayColors.accentLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FlowPayTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Clarify below or continue typing naturally',
                      style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                  color: FlowPayColors.darkTextSecondary,
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Questions List
          ...questions.map((q) => _buildQuestionBlock(context, q, isDark)),

          if (onProceed != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FlowPayButton(
                text: 'Confirm & Continue',
                icon: Icons.check,
                size: FlowPayButtonSize.small,
                onPressed: onProceed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(
      BuildContext context, ClarificationQuestion q, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurfaceElevated,
        borderRadius: FlowPaySpacing.borderRadiusLg,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 16, color: FlowPayColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.question,
                  style: FlowPayTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (q.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              q.description,
              style: FlowPayTypography.captionStyle(
                color: FlowPayColors.darkTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Structured selectable options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: q.options.map((opt) {
              final isSelected = q.selectedOptionId == opt.id;
              return InkWell(
                onTap: () {
                  if (opt.onCustomAction != null) {
                    opt.onCustomAction!();
                  }
                  if (onOptionSelected != null) {
                    onOptionSelected!(q.copyWith(selectedOptionId: opt.id));
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FlowPayColors.primary.withAlpha(45)
                        : (isDark
                            ? FlowPayColors.darkSurfaceSubtle
                            : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? FlowPayColors.primary
                          : (isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.lightBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (opt.icon != null) ...[
                        Icon(opt.icon,
                            size: 14,
                            color: isSelected
                                ? FlowPayColors.primary
                                : FlowPayColors.darkTextSecondary),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? FlowPayColors.primary
                              : (isDark
                                  ? FlowPayColors.darkTextPrimary
                                  : FlowPayColors.lightTextPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
