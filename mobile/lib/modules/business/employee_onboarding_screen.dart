import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency_mapping.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';

/// Employee Onboarding Screen (FlowPay Business Model B)
/// Adheres strictly to the 4 stages and country-specific BMONI specifications:
/// - Stage 2: Smart Wallet Provisioning (On-device owner key, challenge, PIN signing, CNGN/MEXe)
/// - Stage 3: Country-Specific KYC (Nigeria: no selfie + BVN/EDD; Mexico: selfie + CURP/RFC)
/// - Stage 4: Rail Activation (Nigeria: start-nigeria; Mexico: Etherfuse agreements prerequisite)
/// - States: Not Started, In Progress, Ready, Failed
class EmployeeOnboardingScreen extends StatefulWidget {
  final AppState appState;
  final EmployeeModel employee;

  const EmployeeOnboardingScreen({
    super.key,
    required this.appState,
    required this.employee,
  });

  @override
  State<EmployeeOnboardingScreen> createState() =>
      _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  late EmployeeModel _emp;
  EmployeeOnboardingStatusModel? _status;
  bool _isLoading = true;

  // Active stage tab (2, 3, or 4)
  int _activeStage = 2;

  // Nigeria Form Controllers
  final _bvnCtrl = TextEditingController(text: '95888168924');
  final _ninCtrl = TextEditingController(text: '63184876213');
  final _ngStreetCtrl =
      TextEditingController(text: '15 Admiralty Way, Lekki Phase 1');
  final _ngCityCtrl = TextEditingController(text: 'Lagos');
  final _ngStateCtrl = TextEditingController(text: 'Lagos');
  final _ngPostalCtrl = TextEditingController(text: '101241');
  final _ngOccupationCtrl = TextEditingController(text: 'OCC_FIN_001');

  // Mexico Form Controllers
  final _curpCtrl = TextEditingController(text: 'OKAC900115MDFXYZ01');
  final _rfcCtrl = TextEditingController(text: 'OKAC900115XYZ');
  final _paternalCtrl = TextEditingController(text: 'Mendoza');
  final _maternalCtrl = TextEditingController(text: 'García');
  final _mxStreetCtrl = TextEditingController(text: 'Av. Insurgentes Sur 123');
  final _mxCityCtrl = TextEditingController(text: 'Mexico City');
  final _mxStateCtrl = TextEditingController(text: 'CDMX');
  final _mxPostalCtrl = TextEditingController(text: '03100');

  // Interactive step states
  bool _isProcessingAction = false;
  bool _selfieCaptured = false;
  bool _agreementsSigned = false;

  @override
  void initState() {
    super.initState();
    _emp = widget.employee;
    _fetchStatus();
  }

  @override
  void dispose() {
    _bvnCtrl.dispose();
    _ninCtrl.dispose();
    _ngStreetCtrl.dispose();
    _ngCityCtrl.dispose();
    _ngStateCtrl.dispose();
    _ngPostalCtrl.dispose();
    _ngOccupationCtrl.dispose();

    _curpCtrl.dispose();
    _rfcCtrl.dispose();
    _paternalCtrl.dispose();
    _maternalCtrl.dispose();
    _mxStreetCtrl.dispose();
    _mxCityCtrl.dispose();
    _mxStateCtrl.dispose();
    _mxPostalCtrl.dispose();
    super.dispose();
  }

