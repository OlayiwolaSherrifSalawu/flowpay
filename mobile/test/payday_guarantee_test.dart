import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/modules/business/components/payday_guarantee_section.dart';
import 'package:flowpay_mobile/modules/personal/components/guaranteed_pay_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
    await tester.pumpAndSettle();
  }

  testWidgets('Payday guarantee: pick a payday, review the reserved salaries, ready to lock', (tester) async {
    final appState = AppState(providerMode: ProviderMode.demo);
    await pump(tester, PaydayGuaranteeSection(appState: appState));

    expect(find.text('Payday guarantee'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget, reason: 'demo mode is labelled, never shown as on-chain');

    await tester.tap(find.byKey(const Key('guarantee_create_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guarantee_choice_2'))); // in 14 days
    await tester.tap(find.byKey(const Key('guarantee_review_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unlocks '), findsOneWidget);
    expect(find.text('Total to lock'), findsOneWidget);
    expect(find.byKey(const Key('guarantee_lock_button')), findsOneWidget);
    expect(find.textContaining("can't withdraw it before payday"), findsOneWidget);
  });

  testWidgets('Guaranteed pay card is hidden when nothing is reserved for the user', (tester) async {
    await pump(tester, GuaranteedPayCard(appState: AppState(providerMode: ProviderMode.demo)));
    expect(find.text('Your pay is guaranteed'), findsNothing);
  });
}
