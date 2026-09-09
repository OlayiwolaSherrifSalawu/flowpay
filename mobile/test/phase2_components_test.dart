import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';

void main() {
  testWidgets('FlowPayScallopedCard renders title, balance, and action pill',
      (tester) async {
    bool actionTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: FlowPayScallopedCard(
            title: 'Virtual Card',
            balance: '\$12,450.00',
            holderName: 'Waffiyyi Fashola',
            expiryDate: '08/28',
            actionLabel: 'Details',
            onActionTap: () => actionTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('VIRTUAL CARD'), findsOneWidget);
    expect(find.text('\$12,450.00'), findsOneWidget);
    expect(find.text('Waffiyyi Fashola'), findsOneWidget);
    expect(find.text('08/28'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    expect(actionTapped, isTrue);
  });

  testWidgets('FlowPayQuickActionRow renders 4 default action items',
      (tester) async {
    bool depositTapped = false;
    bool transferTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: FlowPayQuickActionRow(
            onDeposit: () => depositTapped = true,
            onTransfer: () => transferTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('Deposit'));
    expect(depositTapped, isTrue);

    await tester.tap(find.text('Transfer'));
    expect(transferTapped, isTrue);
  });

  testWidgets('FlowPayIncomeExpenseRow renders income and expense amounts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: FlowPayIncomeExpenseRow(
            incomeAmount: '\$8,940.50',
            expenseAmount: '\$2,150.00',
          ),
        ),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('\$8,940.50'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('\$2,150.00'), findsOneWidget);
  });

  testWidgets('FlowPayAnalyticsCard renders title, total, and vertical bars',
      (tester) async {
    int? selectedBar;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FlowPayAnalyticsCard(
            title: 'Weekly Flow',
            totalAmount: '\$5,400.00',
            data: const [
              AnalyticsBarData(label: 'Mon', value: 30),
              AnalyticsBarData(label: 'Tue', value: 80, isPeak: true),
              AnalyticsBarData(label: 'Wed', value: 50),
            ],
            onBarSelected: (index) => selectedBar = index,
          ),
        ),
      ),
    );

    expect(find.text('WEEKLY FLOW'), findsOneWidget);
    expect(find.text('\$5,400.00'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);

    await tester.tap(find.text('Tue'));
    expect(selectedBar, equals(1));
  });

  testWidgets('FlowPayAmountField renders currency pill and numeric input',
      (tester) async {
    final controller = TextEditingController(text: '250.00');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: FlowPayAmountField(
            controller: controller,
            currencyCode: 'USDC',
            currencySymbol: '\$',
          ),
        ),
      ),
    );

    expect(find.text('USDC'), findsOneWidget);
    expect(find.text('\$'), findsOneWidget);
    expect(find.text('250.00'), findsOneWidget);
  });
}
