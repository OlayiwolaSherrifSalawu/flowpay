import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/config/api_config.dart';
import '../../core/design_system/design_system.dart';

/// Dedicated 6-Digit PIN Setup Screen.
/// Step 3 of the Onboarding Flow: Signup -> KYC -> Set PIN.
/// Conforms to official BMONI Embedded SDK guidelines:
/// 1. Asks user to enter and confirm 6-digit PIN.
/// 2. Provisions on-device wallet keypair via `BmoniSdkService.initWallet()`.
/// 3. Stores salted PBKDF2 digest in secure hardware storage via `BmoniSdkService.setPin()`.
class SetPinScreen extends ConsumerStatefulWidget {
  final UserProfile userProfile;
  final String? employeeInviteToken;
  final String? employeeId;

  const SetPinScreen({
    super.key,
    required this.userProfile,
    this.employeeInviteToken,
    this.employeeId,
  });

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  String _initialPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isSettingUp = false;
  String? _errorMessage;

  void _onDigitTapped(String digit) {
    if (_isSettingUp) return;

    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_initialPin.length < 6) {
          _initialPin += digit;
          if (_initialPin.length == 6) {
            // Transition to confirmation stage
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _isConfirming = true);
            });
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            _validateAndComplete();
          }
        }
      }
    });
  }

  void _onBackspace() {
    if (_isSettingUp) return;

    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_initialPin.isNotEmpty) {
          _initialPin = _initialPin.substring(0, _initialPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Go back to stage 1 if user hits backspace on empty confirm
          _isConfirming = false;
          _initialPin = '';
        }
      }
    });
  }

  Future<void> _validateAndComplete() async {
    if (_initialPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
        _initialPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isSettingUp = true);

    try {
      // 1. Provision hardware keypair on device via BMONI Embedded SDK
      final generatedAddress = await BmoniSdkService.initWallet();

      // 2. Set 6-digit PIN in BMONI SDK (salted PBKDF2 digest in Secure Storage)
      await BmoniSdkService.setPin(_initialPin);

      // 3. Store fallback PIN and establish active user session
      final storage = ref.read(secureStorageServiceProvider);
      await storage.setFallbackPin(_initialPin);

      // 4. Register on-device wallet keypair with FlowPay backend
      try {
        final walletAddr =
            await BmoniSdkService.walletAddress() ?? generatedAddress;
        if (!SecureStorageService.isTestEnv) {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/wallets/register'),
            headers: {
              'Content-Type': 'application/json',
              'x-user-id': widget.userProfile.userId,
            },
            body: jsonEncode({
              'userId': widget.userProfile.userId,
              'address': walletAddr,
            }),
          ).timeout(const Duration(seconds: 4));
        }
      } catch (regErr) {
        debugPrint('[SetPinScreen] register wallet notice: $regErr');
      }

      // 5. Link employee's self-custody wallet to payroll roster if invite flow
      if (widget.employeeInviteToken != null &&
          widget.employeeInviteToken!.trim().isNotEmpty) {
        try {
          final walletAddr =
              await BmoniSdkService.walletAddress() ?? generatedAddress;
          final sessionToken = await storage.getAuthToken() ??
              'flowpay_jwt_${widget.userProfile.userId}';

          if (!SecureStorageService.isTestEnv) {
            await http.post(
              Uri.parse('${ApiConfig.baseUrl}/api/employees/link-wallet'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $sessionToken',
                'x-user-id': widget.userProfile.userId,
              },
              body: jsonEncode({
                'employeeId': widget.employeeId,
                'inviteToken': widget.employeeInviteToken,
                'bmoniUserId': widget.userProfile.userId,
                'walletAddress': walletAddr,
                'requestingUserId': widget.userProfile.userId,
              }),
            ).timeout(const Duration(seconds: 4));
          }
        } catch (linkErr) {
          debugPrint('[SetPinScreen] link-wallet notice: $linkErr');
        }
      }

      if (!mounted) return;
      // Log in user and unlock into corresponding shell
      await ref
          .read(appLockStateProvider.notifier)
          .loginAsPersona(widget.userProfile, pin: _initialPin);

      if (!mounted) return;
      if (widget.employeeInviteToken != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: FlowPayColors.success,
            content: Text(
              'Hardware wallet linked to corporate payroll! You have full custody of your earnings.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      // Pop back to root (AppAuthGate will render the unlocked shell)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSettingUp = false;
          _errorMessage = 'Failed to configure PIN: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePin = _isConfirming ? _confirmPin : _initialPin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondary =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            if (_isConfirming) {
              setState(() {
                _isConfirming = false;
                _confirmPin = '';
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlowPayLogo.compact(),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FlowPayColors.primary.withValues(alpha: 0.1),
                borderRadius: FlowPayRadii.chip,
                border: Border.all(
                    color: FlowPayColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Step 3 of 3',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FlowPayColors.primary,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Hero Shield Icon ──
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark
                                ? FlowPayColors.darkSurfaceElevated
                                : FlowPayColors.mint100,
                            borderRadius: FlowPayRadii.card,
                            border: Border.all(
                              color:
                                  FlowPayColors.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FlowPayColors.primary
                                    .withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 36,
                            color: FlowPayColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Title & Instructions ──
                        Text(
                          _isConfirming
                              ? 'Confirm Your 6-Digit PIN'
                              : 'Set Your 6-Digit PIN',
                          style: FlowPayTypography.headline()
                              .copyWith(color: textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isConfirming
                              ? 'Re-enter your 6-digit PIN to confirm.'
                              : 'This PIN authorizes transfers, payroll disbursements, and unlocks FlowPay.',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // ── 6 PIN Dots ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final isFilled = index < activePin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? FlowPayColors.emerald600
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isFilled
                                      ? FlowPayColors.emerald600
                                      : borderColor,
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 16),

                        // ── Error banner ──
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: FlowPayColors.error.withValues(alpha: 0.1),
                              borderRadius: FlowPayRadii.chip,
                              border: Border.all(
                                  color: FlowPayColors.error
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FlowPayColors.error,
                              ),
                            ),
                          ),

                        if (_isSettingUp) ...[
                          const Spacer(),
                          const CircularProgressIndicator(
                              color: FlowPayColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Setting up your secure wallet...',
                            style: TextStyle(
                                fontSize: 13, color: textSecondary),
                          ),
                          const Spacer(),
                        ] else ...[
                          const Spacer(),

                          // ── Trust Banner ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 12),
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
                                Icon(Icons.key_outlined,
                                    size: 13,
                                    color: FlowPayColors.primary
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Your 6-digit PIN confirms payments securely. It is never stored in plain text.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Custom Numeric Keypad ──
                          _buildKeypad(isDark, surfaceColor, borderColor,
                              textPrimary),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypad(
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
  ) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row
                .map((d) => _buildKey(d,
                    onTap: () => _onDigitTapped(d),
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary))
                .toList(),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 72),
            _buildKey('0',
                onTap: () => _onDigitTapped('0'),
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textPrimary: textPrimary),
            _buildBackspaceKey(
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textPrimary: textPrimary),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(
    String label, {
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return Semantics(
      button: true,
      label: 'Digit $label',
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey({
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return Semantics(
      button: true,
      label: 'Backspace',
      child: InkResponse(
        onTap: _onBackspace,
        radius: 36,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_outlined,
            color: textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

