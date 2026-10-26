import 'package:flutter/material.dart';
import '../../core/copy/app_copy.dart';
import '../../core/design_system/design_system.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// FlowPay landing screen — Stellar-inspired: off-black canvas, hairline grid,
/// serif statement headline, honest network facts, gold primary action.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _onGetStarted(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _onSignIn(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.darkBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -160,
            right: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [FlowPayColors.gold.withValues(alpha: 0.22), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FlowPayLogo.horizontal(size: 24),
                      const Spacer(),
                      Text('BUILT ON STELLAR', style: FlowPayTypography.eyebrow(color: FlowPayColors.gold)),
                      const SizedBox(height: 14),
                      Text(AppCopy.landingHeadline, style: FlowPayTypography.heroSerif(color: FlowPayColors.darkTextPrimary)),
                      const SizedBox(height: 14),
                      Text(
                        AppCopy.landingSubtitle,
                        style: FlowPayTypography.body(color: FlowPayColors.darkTextSecondary),
                      ),
                      const SizedBox(height: 24),
                      const _Facts(),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FlowPayButton(
                          key: const Key('landing_get_started_button'),
                          text: AppCopy.getStarted,
                          size: FlowPayButtonSize.large,
                          onPressed: () => _onGetStarted(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const Key('landing_sign_in_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FlowPayColors.darkTextPrimary,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _onSignIn(context),
                          child: const Text(AppCopy.signIn, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three honest facts about settling on Stellar.
class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    Widget fact(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: FlowPayTypography.title(color: FlowPayColors.darkTextPrimary)),
                const SizedBox(height: 2),
                Text(label, style: FlowPayTypography.captionStyle(color: FlowPayColors.darkTextTertiary)),
              ],
            ),
          ),
        );
    return Row(children: [
      fact('~5s', 'to settle'),
      fact('<\$0.01', 'network fee'),
      fact('5', 'currencies'),
    ]);
  }
}

/// Fine hairline grid, fading toward the bottom.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 36.0;
    final paint = Paint()..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += step) {
      final fade = (1 - y / size.height).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: 0.05 * fade);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += step) {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.05), Colors.transparent],
      ).createShader(Rect.fromLTWH(x, 0, 1, size.height));
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      paint.shader = null;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
