import { Money, type SupportedCurrency } from '../../core/money.js';

export interface StructuredFinancialIntent {
  intentId: string;
  originalPrompt: string;
  operationType: 'TRANSFER' | 'PAYROLL_RUN' | 'CARD_SPEND_LIMIT' | 'MISSION_CREATE' | 'CURRENCY_SWAP';
  parameters: {
    recipientIdentifier?: string; // email, username, or employee name
    recipientUserId?: string;
    sourceCurrency: SupportedCurrency;
    targetCurrency?: SupportedCurrency;
    amountMinor?: string;
    amountFormatted?: string;
    description?: string;
  };
  explanation: string;
  confidenceScore: number;
  requiresExplicitApproval: true; // Hardcoded invariant: Always requires approval
}

export class FinancialIntentInterpreter {
  /**
   * Interprets natural language prompt into a structured financial intent.
   * Uses deterministic pattern extraction with optional LLM enhancement.
   * AI NEVER executes money movement; it only produces structured parameters.
   */
  static interpret(prompt: string): StructuredFinancialIntent {
    const trimmed = prompt.trim();
    const intentId = `intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // Rule 1: Multi-country / aggregate payroll command
    if (/payroll|pay (all|team|employees)/i.test(trimmed)) {
      return {
        intentId,
        originalPrompt: trimmed,
        operationType: 'PAYROLL_RUN',
        parameters: {
          sourceCurrency: 'USD',
          description: 'Multi-country payroll disbursement',
        },
        explanation: 'Run payroll for all linked employees in their local currencies with aggregate USD settlement.',
        confidenceScore: 0.95,
        requiresExplicitApproval: true,
      };
    }

    // Rule 2: Transfer / Send money
    // e.g. "Send $250 to Bunch Dillon" or "Pay 50,000 NGN to Samson"
    const amountCurrencyMatch = trimmed.match(/(?:\$|USD\s*|NGN\s*|MXN\s*|EUR\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(USD|NGN|MXN|EUR|dollars?|naira|pesos?)?/i);
    const recipientMatch = trimmed.match(/(?:to|for)\s+([A-Za-z0-9._%+-]+(?:@[A-Za-z0-9.-]+\.[A-Za-z]{2,})?|[A-Z][a-z]+\s+[A-Z][a-z]+)/i);

    let currency: SupportedCurrency = 'USD';
    if (/naira|ngn/i.test(trimmed)) currency = 'NGN';
    else if (/pesos|mxn/i.test(trimmed)) currency = 'MXN';
    else if (/eur|euro/i.test(trimmed)) currency = 'EUR';

    let amountMinor = '0';
    let amountFormatted = '0.00';

    if (amountCurrencyMatch && amountCurrencyMatch[1]) {
      const cleanNum = amountCurrencyMatch[1].replace(/,/g, '');
      const money = Money.fromMajor(cleanNum, currency);
      amountMinor = money.amountMinor.toString();
      amountFormatted = money.toMajorString();
    }

    const recipient = recipientMatch ? recipientMatch[1].trim() : undefined;

    return {
      intentId,
      originalPrompt: trimmed,
      operationType: 'TRANSFER',
      parameters: {
        recipientIdentifier: recipient,
        sourceCurrency: currency,
        amountMinor,
        amountFormatted,
        description: `Transfer to ${recipient ?? 'recipient'}`,
      },
      explanation: `Prepared transfer proposal of ${amountFormatted} ${currency} to ${recipient ?? 'unspecified recipient'}. Awaiting your deterministic validation and PIN approval.`,
      confidenceScore: recipient && amountMinor !== '0' ? 0.9 : 0.6,
      requiresExplicitApproval: true,
    };
  }
}
