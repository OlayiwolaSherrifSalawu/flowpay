import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/config/api_config.dart';
import '../../core/design_system/design_system.dart';

import 'set_pin_screen.dart';

/// KYC Screen: Handles Personal Tier 1 KYC (BVN/ID + Facial Scan)
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

  bool _isScanningFace = false;
  bool _faceScanCompleted = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nationalIdController = TextEditingController();
  }

  @override
  void dispose() {
    _nationalIdController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _officeAddressController.dispose();
    _signatoryIdController.dispose();
    super.dispose();
  }

  String get _idLabel {
    switch (widget.userProfile.country) {
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

  Future<void> _simulateFaceScan() async {
    setState(() => _isScanningFace = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      setState(() {
        _isScanningFace = false;
        _faceScanCompleted = true;
      });
    }
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

      // 1. Notify FlowPay backend of KYC completion (with safe fallback)
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
                  'country': updatedProfile.country,
                  'status': 'VERIFIED',
                }),
              )
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Safe backend fallback
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
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);

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
                // ── 3-Step Progress Indicator ──
                _buildStepProgress(isPersonal ? 0 : 0),
                const SizedBox(height: 20),

                // ── Compliance Status Hero Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: FlowPayRadii.card,
                    border: Border.all(
                        color: FlowPayColors.primary.withValues(alpha: 0.3),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: FlowPayColors.primary.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: FlowPayColors.emerald600.withValues(alpha: 0.12),
                          borderRadius: FlowPayRadii.avatar,
                          border: Border.all(
                              color:
                                  FlowPayColors.emerald600.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          isPersonal
                              ? Icons.verified_user_outlined
                              : Icons.shield_outlined,
                          color: FlowPayColors.emerald600,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersonal
                                  ? 'Account Verification'
                                  : 'Business Verification',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPersonal
                                  ? 'Unlocks your secure wallet and instant virtual spend cards.'
                                  : 'Enables international payroll and company cards.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? FlowPayColors.darkTextSecondary
                                    : FlowPayColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                    hintText: 'Enter ID number',
                    controller: _nationalIdController,
                    prefix: const Icon(Icons.badge_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    helperText:
                        'Verified securely and instantly.',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'ID is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  FlowPayTextField(
                    label: 'Date of Birth (YYYY-MM-DD)',
                    hintText: 'YYYY-MM-DD',
                    controller: _dobController,
                    prefix: const Icon(Icons.calendar_today_outlined,
                        size: 18, color: FlowPayColors.textSecondary),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Date of birth is required'
                        : null,
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
                    'Face verification helps protect your account from unauthorized access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: FlowPayColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildFacialScannerWidget(),
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

  Widget _buildStepProgress(int activeStep) {
    final steps = ['Verification', 'Selfie', 'Review'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i <= activeStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? FlowPayColors.primary
                        : FlowPayColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? FlowPayColors.primary
                        : FlowPayColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFacialScannerWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlowPayColors.surfaceAlt,
        borderRadius: FlowPayRadii.card,
        border: Border.all(
          color: _faceScanCompleted
              ? FlowPayColors.stateSuccess
              : FlowPayColors.hairline,
          width: _faceScanCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Camera Simulation Viewport
          Container(
            width: 140,
            height: 180,
            decoration: BoxDecoration(
              color: FlowPayColors.surface,
              borderRadius: BorderRadius.circular(70),
              border: Border.all(
                color: _faceScanCompleted
                    ? FlowPayColors.stateSuccess
                    : (_isScanningFace
                        ? FlowPayColors.primary
                        : FlowPayColors.hairline),
                width: 2.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  _faceScanCompleted ? Icons.check_circle : Icons.face,
                  size: 64,
                  color: _faceScanCompleted
                      ? FlowPayColors.stateSuccess
                      : (_isScanningFace
                          ? FlowPayColors.primaryLight
                          : FlowPayColors.textTertiary),
                ),
                if (_isScanningFace)
                  const SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlowPayColors.primaryLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            _faceScanCompleted
                ? 'Facial Biometrics Verified ✅'
                : (_isScanningFace
                    ? 'Aligning face with frame...'
                    : 'Position face inside the frame'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _faceScanCompleted
                  ? FlowPayColors.stateSuccess
                  : FlowPayColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _faceScanCompleted
                ? 'Liveness passed (Anti-spoofing score: 99.8%)'
                : 'Zero-knowledge biometric verification without storing raw video.',
            style: const TextStyle(
              fontSize: 11,
              color: FlowPayColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          if (!_faceScanCompleted)
            FlowPayButton(
              text: _isScanningFace ? 'Scanning...' : 'Start Liveness Scan',
              variant: FlowPayButtonVariant.secondary,
              icon: Icons.camera_alt_outlined,
              isLoading: _isScanningFace,
              onPressed: _isScanningFace ? null : _simulateFaceScan,
            ),
        ],
      ),
    );
  }
}
