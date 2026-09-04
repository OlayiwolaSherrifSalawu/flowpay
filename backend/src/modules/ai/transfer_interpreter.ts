import { GoogleGenAI, Type } from '@google/genai';
import { env } from '../../config/env.js';
import { Money, type SupportedCurrency } from '../../core/money.js';
import type { TransferIntent } from '../transfers/types.js';

export class TransferInterpreter {
  /**
   * Interprets natural language transfer command into a structured TransferIntent.
   * If GEMINI_API_KEY is present, uses Google Gemini (gemini-2.5-flash) with strict JSON Schema.
   * Otherwise falls back gracefully to deterministic rule extraction.
   * AI NEVER executes money movement; it only extracts proposed parameters.
   */
  static async interpret(prompt: string): Promise<TransferIntent> {
    const trimmed = prompt.trim();
    const intentId = `tx_intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (env.GEMINI_API_KEY && env.GEMINI_API_KEY.trim() !== '') {
      try {
        const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
        const response = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: `Parse this natural language send money request into structured parameters: "${trimmed}"`,
          config: {
            systemInstruction: `You are FlowPay's Transfer Intent Interpreter.
Parse user money transfer requests into structured JSON.
Supported currencies: USD, NGN, MXN, CAD, EUR.
Extract:
- recipient: The beneficiary's name, email, or description (e.g. "my designer in Ghana", "bunch.dillon@example.ng", "Samson Jabo")
- amount: Decimal string representation of the numeric amount (e.g. "500.00", "50000.00")
- currency: ISO 3-letter currency code (USD, NGN, MXN, CAD, EUR)
- purpose: Optional brief description or note (e.g. "Payment for design services in Ghana")
- confidenceScore: Between 0.0 and 1.0 based on clarity
Never invent financial parameters. Never execute transactions.`,
            responseMimeType: 'application/json',
            responseJsonSchema: {
              type: Type.OBJECT,
              properties: {
                recipient: {
                  type: Type.STRING,
                  description: 'Recipient name, handle, email or description',
                },
                amount: {
                  type: Type.STRING,
                  description: 'Numeric decimal amount (e.g. "500.00")',
                },
                currency: {
                  type: Type.STRING,
                  enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'],
                  description: 'ISO currency code',
                },
                purpose: {
                  type: Type.STRING,
                  description: 'Purpose or memo for the transfer',
                },
                confidenceScore: {
                  type: Type.NUMBER,
                  description: 'Confidence between 0.0 and 1.0',
                },
              },
              required: ['recipient', 'amount', 'currency'],
            },
          },
        });

        if (response.text) {
          const parsed = JSON.parse(response.text);
          const currency: SupportedCurrency = (['USD', 'NGN', 'MXN', 'CAD', 'EUR'].includes(parsed.currency)
            ? parsed.currency
            : 'USD') as SupportedCurrency;

          let amountMinor = '0';
          let amountFormatted = '0.00';
          if (parsed.amount) {
            try {
              const money = Money.fromMajor(String(parsed.amount).replace(/,/g, ''), currency);
              amountMinor = money.amountMinor.toString();
              amountFormatted = money.toMajorString();
            } catch {
              // Ignore parse error and keep 0
            }
          }

          return {
            intentId,
            originalPrompt: trimmed,
            recipient: parsed.recipient?.trim() || 'Beneficiary',
            amount: amountFormatted,
            amountMinor,
            currency,
            purpose: parsed.purpose || `Payment to ${parsed.recipient || 'beneficiary'}`,
            confidenceScore: Math.min(1.0, Math.max(0.0, parsed.confidenceScore ?? 0.95)),
            requiresExplicitApproval: true,
            provider: 'gemini',
          };
        }
      } catch (err) {
        console.warn('[Gemini AI] Transfer parse failed, falling back to deterministic parser:', err);
      }
    }

    return this.interpretDeterministic(trimmed, intentId);
  }

  /**
   * Deterministic fallback rule-based extraction
   */
  static interpretDeterministic(prompt: string, intentId?: string): TransferIntent {
    const trimmed = prompt.trim();
    const id = intentId || `tx_intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // 1. Resolve Currency
    let currency: SupportedCurrency = 'USD';
    if (/₦|naira|ngn/i.test(trimmed)) {
      currency = 'NGN';
    } else if (/pesos?|mxn/i.test(trimmed)) {
      currency = 'MXN';
    } else if (/cad|canad/i.test(trimmed)) {
      currency = 'CAD';
    } else if (/€|euro|eur/i.test(trimmed)) {
      currency = 'EUR';
    } else if (/\$|usd|dollar/i.test(trimmed)) {
      currency = 'USD';
    }

    // 2. Resolve Amount
    // Matches $500, 500 USD, ₦50,000, 50,000 NGN, 500.00
    const amountRegex = /(?:[\$₦€]|USD\s*|NGN\s*|MXN\s*|CAD\s*|EUR\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(?:USD|NGN|MXN|CAD|EUR|dollars?|naira|pesos?)?/i;
    const amountMatch = trimmed.match(amountRegex);

    let amountMinor = '0';
    let amountFormatted = '0.00';

    if (amountMatch && amountMatch[1]) {
      try {
        const cleanNum = amountMatch[1].replace(/,/g, '');
        const money = Money.fromMajor(cleanNum, currency);
        amountMinor = money.amountMinor.toString();
        amountFormatted = money.toMajorString();
      } catch {
        amountFormatted = '0.00';
        amountMinor = '0';
      }
    }

    // 3. Resolve Recipient
    // Matches patterns like "to my designer in Ghana", "to bunch.dillon@example.ng", "to Samson Jabo", "for Chiamaka"
    let recipient = 'Beneficiary';
    let purpose: string | undefined;

    const toMatch = trimmed.match(/(?:to|for)\s+([^,.;]+?)(?:\s+(?:for|via|as|in)\s+([^,.;]+))?$/i);
    if (toMatch && toMatch[1]) {
      recipient = toMatch[1].trim();
      if (toMatch[2]) {
        purpose = toMatch[2].trim();
      }
    } else {
      const emailMatch = trimmed.match(/([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)/);
      if (emailMatch) {
        recipient = emailMatch[1].trim();
      } else {
        const addrMatch = trimmed.match(/(0x[a-fA-F0-9]{40})/);
        if (addrMatch) {
          recipient = addrMatch[1];
        }
      }
    }

    if (!purpose) {
      if (/designer in ghana/i.test(trimmed)) {
        recipient = 'my designer in Ghana';
        purpose = 'Design services';
      } else {
        purpose = `Transfer to ${recipient}`;
      }
    }

    return {
      intentId: id,
      originalPrompt: trimmed,
      recipient,
      amount: amountFormatted,
      amountMinor,
      currency,
      purpose,
      confidenceScore: recipient !== 'Beneficiary' && amountMinor !== '0' ? 0.95 : 0.7,
      requiresExplicitApproval: true,
      provider: 'deterministic-fallback',
    };
  }
}
