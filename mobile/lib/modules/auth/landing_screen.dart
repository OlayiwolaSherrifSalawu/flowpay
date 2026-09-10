import 'package:flutter/material.dart';
import '../../core/auth/secure_storage_service.dart';
import '../../core/copy/app_copy.dart';
import '../../core/design_system/design_system.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Flagship FlowPay Landing Screen.
/// Follows the 3D metallic currency hero visual design, adapted to
/// FlowPay's Deep Obsidian, Electric Emerald, and Vivid Cyan palette.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (!SecureStorageService.isTestEnv) {
      _animController.repeat(reverse: true);
    }

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onGetStarted(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _onSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: FlowPayColors.darkBackground,
      body: Stack(
        children: [
          // ── Background 3D Floating Coins Image ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/flowpay_landing_hero.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  // Resilient fallback if asset rendering in specific test environments
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.4),
                        radius: 0.8,
                        colors: [
                          Color(0xFF0F2B20),
                          FlowPayColors.darkBackground,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: FlowPayLogo(size: 96),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Smooth Vignette Gradient for Crystal-Clear Text Legibility ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.42, 0.62, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    FlowPayColors.darkBackground.withValues(alpha: 0.82),
                    FlowPayColors.darkBackground,
                  ],
                ),
              ),
            ),
          ),

          // ── Top Bar Brand Indicator (Secure Badge Removed) ──
          Positioned(
            top: topPadding + 14,
            left: 28,
            child: const FlowPayLogo.horizontal(size: 24),
          ),

          // ── Bottom Content: Headline, Subtitle & Pill CTAs ──
          Positioned(
            left: 28,
            right: 28,
            bottom: bottomPadding + 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Headline (3-Line Command Rhythm)
                const Text(
                  AppCopy.landingHeadline,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 18),

                // Subtitle
                Text(
                  AppCopy.landingSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Action Buttons Row (Side-by-side Pill Buttons) ──
                Row(
                  children: [
                    // Primary: Get Started (Luminous Emerald-Cyan Pill)
                    Expanded(
                      child: _buildGetStartedButton(context),
                    ),
                    const SizedBox(width: 14),

                    // Secondary: Sign In (Translucent Glass Pill)
                    Expanded(
                      child: _buildSignInButton(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00E599),
            Color(0xFF00B4D8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E599).withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('landing_get_started_button'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => _onGetStarted(context),
          child: const Center(
            child: Text(
              AppCopy.getStarted,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('landing_sign_in_button'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => _onSignIn(context),
          child: const Center(
            child: Text(
              AppCopy.signIn,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
