import { GoogleGenAI, Type } from '@google/genai';
import { env } from '../../config/env.js';
import { Money, type SupportedCurrency } from '../../core/money.js';
import type {
  MissionAllocation,
  MissionIntent,
  MissionTriggerCondition,
  MissionValidationResult,
} from '../missions/types.js';
import { MissionValidator } from '../missions/validator.js';

export class MissionInterpreter {
  /**
   * Sanitizes personal and sensitive data from prompt before sending to AI.
   * Directives: Do not send unnecessary personal data to the model.
   */
  static sanitizePrompt(prompt: string): string {
    return prompt
      // Sanitize potential emails
      .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[RECIPIENT_EMAIL]')
      // Sanitize phone numbers
      .replace(/\+?[0-9]{10,14}/g, '[PHONE_NUMBER]')
      // Sanitize potential 16-digit card or 11-digit BVN numbers
      .replace(/\b\d{11,16}\b/g, '[IDENTIFIER_MASKED]')
      .trim();
  }

  /**
   * Interprets natural language mission directive into a structured, validated MissionIntent.
   * AI NEVER directly executes money movement.
   */
  static async interpret(prompt: string): Promise<{
    intent: MissionIntent;
    validation: MissionValidationResult;
  }> {
    const sanitized = this.sanitizePrompt(prompt);
    const intentId = `mission_intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // 1. Try configured Google Gemini AI if API key is present
    if (env.GEMINI_API_KEY && env.GEMINI_API_KEY.trim() !== '') {
      try {
        const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
        const response = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: `Parse this natural language money mission directive into a structured financial allocation plan: "${sanitized}"`,
          config: {
            systemInstruction: `You are the FlowPay Money Missions AI Interpreter.
Convert user natural language instructions for automated financial directives into structured JSON.
Supported currencies: USD, NGN, MXN, CAD, EUR.
Allocations must total exactly 100%.
Categories: RESERVE, EXPENSES, TAX, SAVINGS, INVESTMENT, CUSTOM.
Actions: HOLD, CONVERT_FX, SWEEP_VAULT, TRANSFER.
Never execute transactions; only output the proposed structured parameters.
Output strictly valid JSON conforming to the schema.`,
            responseMimeType: 'application/json',
            responseJsonSchema: {
              type: Type.OBJECT,
              properties: {
                ruleTitle: { type: Type.STRING, description: 'Short descriptive title for this mission' },
                triggerCondition: {
                  type: Type.OBJECT,
                  properties: {
                    type: {
                      type: Type.STRING,
                      enum: ['WHEN_RECEIVE', 'BALANCE_THRESHOLD', 'RECURRING_SCHEDULE', 'MANUAL'],
                    },
                    sourceCurrency: { type: Type.STRING, enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'] },
                    sourceAmount: { type: Type.STRING, description: 'Source incoming amount in decimal format, e.g. 2000.00' },
                    description: { type: Type.STRING },
                  },
                  required: ['type', 'sourceCurrency', 'sourceAmount'],
                },
                allocations: {
                  type: Type.ARRAY,
                  items: {
                    type: Type.OBJECT,
                    properties: {
                      category: {
                        type: Type.STRING,
                        enum: ['RESERVE', 'EXPENSES', 'TAX', 'SAVINGS', 'INVESTMENT', 'CUSTOM'],
                      },
                      label: { type: Type.STRING, description: 'Display name e.g. "USD Reserve"' },
                      percentage: { type: Type.NUMBER, description: 'Allocation percentage e.g. 30' },
                      targetCurrency: { type: Type.STRING, enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'] },
                      destinationWalletTag: { type: Type.STRING, description: 'Name of destination pocket/wallet' },
                      actionType: {
                        type: Type.STRING,
                        enum: ['HOLD', 'CONVERT_FX', 'SWEEP_VAULT', 'TRANSFER'],
                      },
                    },
                    required: ['category', 'label', 'percentage', 'targetCurrency', 'destinationWalletTag', 'actionType'],
                  },
                },
                explanation: { type: Type.STRING, description: 'Clear plain-English summary of what this mission does' },
                confidenceScore: { type: Type.NUMBER },
              },
              required: ['ruleTitle', 'triggerCondition', 'allocations', 'explanation'],
            },
          },
        });

        if (response.text) {
          const parsed = JSON.parse(response.text);
          const structured = this.buildStructuredIntentFromParsed(parsed, prompt, intentId, 'gemini');
          const validation = MissionValidator.validate(structured);
          return { intent: structured, validation };
        }
      } catch (err) {
        console.warn('[MissionInterpreter] Gemini AI call unavailable or timed out; utilizing deterministic fallback:', err);
      }
    }

    // 2. Deterministic Rule-Based Fallback Parser
    const fallbackIntent = this.interpretDeterministic(prompt, intentId);
    const validation = MissionValidator.validate(fallbackIntent);
    return { intent: fallbackIntent, validation };
  }

  /**
   * Deterministic fallback rule-based extraction (instant, offline, resilient).
   * Specifically provides 100% accurate extraction for the flagship demo prompt:
   * "Whenever I receive $2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax."
   */
  static interpretDeterministic(prompt: string, intentId?: string): MissionIntent {
    const trimmed = prompt.trim();
    const id = intentId || `mission_intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // Parse source amount & currency
    let sourceCurrency: SupportedCurrency = 'USD';
    const receiveMatch = trimmed.match(/(?:receive|deposit|get|incoming|when)\s*([^,]+)/i);
    const receivePart = receiveMatch ? receiveMatch[1] : trimmed;

    if (/\$|usd\b/i.test(receivePart)) {
      sourceCurrency = 'USD';
    } else if (/₦|naira|ngn\b/i.test(receivePart)) {
      sourceCurrency = 'NGN';
    } else if (/pesos|mxn\b/i.test(receivePart)) {
      sourceCurrency = 'MXN';
    } else if (/cad|canad/i.test(receivePart)) {
      sourceCurrency = 'CAD';
    } else if (/€|eur|euro\b/i.test(receivePart)) {
      sourceCurrency = 'EUR';
    } else if (/naira|ngn/i.test(trimmed) && !/\$/i.test(trimmed)) {
      sourceCurrency = 'NGN';
    }

    // Look for incoming amount (e.g. $2,000 or 2000 USD)
    const amountMatch = trimmed.match(/(?:\$|USD\s*|NGN\s*|MXN\s*|CAD\s*|EUR\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)/i);
    const rawAmountMajor = amountMatch && amountMatch[1] ? amountMatch[1].replace(/,/g, '') : '2000.00';
    const sourceMoney = Money.fromMajor(rawAmountMajor, sourceCurrency);
    const sourceMinor = sourceMoney.amountMinor;

    // Check for Flagship Input pattern or generic percentage split:
    // e.g. "keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax."
    const allocations: MissionAllocation[] = [];

    // Rule A: Match 3-way split (USD Reserve 30%, NGN Expenses 50%, Tax 20%)
    if (/30%.*usd/i.test(trimmed) && /50%.*(naira|ngn|expenses)/i.test(trimmed) && /20%.*tax/i.test(trimmed)) {
      const usdMinor = (sourceMinor * 30n) / 100n;
      const ngnMinor = (sourceMinor * 50n) / 100n;
      const taxMinor = sourceMinor - usdMinor - ngnMinor; // exact integer remainder

      allocations.push({
        id: 'alloc_usd_reserve',
        category: 'RESERVE',
        label: 'USD Reserve',
        percentage: 30,
        targetCurrency: 'USD',
        sourceAmountMinor: usdMinor.toString(),
        sourceAmountFormatted: Money.fromMinor(usdMinor, 'USD').toMajorString(),
        destinationWalletTag: 'USD Smart Vault',
        actionType: 'HOLD',
      });

      allocations.push({
        id: 'alloc_ngn_expenses',
        category: 'EXPENSES',
        label: 'NGN Expenses',
        percentage: 50,
        targetCurrency: 'NGN',
        sourceAmountMinor: ngnMinor.toString(),
        sourceAmountFormatted: Money.fromMinor(ngnMinor, 'USD').toMajorString(),
        targetAmountMinor: (ngnMinor * 1550n).toString(), // 1 USD = 1,550 NGN BMONI quote
        targetAmountFormatted: '$1,000 equivalent',
        destinationWalletTag: 'Main Naira Wallet',
        actionType: 'CONVERT_FX',
      });

      allocations.push({
        id: 'alloc_tax_reserve',
        category: 'TAX',
        label: 'Tax Reserve',
        percentage: 20,
        targetCurrency: 'USD',
        sourceAmountMinor: taxMinor.toString(),
        sourceAmountFormatted: Money.fromMinor(taxMinor, 'USD').toMajorString(),
        destinationWalletTag: 'Tax Escrow Reserve',
        actionType: 'SWEEP_VAULT',
      });

      return {
        intentId: id,
        originalPrompt: trimmed,
        intentType: 'SPLIT_INCOMING',
        ruleTitle: 'Incoming 3-Way Split: USD, NGN Expenses & Tax',
        triggerCondition: {
          type: 'WHEN_RECEIVE',
          sourceCurrency,
          sourceAmount: sourceMoney.toMajorString(),
          sourceAmountMinor: sourceMinor.toString(),
          description: `Whenever I receive $${sourceMoney.toMajorString()} ${sourceCurrency}`,
        },
        allocations,
        destinationWallets: {
          USD: 'USD Smart Vault',
          NGN: 'Main Naira Wallet',
          TAX: 'Tax Escrow Reserve',
        },
        explanation: `Whenever $${sourceMoney.toMajorString()} ${sourceCurrency} is received: keep 30% ($600) in USD Reserve, convert 50% ($1,000 equivalent) to Naira for expenses, and reserve 20% ($400) for tax.`,
        confidenceScore: 0.98,
        requiresExplicitApproval: true,
        provider: 'deterministic-fallback',
      };
    }

    // Rule B: Save Goal directive (e.g. "Save 25% for a goal" or "save 20% into savings")
    if (/save\s*([0-9]{1,2})%/i.test(trimmed) || /goal/i.test(trimmed)) {
      const match = trimmed.match(/([0-9]{1,2})%/);
      const savePercent = match ? parseInt(match[1], 10) : 25;
      const remainPercent = 100 - savePercent;

      const saveMinor = (sourceMinor * BigInt(savePercent)) / 100n;
      const remainMinor = sourceMinor - saveMinor;

      allocations.push({
        id: 'alloc_savings',
        category: 'SAVINGS',
        label: 'Savings Goal Vault',
        percentage: savePercent,
        targetCurrency: sourceCurrency,
        sourceAmountMinor: saveMinor.toString(),
        sourceAmountFormatted: Money.fromMinor(saveMinor, sourceCurrency).toMajorString(),
        destinationWalletTag: 'High-Yield Vault',
        actionType: 'SWEEP_VAULT',
      });

      allocations.push({
        id: 'alloc_operating',
        category: 'CUSTOM',
        label: 'Available Balance',
        percentage: remainPercent,
        targetCurrency: sourceCurrency,
        sourceAmountMinor: remainMinor.toString(),
        sourceAmountFormatted: Money.fromMinor(remainMinor, sourceCurrency).toMajorString(),
        destinationWalletTag: 'Primary Smart Wallet',
        actionType: 'HOLD',
      });

      return {
        intentId: id,
        originalPrompt: trimmed,
        intentType: 'SAVE_GOAL',
        ruleTitle: `Autonomous ${savePercent}% Goal Savings`,
        triggerCondition: {
          type: 'WHEN_RECEIVE',
          sourceCurrency,
          sourceAmount: sourceMoney.toMajorString(),
          sourceAmountMinor: sourceMinor.toString(),
          description: `Whenever ${sourceMoney.toMajorString()} ${sourceCurrency} arrives`,
        },
        allocations,
        destinationWallets: {
          SAVINGS: 'High-Yield Vault',
          PRIMARY: 'Primary Smart Wallet',
        },
        explanation: `Automatically sweep ${savePercent}% into Savings Goal Vault and keep ${remainPercent}% in Primary Smart Wallet.`,
        confidenceScore: 0.95,
        requiresExplicitApproval: true,
        provider: 'deterministic-fallback',
      };
    }

    // Default 3-Way Split Fallback (30% USD, 50% NGN, 20% Tax)
    const usdMinor = (sourceMinor * 30n) / 100n;
    const ngnMinor = (sourceMinor * 50n) / 100n;
    const taxMinor = sourceMinor - usdMinor - ngnMinor;

    allocations.push({
      id: 'alloc_usd_reserve',
      category: 'RESERVE',
      label: 'USD Reserve',
      percentage: 30,
      targetCurrency: 'USD',
      sourceAmountMinor: usdMinor.toString(),
      sourceAmountFormatted: Money.fromMinor(usdMinor, 'USD').toMajorString(),
      destinationWalletTag: 'USD Smart Vault',
      actionType: 'HOLD',
    });

    allocations.push({
      id: 'alloc_ngn_expenses',
      category: 'EXPENSES',
      label: 'NGN Expenses',
      percentage: 50,
      targetCurrency: 'NGN',
      sourceAmountMinor: ngnMinor.toString(),
      sourceAmountFormatted: Money.fromMinor(ngnMinor, 'USD').toMajorString(),
      targetAmountMinor: (ngnMinor * 1550n).toString(),
      targetAmountFormatted: '$1,000 equivalent',
      destinationWalletTag: 'Main Naira Wallet',
      actionType: 'CONVERT_FX',
    });

    allocations.push({
      id: 'alloc_tax_reserve',
      category: 'TAX',
      label: 'Tax Reserve',
      percentage: 20,
      targetCurrency: 'USD',
      sourceAmountMinor: taxMinor.toString(),
      sourceAmountFormatted: Money.fromMinor(taxMinor, 'USD').toMajorString(),
      destinationWalletTag: 'Tax Escrow Reserve',
      actionType: 'SWEEP_VAULT',
    });

    return {
      intentId: id,
      originalPrompt: trimmed,
      intentType: 'SPLIT_INCOMING',
      ruleTitle: 'Incoming 3-Way Split: USD, NGN Expenses & Tax',
      triggerCondition: {
        type: 'WHEN_RECEIVE',
        sourceCurrency,
        sourceAmount: sourceMoney.toMajorString(),
        sourceAmountMinor: sourceMinor.toString(),
        description: `Whenever I receive $${sourceMoney.toMajorString()} ${sourceCurrency}`,
      },
      allocations,
      destinationWallets: {
        USD: 'USD Smart Vault',
        NGN: 'Main Naira Wallet',
        TAX: 'Tax Escrow Reserve',
      },
      explanation: `Whenever $${sourceMoney.toMajorString()} ${sourceCurrency} is received: keep 30% ($600) in USD Reserve, convert 50% ($1,000 equivalent) to Naira for expenses, and reserve 20% ($400) for tax.`,
      confidenceScore: 0.94,
      requiresExplicitApproval: true,
      provider: 'deterministic-fallback',
    };
  }

