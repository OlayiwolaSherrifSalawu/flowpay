export interface PaginationParams {
  page: number;
  limit: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNext: boolean;
  hasPrevious: boolean;
}

export function parsePaginationParams(
  query: Record<string, any>,
  defaultLimit = 10,
  maxLimit = 100
): PaginationParams {
  const page = Math.max(1, parseInt(query.page as string, 10) || 1);
  const rawLimit =
    parseInt(
      (query.limit || query.pageSize || query.size) as string,
      10
    ) || defaultLimit;
  const limit = Math.min(maxLimit, Math.max(1, rawLimit));
  return { page, limit };
}

export function buildPaginatedResponse<T>(
  items: T[],
  total: number,
  page: number,
  limit: number
): PaginatedResponse<T> {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    items,
    page,
    limit,
    total,
    totalPages,
    hasNext: page < totalPages,
    hasPrevious: page > 1,
  };
}

export function paginateArray<T>(
  all: T[],
  page: number,
  limit: number
): PaginatedResponse<T> {
  const total = all.length;
  const totalPages = Math.max(1, Math.ceil(total / limit));
  const safePage = Math.min(totalPages, Math.max(1, page));
  const start = (safePage - 1) * limit;
  const items = all.slice(start, start + limit);
  return buildPaginatedResponse(items, total, safePage, limit);
}
