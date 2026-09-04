export class FlowPayError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number = 500,
    public readonly code: string = 'INTERNAL_ERROR',
    public readonly details?: unknown
  ) {
    super(message);
    this.name = 'FlowPayError';
  }
}

export class ValidationError extends FlowPayError {
  constructor(message: string, details?: unknown) {
    super(message, 400, 'VALIDATION_ERROR', details);
    this.name = 'ValidationError';
  }
}

export class BmoniApiError extends FlowPayError {
  constructor(
    message: string,
    statusCode: number,
    public readonly bmoniError?: string,
    details?: unknown
  ) {
    super(message, statusCode, 'BMONI_API_ERROR', details);
    this.name = 'BmoniApiError';
  }
}

export class FinancialSafetyError extends FlowPayError {
  constructor(message: string, details?: unknown) {
    super(message, 422, 'FINANCIAL_SAFETY_VIOLATION', details);
    this.name = 'FinancialSafetyError';
  }
}

export class UnauthorizedError extends FlowPayError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
    this.name = 'UnauthorizedError';
  }
}

export class NotFoundError extends FlowPayError {
  constructor(message: string = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
    this.name = 'NotFoundError';
  }
}

export class CardEnrollmentRequiredError extends FlowPayError {
  constructor(message: string = 'Card owner is not enrolled for cards yet. 11-digit NIN is required.') {
    super(message, 400, 'E101', { isEnrollmentRequired: true });
    this.name = 'CardEnrollmentRequiredError';
  }
}

