import 'package:flutter/material.dart';
import '../../../core/beneficiaries/beneficiary_model.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/money/currency.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class AddBeneficiaryModal extends StatefulWidget {
  final String? initialNickname;
  final Future<void> Function(Beneficiary) onSave;

  const AddBeneficiaryModal({
    super.key,
    this.initialNickname,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialNickname,
    required Future<void> Function(Beneficiary) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddBeneficiaryModal(
        initialNickname: initialNickname,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddBeneficiaryModal> createState() => _AddBeneficiaryModalState();
}

class _AddBeneficiaryModalState extends State<AddBeneficiaryModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _legalNameController;
  late TextEditingController _accountController;
  late TextEditingController _relationshipController;

  String _selectedCountry = 'Nigeria';
  String _selectedFlag = '🇳🇬';
  Currency _selectedCurrency = Currency.ngn;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _countries = [
    {'name': 'Nigeria', 'flag': '🇳🇬', 'currency': Currency.ngn},
    {'name': 'Mexico', 'flag': '🇲🇽', 'currency': Currency.mxn},
    {'name': 'United States', 'flag': '🇺🇸', 'currency': Currency.usd},
    {'name': 'Canada', 'flag': '🇨🇦', 'currency': Currency.cad},
    {'name': 'United Kingdom', 'flag': '🇬🇧', 'currency': Currency.eur},
  ];

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname ?? '');
    _legalNameController = TextEditingController(
      text: widget.initialNickname != null && widget.initialNickname!.length > 1
          ? widget.initialNickname!
          : '',
    );
    _accountController = TextEditingController();
    _relationshipController = TextEditingController(text: 'Family');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _legalNameController.dispose();
    _accountController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final legalName = _legalNameController.text.trim();
      final nickname = _nicknameController.text.trim().isNotEmpty
          ? _nicknameController.text.trim()
          : legalName;
      final accountOrAddress = _accountController.text.trim().isNotEmpty
          ? _accountController.text.trim()
          : '0123456789 (Verified Bank)';

      final beneficiary = Beneficiary(
        id: 'ben_${DateTime.now().millisecondsSinceEpoch}',
        nickname: nickname,
        legalName: legalName,
        relationship: _relationshipController.text.trim().isNotEmpty
            ? _relationshipController.text.trim()
            : 'Beneficiary',
        destinationCountry: _selectedCountry,
        countryFlag: _selectedFlag,
        currency: _selectedCurrency,
        accountOrAddress: accountOrAddress,
        isVerified: true,
      );

      await widget.onSave(beneficiary);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Beneficiary',
                        style: FlowPayTypography.title(
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verified recipient for direct AI & smart transfers',
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
              const SizedBox(height: 20),

              // Legal Full Name
              Text(
                'FULL LEGAL NAME',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _legalNameController,
                style: TextStyle(
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Ade Fashola',
                  hintStyle: const TextStyle(color: FlowPayColors.darkTextSecondary),
                  filled: true,
                  fillColor: isDark
                      ? FlowPayColors.darkBackground
                      : FlowPayColors.lightBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: FlowPaySpacing.borderRadiusMd,
                    borderSide: BorderSide(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.lightBorder,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter their full legal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Nickname / Relationship Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NICKNAME / ALIAS',
                          style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.darkTextSecondary,
                          ).copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nicknameController,
                          style: TextStyle(
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Dad',
                            hintStyle: const TextStyle(
                                color: FlowPayColors.darkTextSecondary),
                            filled: true,
                            fillColor: isDark
                                ? FlowPayColors.darkBackground
                                : FlowPayColors.lightBackground,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: FlowPaySpacing.borderRadiusMd,
                              borderSide: BorderSide(
                                color: isDark
                                    ? FlowPayColors.darkBorder
                                    : FlowPayColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RELATIONSHIP',
                          style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.darkTextSecondary,
                          ).copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _relationshipController,
                          style: TextStyle(
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Family',
                            hintStyle: const TextStyle(
                                color: FlowPayColors.darkTextSecondary),
                            filled: true,
                            fillColor: isDark
                                ? FlowPayColors.darkBackground
                                : FlowPayColors.lightBackground,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: FlowPaySpacing.borderRadiusMd,
                              borderSide: BorderSide(
                                color: isDark
                                    ? FlowPayColors.darkBorder
                                    : FlowPayColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Country Selector
              Text(
                'DESTINATION COUNTRY',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? FlowPayColors.darkSurface
                        : FlowPayColors.lightSurface,
                    items: _countries.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['name'] as String,
                        child: Row(
                          children: [
                            Text(c['flag'] as String,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              '${c['name']} (${(c['currency'] as Currency).code})',
                              style: TextStyle(
                                color: isDark
                                    ? FlowPayColors.darkTextPrimary
                                    : FlowPayColors.lightTextPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final c = _countries.firstWhere((x) => x['name'] == val);
                      setState(() {
                        _selectedCountry = c['name'] as String;
                        _selectedFlag = c['flag'] as String;
                        _selectedCurrency = c['currency'] as Currency;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Account Number / Address
              Text(
                'ACCOUNT NUMBER OR WALLET ADDRESS',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountController,
                style: TextStyle(
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 0123456789 (GTBank) or 0x3A...F242',
                  hintStyle: const TextStyle(color: FlowPayColors.darkTextSecondary),
                  filled: true,
                  fillColor: isDark
                      ? FlowPayColors.darkBackground
                      : FlowPayColors.lightBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: FlowPaySpacing.borderRadiusMd,
                    borderSide: BorderSide(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.lightBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Save Beneficiary Button
              FlowPayButton(
                text: _isSaving ? 'Saving Beneficiary...' : 'Save & Continue',
                variant: FlowPayButtonVariant.primary,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