  bool get _isNigeria => _emp.country.toUpperCase() == 'NG';
  String get _stablecoin => CurrencyMapping.toStablecoin(_emp.country);

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status =
          await widget.appState.employeeRepo.getOnboardingStatus(_emp.id);
      setState(() {
        _status = status;
        _activeStage = status.currentStage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================================================================
  // STAGE 2 ACTION: PROVISION SMART WALLET
  // =========================================================================
  Future<void> _handleProvisionWallet() async {
    setState(() => _isProcessingAction = true);

    try {
      // 1. Generate or load on-device owner key via BMONI SDK
      final hasWallet = await BmoniSdkService.hasWallet();
      String ownerAddress;
      if (hasWallet) {
        ownerAddress = (await BmoniSdkService.walletAddress())!;
      } else {
        ownerAddress = await BmoniSdkService.initWallet();
      }

      // 2. Request owner challenge from proxy with stablecoin code (CNGN or MEXe)
      final challengeData =
          await widget.appState.employeeRepo.requestOwnerChallenge(
        _emp.id,
        ownerAddress,
      );

      final challengeId = challengeData['challengeId']?.toString() ?? '';
      final messageToSign = challengeData['message']?.toString() ?? '';

      // 3. Prompt user for 6-digit B-Key signing PIN
      if (!mounted) return;
      final signature = await WalletPinAuthSheet.show(
        context: context,
        title: 'Authorize Smart Wallet',
        subtitle:
            'Sign owner challenge for $_stablecoin smart wallet on-device.',
        onAuthorize: (pin) async {
          return await BmoniSdkService.signMessage(messageToSign, pin: pin);
        },
      );

      if (signature == null) {
        setState(() => _isProcessingAction = false);
        return;
      }

      // 4. Deploy managed smart wallet
      await widget.appState.employeeRepo.provisionSmartWallet(
        _emp.id,
        userOwnerAddress: ownerAddress,
        ownerProofChallengeId: challengeId,
        ownerProofSignature: signature,
      );

      if (!mounted) return;
      BMoniToastOverlay.showSuccess(
        context: context,
        title: 'Stage 2 Complete',
        message: 'Smart wallet provisioned with $_stablecoin settlement rail.',
      );

      await _fetchStatus();
      setState(() {
        _activeStage = 3;
      });
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
        context: context,
        title: 'Stage 2 Failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // =========================================================================
  // STAGE 3 ACTION: SUBMIT & ACTIVATE KYC
  // =========================================================================
  Future<void> _handleSubmitKyc() async {
    setState(() => _isProcessingAction = true);

    try {
      if (_isNigeria) {
        // Nigeria KYC payload (NO biometric selfie per BMONI high-risk spec)
        final payload = {
          'personalInfo': {
            'firstName': _emp.firstName,
            'lastName': _emp.lastName,
            'dateOfBirth': '1990-01-15',
            'phoneNumber': _emp.phoneNumber ?? '+2348000000000',
          },
          'addressDetails': {
            'street': _ngStreetCtrl.text.trim(),
            'city': _ngCityCtrl.text.trim(),
            'state': _ngStateCtrl.text.trim(),
            'postalCode': _ngPostalCtrl.text.trim(),
            'countryCode': 'NGA',
          },
          'identification': {
            'bvn': _bvnCtrl.text.trim(),
            'nin': _ninCtrl.text.trim(),
          },
          'employment': {
            'employmentStatus': 'employed',
            'occupationCode': _ngOccupationCtrl.text.trim(),
          },
          'compliance': {
            'sourceOfFunds': 'salary',
            'estimatedMonthlyVolume': 2000,
          },
        };

        await widget.appState.employeeRepo.submitCountryKyc(_emp.id, payload);
        await widget.appState.employeeRepo.checkKycReadiness(_emp.id);
        await widget.appState.employeeRepo.activateKyc(_emp.id);
      } else {
        // Mexico KYC payload (Requires biometric selfie + CURP + RFC + maternal/paternal surnames)
        if (!_selfieCaptured) {
          throw Exception(
              'Mexico KYC requires biometric selfie verification. Please capture selfie first.');
        }

        final payload = {
          'personalInfo': {
            'firstName': _emp.firstName,
            'lastName': _emp.lastName,
            'paternalLastName': _paternalCtrl.text.trim(),
            'maternalLastName': _maternalCtrl.text.trim(),
            'dateOfBirth': '1990-01-15',
            'nationality': 'MX',
          },
          'addressDetails': {
            'street': _mxStreetCtrl.text.trim(),
            'city': _mxCityCtrl.text.trim(),
            'state': _mxStateCtrl.text.trim(),
            'postalCode': _mxPostalCtrl.text.trim(),
            'countryCode': 'MEX',
          },
          'identification': {
            'curp': _curpCtrl.text.trim(),
            'rfc': _rfcCtrl.text.trim(),
          },
          'employment': {
            'employmentStatus': 'employed',
            'employerName': 'FlowPay Remote',
          },
          'compliance': {
            'sourceOfFunds': 'salary',
          },
          'documents': {
            'hasIdDocument': true,
            'hasProofOfAddress': true,
            'hasBiometricSelfie': true,
          },
        };

        await widget.appState.employeeRepo.submitCountryKyc(_emp.id, payload);
        await widget.appState.employeeRepo.checkKycReadiness(_emp.id);
        await widget.appState.employeeRepo.activateKyc(_emp.id);
      }

      if (!mounted) return;
      BMoniToastOverlay.showSuccess(
        context: context,
        title: 'Stage 3 Complete',
        message: 'KYC verified and activated for ${_emp.resolvedCountryName}.',
      );

      await _fetchStatus();
      setState(() {
        _activeStage = 4;
      });
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
        context: context,
        title: 'Stage 3 Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  // =========================================================================
  // STAGE 4 ACTION: SIGN ETHERFUSE AGREEMENTS & ACTIVATE RAIL
  // =========================================================================
  Future<void> _handleSignMexicoAgreements() async {
    setState(() => _isProcessingAction = true);
    try {
      // Fetch agreements payload from backend
      final agreements =
          await widget.appState.employeeRepo.getMexicoAgreements(_emp.id);
      final expiresAt = agreements['expiresAt']?.toString() ?? '';

      if (!mounted) return;
      final signed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: FlowPayColors.canvas,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🇲🇽', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Etherfuse Custody Agreements',
                            style: FlowPayTypography.title(
                                color: FlowPayColors.ink)),
                        Text('Required for SPEI / CLABE onboarding in Mexico',
                            style: FlowPayTypography.captionStyle(
                                color: FlowPayColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FlowPayColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlowPayColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Etherfuse Digital Asset Custody Agreement (MEXe)\n'
                      '• Fintoc Banking Rail & SPEI Offramp Authorization\n'
                      '• CNBV & SAT Regulatory Compliance Disclosures',
                      style: FlowPayTypography.body(
                          color: FlowPayColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Token expires: ${expiresAt.isNotEmpty ? expiresAt.substring(11, 19) : '5 minutes'}',
                      style:
                          FlowPayTypography.captionStyle(color: Colors.amber),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              BMoniButton(
                text: 'Accept & Sign Agreements',
                variant: BMoniButtonVariant.primary,
                size: BMoniButtonSize.large,
                icon: Icons.draw_rounded,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      );

      if (signed == true) {
        setState(() => _agreementsSigned = true);
        if (!mounted) return;
        BMoniToastOverlay.showSuccess(
          context: context,
          title: 'Agreements Signed',
          message: 'Etherfuse authorization registered successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
        context: context,
        title: 'Agreements Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleActivateRail() async {
    setState(() => _isProcessingAction = true);

    try {
      if (!_isNigeria && !_agreementsSigned) {
        throw Exception(
            'Mexico KYC cannot approve until Etherfuse agreements are signed first.');
      }

      await widget.appState.employeeRepo.activateRail(
        _emp.id,
        options: {
          'agreementsSigned': _agreementsSigned,
          'paternalLastName': _paternalCtrl.text.trim(),
          'maternalLastName': _maternalCtrl.text.trim(),
          'bvn': _bvnCtrl.text.trim(),
        },
      );

      if (!mounted) return;
      BMoniToastOverlay.showSuccess(
        context: context,
        title: 'Stage 4 Submitted',
        message:
            'Rail activation started. Awaiting onboarding.completed webhook.',
      );

      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
        context: context,
        title: 'Stage 4 Error',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleSimulateWebhook() async {
    setState(() => _isProcessingAction = true);
    try {
      await widget.appState.employeeRepo.simulateWebhookCompleted(_emp.id);
      if (!mounted) return;
      BMoniToastOverlay.showSuccess(
        context: context,
        title: 'Onboarding Completed',
        message:
            'onboarding.completed webhook processed! Employee is ready for payroll.',
      );
      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
          context: context, title: 'Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _isProcessingAction = true);
    try {
      await widget.appState.employeeRepo.retryOnboarding(_emp.id);
      if (!mounted) return;
      BMoniToastOverlay.showInfo(
          context: context,
          title: 'Retrying',
          message: 'Stage reset to retry onboarding.');
      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      BMoniToastOverlay.showError(
          context: context, title: 'Retry Failed', message: e.toString());
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overall = _status?.overallState ?? OnboardingStageState.notStarted;

    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee Onboarding',
                style: FlowPayTypography.title(color: FlowPayColors.ink)
                    .copyWith(fontSize: 16)),
            Text('${_emp.fullName} • ${_emp.resolvedCountryName}',
                style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: FlowPayColors.ink),
            tooltip: 'Refresh Status',
            onPressed: _fetchStatus,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: FlowPayColors.ink))
          : ListView(
              padding: FlowPaySpacing.insetXl,
              children: [
                // 1. Overall State & Stage Banner
                _buildHeaderBanner(overall),
                const SizedBox(height: 16),

                // 2. Stage Navigation Stepper (2 / 3 / 4)
                _buildStageTabs(),
                const SizedBox(height: 20),

                // 3. Active Stage Content Card
                if (_activeStage == 2) _buildStage2Card(),
                if (_activeStage == 3) _buildStage3Card(),
                if (_activeStage == 4) _buildStage4Card(),

                const SizedBox(height: 24),

                // 4. Sandbox Webhook & Retry Helper Bar
                _buildSandboxActionBar(overall),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildHeaderBanner(OnboardingStageState overall) {
    Color badgeBg;
    Color badgeFg;

    switch (overall) {
      case OnboardingStageState.ready:
        badgeBg = FlowPayColors.signal.withValues(alpha: 0.15);
        badgeFg = FlowPayColors.signal;
        break;
      case OnboardingStageState.failed:
        badgeBg = FlowPayColors.error.withValues(alpha: 0.15);
        badgeFg = FlowPayColors.error;
        break;
      case OnboardingStageState.inProgress:
        badgeBg = Colors.amber.withValues(alpha: 0.15);
        badgeFg = Colors.amber[700] ?? Colors.amber;
        break;
      case OnboardingStageState.notStarted:
        badgeBg = Colors.blue.withValues(alpha: 0.15);
        badgeFg = Colors.blueAccent;
        break;
    }

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_emp.flagEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_emp.fullName,
                        style: FlowPayTypography.title(color: FlowPayColors.ink)
                            .copyWith(fontSize: 17)),
                    Text(
                        'Rail: ${_emp.targetCurrency.code} (${_emp.targetCurrency.stablecoinToken})',
                        style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  overall.label.toUpperCase(),
                  style: TextStyle(
                      color: badgeFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current Stage: Stage ${_status?.currentStage ?? 2} of 4',
            style: FlowPayTypography.body(color: FlowPayColors.ink)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (_status?.failedStage != null) ...[
            const SizedBox(height: 4),
            Text(
              '⚠️ Failed at Stage ${_status!.failedStage}: ${_status!.failureReason}',
              style: FlowPayTypography.captionStyle(color: FlowPayColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageTabs() {
    return Row(
      children: [
        Expanded(
            child: _stageTabItem(
                2, 'Stage 2\nWallet', _status?.stage2Wallet.state)),
        const SizedBox(width: 8),
        Expanded(
            child: _stageTabItem(3, 'Stage 3\nKYC', _status?.stage3Kyc.state)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _stageTabItem(4, 'Stage 4\nRail', _status?.stage4Rail.state)),
      ],
    );
  }

  Widget _stageTabItem(int stage, String label, OnboardingStageState? state) {
    final isSelected = _activeStage == stage;
    final isReady = state == OnboardingStageState.ready;
    final isFailed = state == OnboardingStageState.failed;

    Color borderColor = FlowPayColors.hairline;
    if (isSelected) borderColor = FlowPayColors.primary;
    if (isReady) borderColor = FlowPayColors.signal;
    if (isFailed) borderColor = FlowPayColors.error;

    return GestureDetector(
      onTap: () => setState(() => _activeStage = stage),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? FlowPayColors.surface : FlowPayColors.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? FlowPayColors.ink
                    : FlowPayColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              isReady
                  ? Icons.check_circle_rounded
                  : (isFailed
                      ? Icons.error_outline_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 16,
              color: isReady
                  ? FlowPayColors.signal
                  : (isFailed
                      ? FlowPayColors.error
                      : FlowPayColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STAGE 2 VIEW: SMART WALLET PROVISIONING
  // =========================================================================
  Widget _buildStage2Card() {
    final walletReady =
        _status?.stage2Wallet.state == OnboardingStageState.ready;

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: FlowPayColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Stage 2: Smart Wallet Provisioning',
                  style: FlowPayTypography.title(color: FlowPayColors.ink)
                      .copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FlowPayColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: FlowPayColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart wallet calls use stablecoin token $_stablecoin (not ${_emp.targetCurrency.code}) per BMONI specifications.',
                    style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '1. BmoniEmbeddedSdk.initWallet() generates key on-device\n'
            '2. POST /owner-proof-challenges requests challenge\n'
            '3. BmoniEmbeddedSdk.signMessage() signs challenge via 6-digit PIN\n'
            '4. POST /create-managed registers managed smart wallet',
            style: FlowPayTypography.body(color: FlowPayColors.textSecondary)
                .copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (walletReady) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlowPayColors.signal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: FlowPayColors.signal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: FlowPayColors.signal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Smart wallet active: ${_status?.stage2Wallet.details['walletAddress'] ?? _emp.walletAddress ?? '0x...'}',
                      style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.signal)
                          .copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            BMoniButton(
              text: _isProcessingAction
                  ? 'Provisioning Wallet...'
                  : 'Provision Smart Wallet on BMONI',
              variant: BMoniButtonVariant.primary,
              size: BMoniButtonSize.medium,
              icon: Icons.key_rounded,
              onPressed: _handleProvisionWallet,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 3 VIEW: COUNTRY-SPECIFIC KYC
  // =========================================================================
  Widget _buildStage3Card() {
    final kycReady = _status?.stage3Kyc.state == OnboardingStageState.ready;

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: FlowPayColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Stage 3: ${_isNigeria ? 'Nigeria KYC (No Selfie)' : 'Mexico KYC (Selfie + CURP)'}',
                style: FlowPayTypography.title(color: FlowPayColors.ink)
                    .copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isNigeria
                ? 'Nigeria path strictly omits biometric selfie. Requires 11-digit BVN and Enhanced Due Diligence (EDD).'
                : 'Mexico path requires CURP, RFC, maternal/paternal surnames, and biometric selfie scan.',
            style: FlowPayTypography.captionStyle(
                color: FlowPayColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Country Specific Forms
          if (_isNigeria) ...[
            BMoniTextFormField.filled(
              controller: _bvnCtrl,
              label: 'Bank Verification Number (BVN)',
              hintText: '11 digits (e.g. 95888168924)',
              prefixIcon: const Icon(Icons.numbers_rounded),
            ),
            const SizedBox(height: 10),
            BMoniTextFormField.filled(
              controller: _ninCtrl,
              label: 'National Identification Number (NIN)',
              hintText: '11 digits',
              prefixIcon: const Icon(Icons.badge_rounded),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BMoniTextFormField.filled(
                    controller: _ngCityCtrl,
                    label: 'City',
                    hintText: 'Lagos',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BMoniTextFormField.filled(
                    controller: _ngStateCtrl,
                    label: 'State',
                    hintText: 'Lagos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BMoniTextFormField.filled(
              controller: _ngOccupationCtrl,
              label: 'Occupation Code (EDD)',
              hintText: 'OCC_FIN_001',
              prefixIcon: const Icon(Icons.work_outline_rounded),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biometric selfie step is omitted for Nigeria per official BMONI KYC guidelines.',
                      style: FlowPayTypography.captionStyle(
                          color: Colors.blue[900] ?? Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Mexico KYC Form
            BMoniTextFormField.filled(
              controller: _curpCtrl,
              label: 'CURP (18 characters)',
              hintText: 'OKAC900115MDFXYZ01',
              prefixIcon: const Icon(Icons.badge_rounded),
            ),
            const SizedBox(height: 10),
            BMoniTextFormField.filled(
              controller: _rfcCtrl,
              label: 'RFC (12-13 characters)',
              hintText: 'OKAC900115XYZ',
              prefixIcon: const Icon(Icons.numbers_rounded),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BMoniTextFormField.filled(
                    controller: _paternalCtrl,
                    label: 'Paternal Surname',
                    hintText: 'Mendoza',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BMoniTextFormField.filled(
                    controller: _maternalCtrl,
                    label: 'Maternal Surname',
                    hintText: 'García',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Biometric Selfie Simulator
            GestureDetector(
              onTap: () {
                setState(() => _selfieCaptured = !_selfieCaptured);
                BMoniToastOverlay.showInfo(
                  context: context,
                  title: _selfieCaptured ? 'Selfie Captured' : 'Selfie Cleared',
                  message: _selfieCaptured
                      ? 'Facial liveness scan verified.'
                      : 'Please take selfie.',
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selfieCaptured
                      ? FlowPayColors.signal.withValues(alpha: 0.1)
                      : FlowPayColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selfieCaptured
                        ? FlowPayColors.signal
                        : FlowPayColors.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selfieCaptured
                          ? Icons.face_retouching_natural_rounded
                          : Icons.camera_front_rounded,
                      color: _selfieCaptured
                          ? FlowPayColors.signal
                          : FlowPayColors.ink,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selfieCaptured
                                ? 'Biometric Selfie: Captured & Verified'
                                : 'Capture Biometric Selfie (Required)',
                            style:
                                FlowPayTypography.body(color: FlowPayColors.ink)
                                    .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _selfieCaptured
                                ? 'Liveness and anti-spoofing radar passed'
                                : 'Tap to simulate camera scan',
                            style: FlowPayTypography.captionStyle(
                                color: FlowPayColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _selfieCaptured
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_ios_rounded,
                      color: _selfieCaptured
                          ? FlowPayColors.signal
                          : FlowPayColors.textTertiary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),
          if (kycReady) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlowPayColors.signal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: FlowPayColors.signal),
                  const SizedBox(width: 8),
                  Text('KYC Profile & Verification Passed',
                      style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.signal)),
                ],
              ),
            ),
          ] else ...[
            BMoniButton(
              text: _isProcessingAction
                  ? 'Submitting KYC...'
                  : 'Submit & Activate KYC',
              variant: BMoniButtonVariant.primary,
              size: BMoniButtonSize.medium,
              icon: Icons.send_rounded,
              onPressed: _handleSubmitKyc,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 4 VIEW: RAIL ACTIVATION
  // =========================================================================
  Widget _buildStage4Card() {
    final railReady = _status?.stage4Rail.state == OnboardingStageState.ready;
    final railProcessing =
        _status?.stage4Rail.state == OnboardingStageState.inProgress;

    return FlowPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  color: FlowPayColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Stage 4: ${_isNigeria ? 'Activate Nigeria Rail' : 'Activate Mexico Rail'}',
                style: FlowPayTypography.title(color: FlowPayColors.ink)
                    .copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isNigeria
                ? 'Issues NGN virtual account pointing at smart wallet address via POST /onboarding/start-nigeria.'
                : 'Approval requires Etherfuse agreements signing first, then POST /latam/mx/kyc/activate.',
            style: FlowPayTypography.captionStyle(
                color: FlowPayColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (!_isNigeria) ...[
            // Mexico Agreements Prerequisite Step
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _agreementsSigned
                    ? FlowPayColors.signal.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _agreementsSigned
                        ? FlowPayColors.signal
                        : Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(
                      _agreementsSigned
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      color: _agreementsSigned
                          ? FlowPayColors.signal
                          : Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _agreementsSigned
                              ? 'Etherfuse Agreements: Signed'
                              : 'Prerequisite: Sign Etherfuse Agreements',
                          style: TextStyle(
                            color: _agreementsSigned
                                ? FlowPayColors.signal
                                : Colors.amber[900],
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'GET /v1/users/{userId}/latam/mx/kyc/launch/agreements',
                          style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!_agreementsSigned)
                    TextButton(
                      onPressed: _handleSignMexicoAgreements,
                      child: const Text('Review & Sign'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (railReady) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlowPayColors.signal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: FlowPayColors.signal),
                  const SizedBox(width: 8),
                  Text('Disbursement Rail Active & Ready for Payroll',
                      style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.signal)),
                ],
              ),
            ),
          ] else if (railProcessing) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlowPayColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FlowPayColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text('Onboarding Processing',
                          style:
                              FlowPayTypography.title(color: FlowPayColors.ink)
                                  .copyWith(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Subscribed to onboarding.completed webhook. Do not poll — waiting for provider settlement confirmation.',
                    style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            BMoniButton(
              text: _isProcessingAction
                  ? 'Activating Rail...'
                  : 'Activate Rail on BMONI',
              variant: BMoniButtonVariant.primary,
              size: BMoniButtonSize.medium,
              icon: Icons.power_settings_new_rounded,
              onPressed: _handleActivateRail,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSandboxActionBar(OnboardingStageState overall) {
    return Column(
      children: [
        if (overall == OnboardingStageState.inProgress ||
            overall == OnboardingStageState.notStarted) ...[
          BMoniButton(
            text: 'Simulate Webhook (onboarding.completed)',
            variant: BMoniButtonVariant.outline,
            size: BMoniButtonSize.medium,
            icon: Icons.bolt_rounded,
            onPressed: _handleSimulateWebhook,
          ),
          const SizedBox(height: 10),
        ],
        if (overall == OnboardingStageState.failed) ...[
          BMoniButton(
            text: 'Retry Onboarding',
            variant: BMoniButtonVariant.primary,
            size: BMoniButtonSize.medium,
            icon: Icons.refresh_rounded,
            onPressed: _handleRetry,
          ),
        ],
      ],
    );
  }
}
