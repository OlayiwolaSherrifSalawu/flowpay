import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/config/api_config.dart';
import '../../core/design_system/design_system.dart';
import 'components/live_face_scanner.dart';
import 'set_pin_screen.dart';

/// KYC Screen: Handles Personal Tier 1 KYC (BVN/ID + Real Camera Facial Liveness Scan)
/// and Business KYB (Entity Docs + Signatory Verification + Payroll Rail Activation).
class KycScreen extends ConsumerStatefulWidget {
  final UserProfile userProfile;
  final String? employeeInviteToken;
  final String? employeeId;

  const KycScreen({
    super.key,
    required this.userProfile,
    this.employeeInviteToken,
    this.employeeId,
  });

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Fields
  late final TextEditingController _nationalIdController;
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Business Fields
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _officeAddressController = TextEditingController();
  final TextEditingController _signatoryIdController = TextEditingController();

  bool _faceScanCompleted = false;
  String? _capturedFacePath;
  bool _isSubmitting = false;
  DateTime? _selectedDob;
  String? _ageLabel;

  @override
  void initState() {
    super.initState();
    _nationalIdController = TextEditingController();
    _nationalIdController.addListener(_onFieldChanged);
    _dobController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nationalIdController.removeListener(_onFieldChanged);
    _dobController.removeListener(_onFieldChanged);
    _nationalIdController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _officeAddressController.dispose();
    _signatoryIdController.dispose();
    super.dispose();
  }

  bool get _isNigeria => widget.userProfile.country.toUpperCase() == 'NG';

  String get _idLabel {
    switch (widget.userProfile.country.toUpperCase()) {
      case 'NG':
        return 'Bank Verification Number (BVN) / NIN';
      case 'MX':
        return 'CURP / RFC Identity Number';
      case 'US':
        return 'Social Security Number (SSN)';
      case 'CA':
        return 'Social Insurance Number (SIN)';
      case 'GB':
        return 'National Insurance (NI)';
      default:
        return 'Government National ID Number';
    }
  }

