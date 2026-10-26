import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';

void main() {
  group('FlowPay Design System Foundation (Phase 1)', () {
    test('FlowPayColors matches approved Current palette tokens', () {
      expect(FlowPayColors.emerald700, const Color(0xFF005F67));
      expect(FlowPayColors.emerald600, const Color(0xFF00818B));
      expect(FlowPayColors.emerald400, const Color(0xFF00A7B5));
      expect(FlowPayColors.primary, const Color(0xFF00818B));
      expect(FlowPayColors.gold, const Color(0xFFFDDA24));
      expect(FlowPayColors.mint100, const Color(0xFFFFF6CC));
      expect(FlowPayColors.ink, const Color(0xFF0F0F0F));
      expect(FlowPayColors.paper, const Color(0xFFF9F9F9));

      // Transaction states
      expect(FlowPayColors.success, const Color(0xFF12A150));
      expect(FlowPayColors.pending, const Color(0xFFD8A400));
      expect(FlowPayColors.error, const Color(0xFFD14343));
      expect(FlowPayColors.info, const Color(0xFF2E6FF2));

      // Dark mode palette
      expect(FlowPayColors.darkBackground, const Color(0xFF0F0F0F));
      expect(FlowPayColors.darkSurface, const Color(0xFF191919));
      expect(FlowPayColors.darkAccent, const Color(0xFFFDDA24));
    });

    test('FlowPayRadii conforms to Stellar-style low-radius geometry', () {
      expect(FlowPayRadii.cardValue, 12.0);
      expect(FlowPayRadii.cardLargeValue, 16.0);
      expect(FlowPayRadii.buttonValue, 9999.0);
      expect(FlowPayRadii.inputValue, 10.0);
      expect(FlowPayRadii.sheetValue, 20.0);
      expect(FlowPayRadii.quickActionValue, 12.0);
    });

    testWidgets('FlowPayTheme mounts properly in Light and Dark MaterialApp',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.light(),
          darkTheme: FlowPayTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: Text('FlowPay Theme Test'),
            ),
          ),
        ),
      );

      expect(find.text('FlowPay Theme Test'), findsOneWidget);
    });

    testWidgets('FlowPayLogo renders correctly with mark and wordmark',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FlowPayLogo(
                size: 40,
                showWordmark: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FlowPayLogo), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
    });
  });
}
