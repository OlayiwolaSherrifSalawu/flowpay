import 'package:flutter/material.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/state/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Add Employee Modal
/// Conforms to design.md §3.4, §3.5 & §4.1:
/// - 24dp top corner radius sheet
/// - 12dp input radius with hairline border
/// - Field labels always above the input
/// - Universal pill CTA button
class AddEmployeeModal extends StatefulWidget {
  final BusinessProvider businessProvider;

  const AddEmployeeModal({Key? key, required this.businessProvider}) : super(key: key);

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
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController(text: '3100000.00');

  String _selectedCountry = 'NG';
  Currency _selectedCurrency = Currency.ngn;
  bool _isSubmitting = false;

  void _onCountryChanged(String? country) {
    if (country == null) return;
    setState(() {
      _selectedCountry = country;
      if (country == 'NG') {
        _selectedCurrency = Currency.ngn;
        _salaryCtrl.text = '3100000.00';
      } else if (country == 'MX') {
        _selectedCurrency = Currency.mxn;
        _salaryCtrl.text = '35000.00';
      } else if (country == 'CA') {
        _selectedCurrency = Currency.cad;
        _salaryCtrl.text = '2750.00';
      }
    });
  }

  Future<void> _handleSubmit() async {
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final salaryStr = _salaryCtrl.text.trim();

    if (first.isEmpty || last.isEmpty || email.isEmpty || salaryStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final salaryMoney = Money.fromMajorString(salaryStr, _selectedCurrency);
      final usdSalary = Money.fromMajorString('2000.00', Currency.usd);

      final countryName = _selectedCountry == 'NG'
          ? 'Nigeria'
          : _selectedCountry == 'MX'
              ? 'Mexico'
              : 'Canada';

      await widget.businessProvider.addEmployee(
        firstName: first,
        lastName: last,
        email: email,
        country: _selectedCountry,
        countryName: countryName,
        targetCurrency: _selectedCurrency,
        payrollAmount: salaryMoney,
        usdPayrollAmount: usdSalary,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FlowPayColors.ink,
            content: Text(
              '$first $last onboarded successfully! Smart wallet provisioned.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add employee: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: FlowPayColors.surface,
        borderRadius: FlowPayRadii.sheet,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: FlowPayColors.surfaceAlt,
                    borderRadius: FlowPayRadii.avatar,
                  ),
                  child: const Icon(Icons.person_add_rounded, color: FlowPayColors.ink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Remote Team Member',
                        style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(fontSize: 17),
                      ),
                      Text(
                        'Auto-provisions BMONI smart wallet & card',
                        style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: FlowPayColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Country & Settlement Rail Selector
            Text(
              'DESTINATION COUNTRY & RAIL',
              style: FlowPayTypography.captionStyle(color: FlowPayColors.textTertiary).copyWith(
                fontSize: 10,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: FlowPayColors.surfaceAlt,
                borderRadius: FlowPayRadii.input,
                border: Border.all(color: FlowPayColors.hairline),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountry,
                  dropdownColor: FlowPayColors.surface,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: FlowPayColors.textSecondary),
                  items: const [
                    DropdownMenuItem(
                      value: 'NG',
                      child: Text('🇳🇬 Nigeria (NGN / CNGN)', style: TextStyle(color: FlowPayColors.ink, fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'MX',
                      child: Text('🇲🇽 Mexico (MXN / MEXe)', style: TextStyle(color: FlowPayColors.ink, fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'CA',
                      child: Text('🇨🇦 Canada (CAD / CADC)', style: TextStyle(color: FlowPayColors.ink, fontSize: 14)),
                    ),
                  ],
                  onChanged: _onCountryChanged,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name Fields Row
            Row(
              children: [
                Expanded(
                  child: _InputField(
                    label: 'First Name',
                    controller: _firstCtrl,
                    hint: 'e.g. Adebayo / Carlos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputField(
                    label: 'Last Name',
                    controller: _lastCtrl,
                    hint: 'e.g. Johnson / Silva',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Work Email Field
            _InputField(
              label: 'Work Email',
              controller: _emailCtrl,
              hint: 'employee@company.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Monthly Payroll Amount
            _InputField(
              label: 'Monthly Salary (${_selectedCurrency.code})',
              controller: _salaryCtrl,
              hint: '0.00',
              prefixText: '${_selectedCurrency.symbol} ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FlowPayButton(
                text: 'Add Employee & Provision Wallet',
                icon: Icons.check_circle_rounded,
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  final TextInputType keyboardType;

  const _InputField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hint,
    this.prefixText,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FlowPayTypography.label(color: FlowPayColors.textSecondary).copyWith(fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: FlowPayColors.ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: FlowPayColors.textTertiary, fontSize: 13),
            prefixText: prefixText,
            prefixStyle: const TextStyle(color: FlowPayColors.ink, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: FlowPayColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: const BorderSide(color: FlowPayColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: FlowPayRadii.input,
              borderSide: const BorderSide(color: FlowPayColors.ink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
