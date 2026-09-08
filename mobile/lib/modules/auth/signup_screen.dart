import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/config/api_config.dart';
import '../../core/design_system/buttons.dart';
import '../../core/design_system/input_fields.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radii.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import 'kyc_screen.dart';
import 'login_screen.dart';

/// Signup Screen: Allows selecting Personal vs Business account type,
/// collecting identity details, setting up security PIN, and proceeding to KYC.
class SignupScreen extends ConsumerStatefulWidget {
  final String? employeeInviteToken;

  const SignupScreen({
    super.key,
    this.employeeInviteToken,
  });

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  AccountType _accountType = AccountType.personal;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Business specific controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyRegController = TextEditingController();
  final TextEditingController _companyRoleController = TextEditingController();

  String _selectedCountry = 'NG';
  bool _isLoadingInvite = false;
  String? _inviteErrorMessage;
  Map<String, dynamic>? _inviteDetails;
  String? _employeeId;

  final List<Map<String, String>> _countries = const [
    {
      'code': 'NG',
      'name': 'Nigeria',
      'currency': 'NGN',
      'idLabel': 'BVN / NIN'
    },
    {
      'code': 'MX',
      'name': 'Mexico',
      'currency': 'MXN',
      'idLabel': 'CURP / RFC'
    },
    {'code': 'US', 'name': 'United States', 'currency': 'USD', 'idLabel': 'SSN'},
    {'code': 'CA', 'name': 'Canada', 'currency': 'CAD', 'idLabel': 'SIN'},
    {
      'code': 'GB',
      'name': 'United Kingdom',
      'currency': 'GBP',
      'idLabel': 'National Insurance'
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.employeeInviteToken != null &&
        widget.employeeInviteToken!.trim().isNotEmpty) {
      _loadInviteDetails(widget.employeeInviteToken!.trim());
    }
  }

