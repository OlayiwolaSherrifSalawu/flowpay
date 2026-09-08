import 'package:flutter/material.dart';
import '../../../core/beneficiaries/beneficiary_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class ChooseBeneficiaryModal extends StatelessWidget {
  final List<Beneficiary> beneficiaries;
  final ValueChanged<Beneficiary> onSelect;

  const ChooseBeneficiaryModal({
    super.key,
    required this.beneficiaries,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Beneficiary> beneficiaries,
    required ValueChanged<Beneficiary> onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChooseBeneficiaryModal(
        beneficiaries: beneficiaries,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: FlowPayColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Existing Contact',
                    style: FlowPayTypography.title(
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select a verified recipient from your contacts',
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 20, color: FlowPayColors.darkTextSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact List
          if (beneficiaries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No beneficiaries found',
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.darkTextSecondary,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: beneficiaries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final b = beneficiaries[index];
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(b);
                    },
                    borderRadius: FlowPaySpacing.borderRadiusMd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FlowPayColors.darkBackground
                            : FlowPayColors.lightBackground,
                        borderRadius: FlowPaySpacing.borderRadiusMd,
                        border: Border.all(
                          color: isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: FlowPayColors.primary.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                b.countryFlag,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      b.legalName,
                                      style: TextStyle(
                                        color: isDark
                                            ? FlowPayColors.darkTextPrimary
                                            : FlowPayColors.lightTextPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (b.nickname.isNotEmpty &&
                                        b.nickname != b.legalName) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${b.nickname})',
                                        style: FlowPayTypography.captionStyle(
                                          color: FlowPayColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${b.accountOrAddress} • ${b.destinationCountry} (${b.currency.code})',
                                  style: FlowPayTypography.captionStyle(
                                    color: FlowPayColors.darkTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: FlowPayColors.darkTextSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