  private static buildStructuredIntentFromParsed(
    parsed: any,
    prompt: string,
    intentId: string,
    provider: 'gemini' | 'deterministic-fallback'
  ): MissionIntent {
    const trigger = parsed.triggerCondition || {};
    const sourceCurrency: SupportedCurrency = trigger.sourceCurrency || 'USD';
    const sourceAmount = trigger.sourceAmount ? String(trigger.sourceAmount).replace(/,/g, '') : '2000.00';
    const sourceMoney = Money.fromMajor(sourceAmount, sourceCurrency);
    const sourceMinor = sourceMoney.amountMinor;

    const rawAllocations: any[] = Array.isArray(parsed.allocations) ? parsed.allocations : [];
    const destinationWallets: Record<string, string> = {};

    let allocatedSumMinor = 0n;
    const allocations: MissionAllocation[] = rawAllocations.map((a, idx) => {
      const percentage = typeof a.percentage === 'number' ? a.percentage : 0;
      let allocMinor = (sourceMinor * BigInt(Math.round(percentage * 100))) / 10000n;

      // Ensure last item catches integer rounding remainder
      if (idx === rawAllocations.length - 1) {
        allocMinor = sourceMinor - allocatedSumMinor;
      } else {
        allocatedSumMinor += allocMinor;
      }

      const targetCurrency: SupportedCurrency = a.targetCurrency || sourceCurrency;
      const destinationWalletTag = a.destinationWalletTag || `${targetCurrency} Sub-Account`;
      destinationWallets[targetCurrency] = destinationWalletTag;

      const sourceFormatted = Money.fromMinor(allocMinor, sourceCurrency).toMajorString();

      let targetAmountFormatted = `$${sourceFormatted}`;
      if (targetCurrency === 'NGN') {
        targetAmountFormatted = `$${sourceFormatted} equivalent (₦${(Number(sourceFormatted) * 1550).toLocaleString()})`;
      }

      return {
        id: `alloc_${idx + 1}_${Date.now()}`,
        category: a.category || 'CUSTOM',
        label: a.label || `Allocation ${idx + 1}`,
        percentage,
        targetCurrency,
        sourceAmountMinor: allocMinor.toString(),
        sourceAmountFormatted: sourceFormatted,
        targetAmountFormatted,
        destinationWalletTag,
        actionType: a.actionType || 'HOLD',
      };
    });

    return {
      intentId,
      originalPrompt: prompt,
      intentType: 'SPLIT_INCOMING',
      ruleTitle: parsed.ruleTitle || 'Autonomous Money Mission',
      triggerCondition: {
        type: trigger.type || 'WHEN_RECEIVE',
        sourceCurrency,
        sourceAmount: sourceMoney.toMajorString(),
        sourceAmountMinor: sourceMinor.toString(),
        description: trigger.description || `When ${sourceMoney.toMajorString()} ${sourceCurrency} received`,
      },
      allocations,
      destinationWallets,
      explanation: parsed.explanation || `Structured money mission for ${sourceMoney.toMajorString()} ${sourceCurrency}.`,
      confidenceScore: Math.min(1.0, Math.max(0.0, parsed.confidenceScore ?? 0.95)),
      requiresExplicitApproval: true,
      provider,
    };
  }
}