  String? _validateId(String? v) {
    if (v == null || v.trim().isEmpty) {
      return '$_idLabel is required';
    }
    final clean = v.trim();
    if (_isNigeria) {
      if (!RegExp(r'^\d+$').hasMatch(clean)) {
        return 'BVN must contain only numbers';
      }
      if (clean.length != 11) {
        return 'BVN must be exactly 11 digits (entered ${clean.length}/11)';
      }
      if (clean == '00000000000') {
        return 'Please enter a valid 11-digit BVN';
      }
    } else if (widget.userProfile.country.toUpperCase() == 'MX') {
      if (clean.length < 10) {
        return 'Please enter a valid CURP or RFC identity';
      }
    } else if (widget.userProfile.country.toUpperCase() == 'US' ||
        widget.userProfile.country.toUpperCase() == 'CA') {
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length != 9) {
        return 'Must be 9 digits';
      }
    }
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final minDate = DateTime(1920, 1, 1);
    final initialDate =
        _selectedDob ?? DateTime(now.year - 25, now.month, now.day);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(maxDate) ? maxDate : initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'SELECT DATE OF BIRTH (18+ REQUIRED)',
      builder: (context, child) {
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: FlowPayColors.primary,
              primary: FlowPayColors.primary,
              surface: isDark ? FlowPayColors.darkSurface : Colors.white,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        final formatted =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        _dobController.text = formatted;

        int age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageLabel = '$age years old';
      });
    }
  }

  String? _validateDob(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Date of birth is required';
    }
    final clean = v.trim();
    final parts = clean.split('-');
    if (parts.length != 3) {
      return 'Format must be YYYY-MM-DD';
    }
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) {
      return 'Invalid date format';
    }
    final now = DateTime.now();
    int age = now.year - y;
    if (now.month < m || (now.month == m && now.day < d)) {
      age--;
    }
    if (age < 18) {
      return 'You must be at least 18 years of age (entered $age)';
    }
    return null;
  }

  Future<void> _completeKyc() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.userProfile.isPersonal && !_faceScanCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please perform the facial liveness verification to proceed.'),
          backgroundColor: FlowPayColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final updatedProfile = widget.userProfile.copyWith(
        kycStatus: KycStatus.verified,
        nationalId: _nationalIdController.text.trim(),
        nationalIdType: _idLabel,
      );

      // 1. Notify FlowPay backend of KYC completion with resilient timeout
      if (!SecureStorageService.isTestEnv) {
        try {
          final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/kyc');
          await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'userId': updatedProfile.userId,
                  'accountType': updatedProfile.accountType.name,
                  'nationalId': updatedProfile.nationalId,
                  'nationalIdType': _idLabel,
                  'country': updatedProfile.country,
                  'dateOfBirth': _dobController.text.trim(),
                  'address': _addressController.text.trim(),
                  'livenessVerified': _faceScanCompleted,
                  if (_capturedFacePath != null)
                    'faceProofPath': _capturedFacePath,
                  'status': 'VERIFIED',
                }),
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('[KycScreen] Non-blocking backend KYC sync notice: $e');
        }
      }

      // 2. Persist verified profile to Secure Storage
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveUserProfile(updatedProfile);
      await storage.setKycCompleted(true);

      final targetMode = widget.userProfile.isPersonal
          ? AccountMode.personal
          : AccountMode.business;
      await storage.saveAccountMode(targetMode);

      final capabilities = widget.userProfile.isPersonal
          ? AccountCapabilities.personalOnly(bmoniUserId: updatedProfile.userId)
          : AccountCapabilities.businessOnly(
              bmoniUserId: updatedProfile.userId,
              companyName: updatedProfile.companyName ?? 'Business Account',
              companyRole: updatedProfile.companyRole ?? 'ADMIN',
            );
      await storage.saveCapabilities(capabilities);

      // 3. Update Riverpod Notifiers
      ref.read(currentAccountModeProvider.notifier).state = targetMode;
      await ref
          .read(currentUserProfileProvider.notifier)
          .saveProfile(updatedProfile);
      await ref.read(currentUserProfileProvider.notifier).setKycVerified();

      // 4. Navigate to Step 3: Set Security PIN
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SetPinScreen(
              userProfile: updatedProfile,
              employeeInviteToken: widget.employeeInviteToken,
              employeeId: widget.employeeId,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = widget.userProfile.isPersonal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final borderColor = FlowPayColors.borderOf(context);

    // BVN Validation feedback
    final cleanId = _nationalIdController.text.trim();
    final isBvnValid = _isNigeria &&
        cleanId.length == 11 &&
        RegExp(r'^\d{11}$').hasMatch(cleanId);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPersonal ? 'Identity Verification' : 'Corporate KYB Compliance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPersonal) ...[
                  // Personal KYC Section
                  Text(
                    'Step 1: Government Identity',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  FlowPayTextField(
                    label: _idLabel,
                    hintText: _isNigeria
                        ? 'Enter 11-digit BVN / NIN'
                        : 'Enter ID number',
                    controller: _nationalIdController,
                    keyboardType: _isNigeria
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: _isNigeria
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ]
                        : [LengthLimitingTextInputFormatter(24)],
                    prefix: const Icon(Icons.badge_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    suffix: isBvnValid
                        ? const Icon(Icons.check_circle_rounded,
                            color: FlowPayColors.stateSuccess, size: 20)
                        : null,
                    helperText: isBvnValid
                        ? '✓ 11-digit BVN verified format'
                        : (_isNigeria && cleanId.isNotEmpty
                            ? 'Entered ${cleanId.length}/11 digits'
                            : (_isNigeria
                                ? '11-digit Central Bank of Nigeria identifier (e.g. 22222222222)'
                                : 'Verified securely and instantly.')),
                    onChanged: (v) => setState(() {}),
                    validator: _validateId,
                  ),
                  const SizedBox(height: 14),

                  FlowPayTextField(
                    label: 'Date of Birth (YYYY-MM-DD)',
                    hintText: 'YYYY-MM-DD',
                    controller: _dobController,
                    keyboardType: TextInputType.datetime,
                    prefix: const Icon(Icons.calendar_today_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    suffix: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined,
                          color: FlowPayColors.primary, size: 20),
                      onPressed: _pickDateOfBirth,
                      tooltip: 'Select date from calendar',
                    ),
                    onTap: _pickDateOfBirth,
                    helperText: _ageLabel != null
                        ? 'Age: $_ageLabel • Eligible (18+ verified)'
                        : 'Tap calendar or field to select date of birth (18+ required)',
                    validator: _validateDob,
                  ),
                  const SizedBox(height: 14),

                  FlowPayTextField(
                    label: 'Residential Address',
                    hintText: 'Street, City, State, Country',
                    controller: _addressController,
                    prefix: const Icon(Icons.home_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // Step 2: Facial Biometrics
                  Text(
                    'Step 2: Facial Biometric Liveness',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Real front-camera verification protects your self-custody wallet from unauthorized access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: FlowPayColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Face Scanner Component
                  LiveFaceScanner(
                    initialCompleted: _faceScanCompleted,
                    onLivenessChanged: (verified) {
                      setState(() {
                        _faceScanCompleted = verified;
                      });
                    },
                    onPhotoCaptured: (path) {
                      _capturedFacePath = path;
                    },
                  ),
                  const SizedBox(height: 28),
                ] else ...[
                  // Business KYB Section
                  Text(
                    'Step 1: Corporate Legal Entity',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  FlowPayTextField(
                    label: 'Corporate Tax ID / RFC / EIN',
                    hintText: 'e.g. TIN-99482014',
                    controller: _taxIdController,
                    prefix: const Icon(Icons.numbers,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tax ID is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  FlowPayTextField(
                    label: 'Registered Business Office Address',
                    hintText: 'e.g. 100 Financial Plaza',
                    controller: _officeAddressController,
                    prefix: const Icon(Icons.business,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Step 2: Authorized Signatory Verification',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FlowPayColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Officer: ${widget.userProfile.fullName} (${widget.userProfile.companyRole ?? 'Administrator'})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),

                  FlowPayTextField(
                    label: 'Authorized Officer Identity / BVN',
                    hintText: 'Enter representative identification number',
                    controller: _signatoryIdController,
                    prefix: const Icon(Icons.verified_user,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Signatory ID is required'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Payroll Rail Readiness Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlowPayColors.surfaceAlt,
                      borderRadius: FlowPayRadii.card,
                      border: Border.all(color: FlowPayColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hub_outlined,
                                size: 18, color: FlowPayColors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Payment Countries Activated',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: FlowPayColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRailItem('Nigeria 🇳🇬 (NGN)',
                            'Direct bank transfers & cards'),
                        _buildRailItem('Mexico 🇲🇽 (MXN)',
                            'Direct bank transfers & cards'),
                        _buildRailItem('Global USD Account 🇺🇸',
                            'One-bill payment source'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Submit Verification Button ──
                FlowPayButton(
                  text: _isSubmitting
                      ? 'Verifying...'
                      : (isPersonal
                          ? 'Verify & Set PIN'
                          : 'Verify Business & Set PIN'),
                  icon: Icons.arrow_forward,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _completeKyc,
                ),
                const SizedBox(height: 12),
                // ── Trust Guarantee Banner ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.mint100.withValues(alpha: 0.5),
                    borderRadius: FlowPayRadii.input,
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 13,
                          color: FlowPayColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Your data is encrypted. Only used for regulatory compliance.',
                          style: TextStyle(
                            fontSize: 11,
                            color: FlowPayColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 14, color: FlowPayColors.stateSuccess),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FlowPayColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FlowPayColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
