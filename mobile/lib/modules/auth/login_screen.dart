import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/radii.dart';
import '../../core/theme/typography.dart';
import 'signup_screen.dart';

/// FlowPay Log In Screen.
/// Used when authentication has expired or user wants to sign in to an existing account.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _autofillPersonal() {
    setState(() {
      _emailController.text = 'bunch.dillon@remote.africa';
      _pinController.text = '123456';
      _errorMessage = null;
    });
  }

  void _autofillBusiness() {
    setState(() {
      _emailController.text = 'waffiyyi@flowpay.finance';
      _pinController.text = '123456';
      _errorMessage = null;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    try {
      // 1. Validate PIN against secure storage fallback or BMONI SDK
      final isValidPin =
          await ref.read(secureStorageServiceProvider).verifyFallbackPin(pin);
      if (!isValidPin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect 6-digit PIN.';
        });
        return;
      }

      // 2. Resolve persona by email domain/type
      final isBusiness = email.contains('flowpay') ||
          email.contains('business') ||
          email.contains('company');
      final profile = isBusiness
          ? UserProfile(
              userId:
                  'usr_flowpay_business_${email.hashCode.abs().toString().substring(0, 6)}',
              fullName: 'Waffiyyi Fashola',
              email: email,
              phone: '+14155552671',
              country: 'US',
              accountType: AccountType.business,
              companyName: 'FlowPay Technologies Ltd',
              companyRole: 'Founder & CEO',
              kycStatus: KycStatus.verified,
              createdAt: DateTime.now(),
            )
          : UserProfile(
              userId:
                  'usr_flowpay_personal_${email.hashCode.abs().toString().substring(0, 6)}',
              fullName: 'Bunch Dillon',
              email: email,
              phone: '+2348012345678',
              country: 'NG',
              accountType: AccountType.personal,
              kycStatus: KycStatus.verified,
              createdAt: DateTime.now(),
            );

      // 3. Establish active session
      await ref
          .read(appLockStateProvider.notifier)
          .loginAsPersona(profile, pin: pin);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FlowPayColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const PoweredByBmoniBadge(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Hero Icon
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: FlowPayColors.surfaceAlt,
                      borderRadius: FlowPayRadii.card,
                      border: Border.all(color: FlowPayColors.hairline),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      color: FlowPayColors.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Log In to FlowPay',
                  style: FlowPayTypography.headline(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your account email and 6-digit signing PIN.',
                  style: TextStyle(
                    fontSize: 13,
                    color: FlowPayColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FlowPayColors.stateError.withAlpha(25),
                      borderRadius: FlowPayRadii.input,
                      border: Border.all(color: FlowPayColors.stateError),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FlowPayColors.stateError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email
                const Text(
                  'Account Email',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.ink),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style:
                      const TextStyle(color: FlowPayColors.ink, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'name@company.com',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: FlowPayColors.textSecondary, size: 18),
                    filled: true,
                    fillColor: FlowPayColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: FlowPayColors.hairline),
                    ),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email address'
                      : null,
                ),

                const SizedBox(height: 18),

                // PIN
                const Text(
                  '6-Digit PIN',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.ink),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: const TextStyle(
                      color: FlowPayColors.ink, fontSize: 18, letterSpacing: 4),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: FlowPayColors.textSecondary, size: 18),
                    filled: true,
                    fillColor: FlowPayColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: FlowPayColors.hairline),
                    ),
                  ),
                  validator: (v) => v == null || v.length != 6
                      ? 'PIN must be 6 digits'
                      : null,
                ),

                const SizedBox(height: 16),

                // Quick Autofill
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.bolt,
                              size: 14, color: FlowPayColors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Quick Autofill Account',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FlowPayColors.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: FlowPayColors.hairline),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                              onPressed: _autofillPersonal,
                              child: const Text('👤 Personal',
                                  style: TextStyle(
                                      fontSize: 12, color: FlowPayColors.ink)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: FlowPayColors.hairline),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                              onPressed: _autofillBusiness,
                              child: const Text('💼 Business',
                                  style: TextStyle(
                                      fontSize: 12, color: FlowPayColors.ink)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                FlowPayButton(
                  text: _isLoading ? 'Authenticating...' : 'Log In',
                  icon: Icons.login,
                  onPressed: _isLoading ? null : _login,
                ),

                const SizedBox(height: 16),

                // Go to signup
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.primary),
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
}