  Future<void> _loadInviteDetails(String token) async {
    setState(() {
      _isLoadingInvite = true;
      _inviteErrorMessage = null;
    });

    try {
      if (SecureStorageService.isTestEnv) {
        setState(() {
          _isLoadingInvite = false;
          _fullNameController.text = 'Amara Okonkwo';
          _emailController.text = 'amara.okonkwo@flowpay.ng';
          _selectedCountry = 'NG';
          _accountType = AccountType.personal;
          _employeeId = 'emp_test_amara';
          _inviteDetails = {
            'firstName': 'Amara',
            'lastName': 'Okonkwo',
            'email': 'amara.okonkwo@flowpay.ng',
            'country': 'NG',
          };
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/employees/invite/$token'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final details = data['data'] as Map<String, dynamic>;
        setState(() {
          _inviteDetails = details;
          _employeeId = details['employeeId'];
          final first = details['firstName'] ?? '';
          final last = details['lastName'] ?? '';
          _fullNameController.text = '$first $last'.trim();
          _emailController.text = details['email'] ?? '';
          if (details['country'] != null) {
            _selectedCountry = (details['country'] as String).toUpperCase();
          }
          _accountType = AccountType.personal;
          _isLoadingInvite = false;
        });
      } else {
        final code = data['code'] ?? '';
        final msg = data['message'] ?? 'Unable to resolve invitation';
        setState(() {
          _isLoadingInvite = false;
          if (code == 'ALREADY_USED') {
            _inviteErrorMessage =
                'This invitation has already been used and employee wallet is linked.';
          } else if (code == 'EXPIRED') {
            _inviteErrorMessage =
                'This invitation link has expired. Please contact your employer for a new link.';
          } else {
            _inviteErrorMessage = msg;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingInvite = false;
        _inviteErrorMessage = 'Failed to load invitation details: $e';
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _companyRegController.dispose();
    _companyRoleController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId =
        'usr_${_accountType.name}_${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile(
      userId: userId,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      accountType: _accountType,
      country: _selectedCountry,
      phone: _phoneController.text.trim(),
      companyName: _accountType == AccountType.business
          ? _companyNameController.text.trim()
          : null,
      companyRole: _accountType == AccountType.business
          ? _companyRoleController.text.trim()
          : null,
      companyRegNumber: _accountType == AccountType.business
          ? _companyRegController.text.trim()
          : null,
      createdAt: DateTime.now(),
    );

    if (!SecureStorageService.isTestEnv) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fullName': profile.fullName,
            'email': profile.email,
            'accountType': profile.accountType.name,
            'country': profile.country,
            'phone': profile.phone,
            'companyName': profile.companyName,
            'companyRole': profile.companyRole,
            if (widget.employeeInviteToken != null)
              'inviteToken': widget.employeeInviteToken,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycScreen(
          userProfile: profile,
          employeeInviteToken: widget.employeeInviteToken,
          employeeId: _employeeId,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Brand Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: FlowPayColors.ink,
                          borderRadius: FlowPayRadii.card,
                        ),
                        child: const Icon(
                          Icons.bolt,
                          size: 32,
                          color: FlowPayColors.amber,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'FLOWPAY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: FlowPayColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your money. Your rules. AI executes.',
                        style: FlowPayTypography.caption.copyWith(
                          color: FlowPayColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Employee Invite Status Banner
                if (_isLoadingInvite)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: FlowPayColors.surfaceAlt,
                      borderRadius: FlowPayRadii.card,
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: FlowPayColors.primary),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Verifying invitation token...',
                          style: TextStyle(
                              fontSize: 13, color: FlowPayColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else if (_inviteErrorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowPayColors.errorSubtle,
                      borderRadius: FlowPayRadii.card,
                      border: Border.all(color: FlowPayColors.error),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: FlowPayColors.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Invalid or Expired Invitation',
                                style: TextStyle(
                                    color: FlowPayColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _inviteErrorMessage!,
                                style: const TextStyle(
                                    color: FlowPayColors.error, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_inviteDetails != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowPayColors.surfaceAlt,
                      borderRadius: FlowPayRadii.card,
                      border:
                          Border.all(color: FlowPayColors.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: FlowPayColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.card_membership_rounded,
                              color: FlowPayColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Remote Employee Invitation',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: FlowPayColors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pre-filled from employer invite. After PIN setup, your hardware wallet will link to corporate payroll.',
                                style: FlowPayTypography.captionStyle(
                                    color: FlowPayColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Title & Subtitle
                Text(
                  'Create an Account',
                  style: FlowPayTypography.title().copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select your account type to configure your BMONI infrastructure.',
                  style: TextStyle(
                    fontSize: 14,
                    color: FlowPayColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Account Type Selector
                Row(
                  children: [
                    Expanded(
                      child: _buildAccountTypeCard(
                        type: AccountType.personal,
                        icon: Icons.person_outline,
                        title: 'Personal',
                        tagline: 'Freelancer & Worker',
                        description:
                            'Multi-currency wallets, virtual cards & money missions',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAccountTypeCard(
                        type: AccountType.business,
                        icon: Icons.business_center_outlined,
                        title: 'Business',
                        tagline: 'Employer & Payroll',
                        description:
                            'One Employer, Many Countries, One Bill fan-out',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form Fields Section
                Text(
                  _accountType == AccountType.personal
                      ? 'Personal Information'
                      : 'Business Administrator Information',
                  style: FlowPayTypography.headingSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FlowPayColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Full Name
                FlowPayTextField(
                  label: 'Full Legal Name',
                  hintText: _accountType == AccountType.personal
                      ? 'e.g. Bunch Dillon'
                      : 'e.g. Waffiyyi Fashola',
                  controller: _fullNameController,
                  prefix: const Icon(Icons.person,
                      size: 18, color: FlowPayColors.textSecondary),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your legal name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Email
                FlowPayTextField(
                  label: _accountType == AccountType.personal
                      ? 'Personal Email'
                      : 'Work Email',
                  hintText: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  prefix: const Icon(Icons.email_outlined,
                      size: 18, color: FlowPayColors.textSecondary),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Invalid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Country & Currency Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primary Operating Country',
                      style: FlowPayTypography.caption.copyWith(
                        color: FlowPayColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: FlowPaySpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlowPayColors.surfaceAlt,
                        borderRadius: FlowPayRadii.input,
                        border: Border.all(color: FlowPayColors.hairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountry,
                          isExpanded: true,
                          dropdownColor: FlowPayColors.surface,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: FlowPayColors.ink,
                          ),
                          items: _countries.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['code'],
                              child: Row(
                                children: [
                                  Text(c['name']!,
                                      style: const TextStyle(fontSize: 14)),
                                  const Spacer(),
                                  Text(
                                    '(${c['currency']})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FlowPayColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCountry = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Phone Number
                FlowPayTextField(
                  label: 'Phone Number',
                  hintText: '+234 800 000 0000',
                  keyboardType: TextInputType.phone,
                  controller: _phoneController,
                  prefix: const Icon(Icons.phone_outlined,
                      size: 18, color: FlowPayColors.textSecondary),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your phone number'
                      : null,
                ),
                const SizedBox(height: 14),

                // Business Specific Fields
                if (_accountType == AccountType.business) ...[
                  const Divider(color: FlowPayColors.hairline, height: 28),
                  Text(
                    'Company & Entity Details',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FlowPayColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FlowPayTextField(
                    label: 'Registered Company Name',
                    hintText: 'e.g. Acme Global Technologies Ltd',
                    controller: _companyNameController,
                    prefix: const Icon(Icons.domain,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter company name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  FlowPayTextField(
                    label: 'Registration / Tax Number',
                    hintText: 'e.g. RC-8924190 or EIN / RFC',
                    controller: _companyRegController,
                    prefix: const Icon(Icons.numbers,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter registration number'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  FlowPayTextField(
                    label: 'Your Company Role',
                    hintText: 'e.g. Founder & CEO, Head of Finance',
                    controller: _companyRoleController,
                    prefix: const Icon(Icons.badge_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your corporate role'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 24),

                // Submit Action
                FlowPayButton(
                  text: 'Proceed to Identity Verification',
                  icon: Icons.arrow_forward,
                  onPressed: _submit,
                ),

                const SizedBox(height: 16),

                // Already have account
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Already have an account? Log In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FlowPayColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard({
    required AccountType type,
    required IconData icon,
    required String title,
    required String tagline,
    required String description,
  }) {
    final isSelected = _accountType == type;

    return GestureDetector(
      onTap: () => setState(() => _accountType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? FlowPayColors.surfaceAlt : FlowPayColors.surface,
          borderRadius: FlowPayRadii.card,
          border: Border.all(
            color: isSelected ? FlowPayColors.primary : FlowPayColors.hairline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FlowPayColors.primary
                        : FlowPayColors.surfaceSubtle,
                    borderRadius: FlowPayRadii.chip,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color:
                        isSelected ? Colors.white : FlowPayColors.textSecondary,
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected
                      ? FlowPayColors.primary
                      : FlowPayColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FlowPayColors.ink,
              ),
            ),
            Text(
              tagline,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FlowPayColors.amber,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 11,
                color: FlowPayColors.textSecondary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
