import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/config/api_config.dart';
import '../../core/design_system/design_system.dart';
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    if (SecureStorageService.isTestEnv) {
      final profile = UserProfile(
        userId: 'usr_test_${email.contains('business') ? 'business' : 'personal'}_1',
        fullName: 'FlowPay User',
        email: email,
        phone: '+2348012345678',
        country: 'NG',
        accountType: email.contains('business') ? AccountType.business : AccountType.personal,
        kycStatus: KycStatus.verified,
        createdAt: DateTime.now(),
      );
      await ref
          .read(appLockStateProvider.notifier)
          .loginAsPersona(profile, pin: pin);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    try {
      // 1. Authenticate against FlowPay backend & Supabase
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'pin': pin,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        String msg = 'Login failed. Please check your credentials.';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;

      final profile = UserProfile(
        userId: userJson['userId'] ?? userJson['id'],
        fullName: userJson['fullName'] ?? 'FlowPay User',
        email: userJson['email'] ?? email,
        phone: userJson['phone'] ?? '',
        country: userJson['country'] ?? 'US',
        accountType: userJson['accountType'] == 'business'
            ? AccountType.business
            : AccountType.personal,
        companyName: userJson['companyName'],
        companyRole: userJson['companyRole'],
        kycStatus: userJson['kycStatus'] == 'verified'
            ? KycStatus.verified
            : (userJson['kycStatus'] == 'pending'
                ? KycStatus.pending
                : KycStatus.unverified),
        createdAt: DateTime.now(),
      );

      // 2. Establish active session and save credentials
      await ref
          .read(appLockStateProvider.notifier)
          .loginAsPersona(profile, pin: pin);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String message =
            'Unable to connect to FlowPay server. Please check your network connection.';
        if (errStr.contains('TimeoutException')) {
          message =
              'Server is waking up from standby. Please tap Log In again in a few moments.';
        }
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // ── Hero Section — FlowPay logo mark with glow ring ──
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.darkSurfaceElevated
                              : FlowPayColors.mint100,
                          borderRadius: FlowPayRadii.card,
                          border: Border.all(
                            color: FlowPayColors.primary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  FlowPayColors.primary.withValues(alpha: 0.18),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: FlowPayLogo(size: 48),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome Back',
                        style: FlowPayTypography.headline()
                            .copyWith(color: textPrimary, fontSize: 26),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your money. Your rules. AI executes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Error Banner ──
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowPayColors.error.withValues(alpha: 0.08),
                      borderRadius: FlowPayRadii.input,
                      border: Border.all(
                          color: FlowPayColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: FlowPayColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FlowPayColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Account Email ──
                Text(
                  'Account Email',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('login_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'name@company.com',
                    hintStyle: TextStyle(color: textSecondary),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: textSecondary, size: 18),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(
                          color: FlowPayColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email address'
                      : null,
                ),

                const SizedBox(height: 18),

                // ── 6-Digit PIN ──
                Text(
                  '6-Digit PIN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('login_pin_field'),
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  style: TextStyle(
                      color: textPrimary, fontSize: 20, letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle:
                        TextStyle(color: textSecondary, letterSpacing: 4),
                    prefixIcon: Icon(Icons.lock_outline,
                        color: textSecondary, size: 18),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: FlowPayRadii.input,
                      borderSide: BorderSide(
                          color: FlowPayColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length != 6 ? 'PIN must be 6 digits' : null,
                ),

                const SizedBox(height: 28),

                // ── Submit Button ──
                FlowPayButton(
                  key: const Key('login_submit_button'),
                  text: _isLoading ? 'Authenticating...' : 'Log In',
                  icon: Icons.login_rounded,
                  onPressed: _isLoading ? null : _login,
                ),

                const SizedBox(height: 16),

                // ── Go to Signup ──
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
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

                const SizedBox(height: 24),

                // ── Trust Banner ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Icon(Icons.shield_outlined,
                          size: 14,
                          color: FlowPayColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'Your account is secured on this device',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
