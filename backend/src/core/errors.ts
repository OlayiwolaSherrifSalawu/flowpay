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

export class InsufficientFundsError extends FlowPayError {
  constructor(message: string = 'Insufficient funds across available smart wallets for this operation.') {
    super(message, 400, 'INSUFFICIENT_FUNDS');
    this.name = 'InsufficientFundsError';
  }
}

export class InvalidRequestError extends FlowPayError {
  constructor(message: string, details?: unknown) {
    super(message, 400, 'INVALID_REQUEST', details);
    this.name = 'InvalidRequestError';
  }
}

export class KycOnboardingError extends FlowPayError {
  constructor(message: string, details?: unknown) {
    super(message, 400, 'KYC_ONBOARDING_FAILED', details);
    this.name = 'KycOnboardingError';
  }
}

export class SignatureFailureError extends FlowPayError {
  constructor(message: string = 'On-device PIN signature verification failed.') {
    super(message, 400, 'SIGNATURE_FAILURE');
    this.name = 'SignatureFailureError';
  }
}

export class ProposalExpiredError extends FlowPayError {
  constructor(message: string = 'The financial proposal has expired. Please review updated rates and generate a new proposal.') {
    super(message, 400, 'PROPOSAL_EXPIRED');
    this.name = 'ProposalExpiredError';
  }
}

export class UnsupportedCurrencyError extends FlowPayError {
  constructor(currency: string) {
    super(`Currency ${currency} is not supported. Supported: USD, CAD, MXN, GBP, NGN.`, 400, 'UNSUPPORTED_CURRENCY');
    this.name = 'UnsupportedCurrencyError';
  }
}

/**
 * A Stellar operation failed. `resultCodes` carries Horizon's `extras.result_codes`
 * (e.g. { transaction: 'tx_failed', operations: ['op_underfunded'] }) so callers and the
 * UI can explain *why* — never swallow this into a success.
 */
export class StellarError extends FlowPayError {
  constructor(
    message: string,
    statusCode: number = 502,
    code: string = 'STELLAR_ERROR',
    public readonly resultCodes?: { transaction?: string; operations?: string[] },
    details?: unknown
  ) {
    super(message, statusCode, code, { resultCodes, ...(details as object | undefined) });
    this.name = 'StellarError';
  }
}

export class StellarAccountNotFoundError extends StellarError {
  constructor(public readonly accountId: string) {
    super(`Stellar account ${accountId} does not exist on the network yet (it must be funded first).`, 404, 'STELLAR_ACCOUNT_NOT_FOUND');
    this.name = 'StellarAccountNotFoundError';
  }
}

/**
 * Submission outcome is UNKNOWN (Horizon timeout / network drop). The transaction may still
 * land. Record it as PENDING and reconcile by `hash` — never report it as failed or completed.
 */
export class StellarSubmitTimeoutError extends StellarError {
  constructor(public readonly hash: string, details?: unknown) {
    super(`Stellar submission for ${hash} timed out; outcome pending reconciliation.`, 504, 'STELLAR_SUBMIT_PENDING', undefined, details);
    this.name = 'StellarSubmitTimeoutError';
  }
}
