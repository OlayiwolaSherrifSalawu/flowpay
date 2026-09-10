import 'package:flutter/material.dart';
import '../../core/copy/app_copy.dart';
import '../../core/design_system/design_system.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Flagship FlowPay Landing Screen.
/// Follows the 3D metallic currency hero visual design, adapted to
/// FlowPay's Deep Obsidian and Emerald palette with static hero visual and solid buttons.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

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
          // ── Background 3D Floating Coins Image (Static, No Pulsing) ──
          Positioned.fill(
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

          // ── Top Bar Brand Indicator ──
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
                    // Primary: Get Started (Solid FlowPay Emerald Pill)
                    Expanded(
                      child: _buildGetStartedButton(context),
                    ),
                    const SizedBox(width: 14),

                    // Secondary: Sign In (Solid Dark Surface Pill)
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
        color: FlowPayColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: FlowPayColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 5),
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
        color: FlowPayColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FlowPayColors.darkBorderLight,
          width: 1.2,
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
