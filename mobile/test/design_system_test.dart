import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';

void main() {
  group('FlowPay Design System Primitives', () {
    testWidgets('Renders FlowPayButton variants and sizes', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: FlowPayButton(
              text: 'Send Payment',
              variant: FlowPayButtonVariant.primary,
              icon: Icons.send,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Send Payment'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.tap(find.byType(FlowPayButton));
      expect(tapped, isTrue);
    });

    testWidgets('Renders FlowPayCard variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                FlowPayCard(
                  variant: FlowPayCardVariant.surface,
                  child: Text('Surface Card'),
                ),
                FlowPayCard(
                  variant: FlowPayCardVariant.elevated,
                  child: Text('Elevated Card'),
                ),
                FlowPayStatCard(
                  label: 'Balance',
                  value: '\$5,000.00',
                  subtitle: '+12% this month',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Surface Card'), findsOneWidget);
      expect(find.text('Elevated Card'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('\$5,000.00'), findsOneWidget);
    });

    testWidgets('Renders FlowPayTextField and FlowPayAmountField', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                FlowPayTextField(
                  label: 'Work Email',
                  hintText: 'john@example.com',
                  controller: ctrl,
                ),
                const FlowPayAmountField(
                  currencyCode: 'USD',
                  currencySymbol: '\$',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Work Email'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('\$'), findsOneWidget);
    });

    testWidgets('Renders FlowPayStatusBadge across all 10 shared states', (tester) async {
      const states = [
        FlowPayAppStatus.loading,
        FlowPayAppStatus.success,
        FlowPayAppStatus.error,
        FlowPayAppStatus.empty,
        FlowPayAppStatus.pending,
        FlowPayAppStatus.awaitingApproval,
        FlowPayAppStatus.processing,
        FlowPayAppStatus.completed,
        FlowPayAppStatus.failed,
        FlowPayAppStatus.cancelled,
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: Column(
              children: states.map((s) => FlowPayStatusBadge(appStatus: s)).toList(),
            ),
          ),
        ),
      );

      for (final s in states) {
        expect(find.text(s.label.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('Renders FlowPayAmountDisplay with tabular figures', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: const Scaffold(
            body: FlowPayAmountDisplay(
              amount: '4,250.00',
              currencySymbol: '\$',
              currencyCode: 'USD',
              secondaryAmount: '≈ ₦6,800,000 NGN',
              size: AmountDisplaySize.large,
            ),
          ),
        ),
      );

      expect(find.text('4,250'), findsOneWidget);
      expect(find.text('.00'), findsOneWidget);
      expect(find.text('\$'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('≈ ₦6,800,000 NGN'), findsOneWidget);
    });

    testWidgets('Renders FlowPayCurrencyDisplay in both full and compact styles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                FlowPayCurrencyDisplay(
                  code: 'NGN',
                  symbol: '₦',
                  name: 'Nigerian Naira',
                  tokenName: 'BMONI cNGN',
                ),
                FlowPayCurrencyDisplay(
                  code: 'USD',
                  symbol: '\$',
                  name: 'US Dollar',
                  isCompact: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nigerian Naira'), findsOneWidget);
      expect(find.text('BMONI cNGN'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets('Renders FlowPayStateView with universal states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: const Scaffold(
            body: FlowPayStateView(
              status: FlowPayAppStatus.loading,
              loadingMessage: 'Synchronizing rails...',
              content: Text('Live Content'),
            ),
          ),
        ),
      );

      expect(find.text('Synchronizing rails...'), findsOneWidget);
      expect(find.text('Live Content'), findsNothing);
    });
  });
}
