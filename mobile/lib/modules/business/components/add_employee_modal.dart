import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/state/business_provider.dart';
import '../../auth/signup_screen.dart';

class CountryOption {
  final String code;
  final String name;
  final String flag;
  final Currency currency;
  final String defaultSalary;

  const CountryOption({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.defaultSalary,
  });
}

/// Add Employee Modal
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - 28dp sheet radius (FlowPayRadii.sheet)
/// - Theme-adaptive canvas (lightSurface / darkSurface) with pull handle
/// - BMoniTextFormField.filled for inputs with 16dp pillowed radius
/// - SelectorBottomSheet<CountryOption> for country & rail selection
/// - Universal pill buttons for invitation dispatch
/// - BMoniToastOverlay for rich feedback
class AddEmployeeModal extends StatefulWidget {
  final BusinessProvider businessProvider;

  const AddEmployeeModal({super.key, required this.businessProvider});

  static Future<void> show(BuildContext context, BusinessProvider provider) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEmployeeModal(businessProvider: provider),
    );
  }

  @override
  State<AddEmployeeModal> createState() => _AddEmployeeModalState();
}

class _AddEmployeeModalState extends State<AddEmployeeModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController(text: '3100000.00');

  String? _createdInviteUrl;
  String? _createdInviteToken;
  String? _createdEmployeeName;
  String? _createdEmployeeEmail;

  static const List<CountryOption> _countries = [
    CountryOption(
      code: 'NG',
      name: 'Nigeria (NGN / CNGN)',
      flag: '🇳🇬',
      currency: Currency.ngn,
      defaultSalary: '3100000.00',
    ),
    CountryOption(
      code: 'MX',
      name: 'Mexico (MXN / MEXe)',
      flag: '🇲🇽',
      currency: Currency.mxn,
      defaultSalary: '35000.00',
    ),
  ];

  CountryOption _selectedCountry = _countries.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    try {
      final picked = await BMoniBottomSheet.show<CountryOption>(
        context: context,
        child: SelectorBottomSheet<CountryOption>(
          items: _countries,
          selected: _selectedCountry,
          title: 'Select Country',
          label: (c) => '${c.flag} ${c.name}',
          value: (c) => c.code,
          showIcon: false,
        ),
      );

      if (picked != null && mounted) {
        setState(() {
          _selectedCountry = picked;
          _salaryCtrl.text = picked.defaultSalary;
        });
      }
    } catch (_) {
      _showSimpleCountryPicker();
    }
  }

  void _showSimpleCountryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.sheet),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Country',
                style: FlowPayTypography.title(
                  color: isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.ink,
                ),
              ),
            ),
            ..._countries.map((c) => ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: isDark
                          ? FlowPayColors.darkTextPrimary
                          : FlowPayColors.ink,
                    ),
                  ),
                  trailing: c.code == _selectedCountry.code
                      ? const Icon(Icons.check_circle_rounded,
                          color: FlowPayColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedCountry = c;
                      _salaryCtrl.text = c.defaultSalary;
                    });
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.trim();
    final salaryStr = _salaryCtrl.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final salaryMoney =
          Money.fromMajorString(salaryStr, _selectedCountry.currency);
      final usdSalary = Money.fromMajorString('2000.00', Currency.usd);

      final inviteUrl = await widget.businessProvider.addEmployee(
        firstName: first,
        lastName: last,
        email: email,
        phoneNumber: phone.isNotEmpty ? phone : null,
        country: _selectedCountry.code,
        countryName: _selectedCountry.code == 'NG' ? 'Nigeria' : 'Mexico',
        targetCurrency: _selectedCountry.currency,
        payrollAmount: salaryMoney,
        usdPayrollAmount: usdSalary,
      );

      final token = inviteUrl.split('/').last.replaceAll('flowpay_', '');

      if (mounted) {
        setState(() {
          _createdInviteUrl = inviteUrl;
          _createdInviteToken = token;
          _createdEmployeeName = '$first $last';
          _createdEmployeeEmail = email;
        });

        try {
          BMoniToastOverlay.showSuccess(
            context: context,
            title: 'Invitation Dispatched',
            message: 'Single-use invite link created for $first $last.',
          );
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        try {
          BMoniToastOverlay.showError(
            context: context,
            title: 'Onboarding Failed',
            message: 'Failed to create employee: $e',
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add employee: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildInvitationSentView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: FlowPayRadii.chip,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FlowPayColors.signal.withValues(alpha: 0.12),
                borderRadius: FlowPayRadii.avatar,
                border: Border.all(
                  color: FlowPayColors.signal.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(Icons.mark_email_read_rounded,
                  color: FlowPayColors.signal, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invitation Sent!',
                    style: FlowPayTypography.title(color: inkColor)
                        .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Employee self-onboards on their phone to hold their own key.',
                    style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: textSecondaryColor),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Employee Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceAltColor,
            borderRadius: FlowPayRadii.cardSmall,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _createdEmployeeName ?? '',
                    style: FlowPayTypography.body(color: inkColor)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const StatusBadge(status: 'INVITED'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _createdEmployeeEmail ?? '',
                    style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor),
                  ),
                  Text(
                    '${_selectedCountry.flag} ${_selectedCountry.currency.code}',
                    style: FlowPayTypography.captionStyle(color: inkColor)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Copy Link Box
        Text(
          'SINGLE-USE INVITATION LINK (72H TTL)',
          style: FlowPayTypography.captionStyle(color: textTertiaryColor)
              .copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceAltColor,
            borderRadius: FlowPayRadii.input,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded,
                  color: textSecondaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _createdInviteUrl ?? '',
                  style: FlowPayTypography.captionStyle(color: inkColor)
                      .copyWith(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  if (_createdInviteUrl != null) {
                    Clipboard.setData(ClipboardData(text: _createdInviteUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: inkColor,
                        content: Text(
                          'Invite link copied to clipboard!',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }
                },
                borderRadius: FlowPayRadii.chip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlowPayColors.primary.withValues(alpha: 0.12),
                    borderRadius: FlowPayRadii.chip,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy_rounded,
                          size: 14, color: FlowPayColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: FlowPayTypography.captionStyle(
                                color: FlowPayColors.primary)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Test Onboarding as Employee button
        BMoniButton(
          text: 'Test Onboarding as Employee',
          variant: BMoniButtonVariant.primary,
          size: BMoniButtonSize.large,
          icon: Icons.smartphone_rounded,
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  employeeInviteToken: _createdInviteToken,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        BMoniButton(
          text: 'Close',
          variant: BMoniButtonVariant.secondary,
          size: BMoniButtonSize.medium,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
          borderRadius: FlowPayRadii.sheet,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: bottomInset + 24,
        ),
        child: _createdInviteUrl != null
            ? _buildInvitationSentView(context)
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pull Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: FlowPayRadii.chip,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: FlowPayColors.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: FlowPayRadii.avatar,
                              border: Border.all(
                                color: FlowPayColors.primary
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.person_add_rounded,
                                  color: FlowPayColors.primary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invite Remote Employee',
                                  style: FlowPayTypography.title(
                                          color: inkColor)
                                      .copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Invite → Employee Self-Onboards → Ready',
                                  style: FlowPayTypography.captionStyle(
                                    color: textSecondaryColor,
                                  ).copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: textSecondaryColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Country & Currency Selector using SelectorBottomSheet
                      Text(
                        'DESTINATION COUNTRY',
                        style: FlowPayTypography.captionStyle(
                          color: textTertiaryColor,
                        ).copyWith(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickCountry,
                        borderRadius: FlowPayRadii.input,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: surfaceAltColor,
                            borderRadius: FlowPayRadii.input,
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Text(_selectedCountry.flag,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCountry.name,
                                      style: FlowPayTypography.body(
                                              color: inkColor)
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Disbursement currency: ${_selectedCountry.currency.code}',
                                      style: FlowPayTypography.captionStyle(
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: textSecondaryColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Row with BMoniTextFormField.filled
                      Row(
                        children: [
                          Expanded(
                            child: BMoniTextFormField.filled(
                              label: 'First Name',
                              hintText: 'e.g. Bunch / Samson',
                              controller: _firstCtrl,
                              size: BMoniTextFieldSize.medium,
                              prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BMoniTextFormField.filled(
                              label: 'Last Name',
                              hintText: 'e.g. Dillon / Jabo',
                              controller: _lastCtrl,
                              size: BMoniTextFieldSize.medium,
                              prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Work Email Field with BMoniTextFormField.filled
                      BMoniTextFormField.filled(
                        label: 'Work Email Address',
                        hintText: 'employee@company.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        size: BMoniTextFieldSize.medium,
                        prefixIcon:
                            const Icon(Icons.mail_outline_rounded, size: 18),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex =
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Number (Optional E.164)
                      BMoniTextFormField.filled(
                        label: 'Phone Number (E.164 format)',
                        hintText: _selectedCountry.code == 'NG'
                            ? '+2348011112222'
                            : '+525512345678',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        size: BMoniTextFieldSize.medium,
                        prefixIcon:
                            const Icon(Icons.phone_outlined, size: 18),
                      ),
                      const SizedBox(height: 16),

                      // Monthly Salary Field
                      BMoniTextFormField.filled(
                        label:
                            'Monthly Net Salary (${_selectedCountry.currency.code})',
                        hintText: '0.00',
                        controller: _salaryCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        size: BMoniTextFieldSize.medium,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          child: Text(
                            _selectedCountry.currency.symbol,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Salary is required';
                          }
                          final numVal = double.tryParse(v.trim());
                          if (numVal == null || numVal <= 0) {
                            return 'Must be a positive amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Primary Submission Button using BMoniButton
                      SizedBox(
                        width: double.infinity,
                        child: BMoniButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          text: 'Send Employee Invitation',
                          variant: BMoniButtonVariant.primary,
                          size: BMoniButtonSize.large,
                          isLoading: _isSubmitting,
                          icon: Icons.send_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
