import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';
import 'package:flowpay_mobile/core/models/paginated_result.dart';

void main() {
  group('PaginatedResult Logic Tests', () {
    test('paginateList handles normal range and pages correctly', () {
      final items = List.generate(47, (i) => 'Item $i');
      final page1 = PaginatedResult.paginateList(items, page: 1, limit: 10);

      expect(page1.page, 1);
      expect(page1.limit, 10);
      expect(page1.total, 47);
      expect(page1.totalPages, 5);
      expect(page1.hasPrevious, isFalse);
      expect(page1.hasNext, isTrue);
      expect(page1.items.length, 10);
      expect(page1.items.first, 'Item 0');
      expect(page1.items.last, 'Item 9');
      expect(page1.rangeLabel, 'Showing 1–10 of 47');

      final page5 = PaginatedResult.paginateList(items, page: 5, limit: 10);
      expect(page5.page, 5);
      expect(page5.hasPrevious, isTrue);
      expect(page5.hasNext, isFalse);
      expect(page5.items.length, 7);
      expect(page5.items.first, 'Item 40');
      expect(page5.items.last, 'Item 46');
      expect(page5.rangeLabel, 'Showing 41–47 of 47');
    });

    test('paginateList clamps out-of-bounds page numbers safely', () {
      final items = List.generate(15, (i) => 'Item $i');

      final clampedLow = PaginatedResult.paginateList(items, page: 0, limit: 10);
      expect(clampedLow.page, 1);
      expect(clampedLow.items.length, 10);

      final clampedHigh = PaginatedResult.paginateList(items, page: 99, limit: 10);
      expect(clampedHigh.page, 2);
      expect(clampedHigh.items.length, 5);
    });

    test('paginateList handles empty list without exceptions', () {
      final emptyResult = PaginatedResult.paginateList(<String>[], page: 1, limit: 10);
      expect(emptyResult.page, 1);
      expect(emptyResult.total, 0);
      expect(emptyResult.totalPages, 1);
      expect(emptyResult.items, isEmpty);
      expect(emptyResult.hasPrevious, isFalse);
      expect(emptyResult.hasNext, isFalse);
      expect(emptyResult.rangeLabel, '0 items');
    });
  });

  group('FlowPayPaginationBar Widget Tests', () {
    testWidgets('renders range text and pagination controls correctly', (tester) async {
      int changedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowPayPaginationBar(
              currentPage: 2,
              totalPages: 5,
              totalItems: 47,
              pageSize: 10,
              itemLabel: 'employees',
              onPageChanged: (newPage) => changedPage = newPage,
            ),
          ),
        ),
      );

      // Verify range display with label
      expect(find.text('Showing 11–20 of 47 employees'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Prev'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(changedPage, 3);

      // Tap Prev
      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();
      expect(changedPage, 1);
    });

    testWidgets('disables Prev button on first page', (tester) async {
      int changedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowPayPaginationBar(
              currentPage: 1,
              totalPages: 5,
              totalItems: 47,
              pageSize: 10,
              onPageChanged: (newPage) => changedPage = newPage,
            ),
          ),
        ),
      );

      expect(find.text('Showing 1–10 of 47'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);

      // Prev should not trigger callback
      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();
      expect(changedPage, -1);

      // Next should trigger callback to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(changedPage, 2);
    });

    testWidgets('disables Next button on last page', (tester) async {
      int changedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlowPayPaginationBar(
              currentPage: 5,
              totalPages: 5,
              totalItems: 47,
              pageSize: 10,
              onPageChanged: (newPage) => changedPage = newPage,
            ),
          ),
        ),
      );

      expect(find.text('Showing 41–47 of 47'), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);

      // Next should not trigger callback
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(changedPage, -1);

      // Prev should trigger callback to page 4
      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();
      expect(changedPage, 4);
    });
  });
}
