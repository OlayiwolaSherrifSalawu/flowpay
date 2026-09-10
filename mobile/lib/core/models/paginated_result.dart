import 'dart:math';

/// Generic immutable pagination container model.
/// Provides consistent metadata across all paginated domain entities in FlowPay.
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  /// Factory constructor to slice an in-memory list deterministically
  factory PaginatedResult.paginateList(
    List<T> allItems, {
    int page = 1,
    int limit = 10,
  }) {
    final safeLimit = limit < 1 ? 10 : limit;
    final total = allItems.length;
    final totalPages = max(1, (total / safeLimit).ceil());
    final safePage = page.clamp(1, totalPages);

    if (total == 0) {
      return PaginatedResult(
        items: const [],
        page: 1,
        limit: safeLimit,
        total: 0,
        totalPages: 1,
        hasNext: false,
        hasPrevious: false,
      );
    }

    final startIndex = (safePage - 1) * safeLimit;
    final endIndex = min(startIndex + safeLimit, total);
    final pageItems = startIndex < total
        ? allItems.sublist(startIndex, endIndex)
        : <T>[];

    return PaginatedResult(
      items: pageItems,
      page: safePage,
      limit: safeLimit,
      total: total,
      totalPages: totalPages,
      hasNext: safePage < totalPages,
      hasPrevious: safePage > 1,
    );
  }

  /// Empty result helper
  factory PaginatedResult.empty({int limit = 10}) {
    return PaginatedResult(
      items: const [],
      page: 1,
      limit: limit,
      total: 0,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
    );
  }

  /// Starting 1-based index of items currently displayed
  int get startItemIndex => total == 0 ? 0 : (page - 1) * limit + 1;

  /// Ending 1-based index of items currently displayed
  int get endItemIndex => total == 0 ? 0 : min(page * limit, total);

  /// Human-friendly range display (e.g. "Showing 1–10 of 47")
  String get rangeLabel {
    if (total == 0) return '0 items';
    return 'Showing $startItemIndex–$endItemIndex of $total';
  }

  /// Map items to another type preserving pagination metadata
  PaginatedResult<R> map<R>(R Function(T item) transform) {
    return PaginatedResult<R>(
      items: items.map(transform).toList(),
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
      hasNext: hasNext,
      hasPrevious: hasPrevious,
    );
  }
}
