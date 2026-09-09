import { GoogleGenAI, Type } from '@google/genai';
import { env } from '../../config/env.js';
import { Money, type SupportedCurrency } from '../../core/money.js';
import {
  type FinancialIntent,
  type FinancialAction,
  type SendMoneyAction,
  type ConvertCurrencyAction,
  type CreateReserveAction,
  type AllocateMoneyAction,
  type CompletenessReport,
} from './types.js';

export { type FinancialIntent, type StructuredFinancialIntent, type FinancialAction } from './types.js';

export class FinancialIntentInterpreter {
  /**
   * Interprets natural language prompt into a structured multi-action FinancialIntent.
   * Scans the entire user message and extracts ALL actionable instructions.
   * If GEMINI_API_KEY is configured, queries Gemini with strict JSON Schema output.
   * If not configured or if the LLM call fails, falls back to the deterministic multi-action parser.
   * AI NEVER executes money movement; it only produces structured parameters.
   */
  static async interpret(prompt: string): Promise<FinancialIntent> {
    const trimmed = prompt.trim();
    const intentId = `intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (env.GEMINI_API_KEY && env.GEMINI_API_KEY.trim() !== '') {
      try {
        const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
        const response = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: `Parse this natural language financial request into ALL structured financial actions: "${trimmed}"`,
          config: {
            systemInstruction: `You are the FlowPay Multi-Action Financial AI Interpreter.
CRITICAL RULES:
1. NEVER assume that one user message contains only one financial action.
2. NEVER stop after extracting the first financial action.
3. NEVER deduplicate actions merely because their type is identical.
4. Scan the ENTIRE user message and identify EVERY actionable financial instruction.
5. Create one structured action per instruction, preserving ordering, amounts, currencies, recipients, and dependencies.
6. FlowPay supports currencies: USD, NGN, MXN, CAD, EUR.
7. Return an object with an "actions" array matching the schema.`,
            responseMimeType: 'application/json',
            responseJsonSchema: {
              type: Type.OBJECT,
              properties: {
                actions: {
                  type: Type.ARRAY,
                  items: {
                    type: Type.OBJECT,
                    properties: {
                      id: { type: Type.STRING },
                      type: {
                        type: Type.STRING,
                        enum: [
                          'SEND_MONEY',
                          'CONVERT_CURRENCY',
                          'ALLOCATE_MONEY',
                          'CREATE_RESERVE',
                          'UPDATE_RESERVE',
                          'CREATE_MISSION',
                          'UPDATE_MISSION',
                          'CHECK_BALANCE',
                          'CHECK_SPENDING',
                          'CHECK_INCOME',
                          'VIEW_TRANSACTIONS',
                          'PAY_BENEFICIARY',
                        ],
                      },
                      recipient: { type: Type.STRING },
                      amount: { type: Type.STRING },
                      currency: {
                        type: Type.STRING,
                        enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'],
                      },
                      sourceCurrency: {
                        type: Type.STRING,
                        enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'],
                      },
                      destinationCurrency: {
                        type: Type.STRING,
                        enum: ['USD', 'NGN', 'MXN', 'CAD', 'EUR'],
                      },
                      purpose: { type: Type.STRING },
                      sourceWallet: { type: Type.STRING },
                      description: { type: Type.STRING },
                      dependsOn: {
                        type: Type.ARRAY,
                        items: { type: Type.STRING },
                      },
                    },
                    required: ['type', 'description'],
                  },
                },
                explanation: { type: Type.STRING },
                confidenceScore: { type: Type.NUMBER },
              },
              required: ['actions', 'explanation'],
            },
          },
        });

        if (response.text) {
          const parsed = JSON.parse(response.text);
          if (Array.isArray(parsed.actions) && parsed.actions.length > 0) {
            const rawActions: FinancialAction[] = parsed.actions.map((act: any, idx: number) => {
              const actId = act.id || `act_${intentId}_${idx + 1}`;
              const currency: SupportedCurrency = this.normalizeCurrency(act.currency || act.sourceCurrency);
              const amountStr = String(act.amount || '0').replace(/,/g, '');
              let amountMinor = '0';
              let amountFormatted = '0.00';
              try {
                const m = Money.fromMajor(amountStr, currency);
                amountMinor = m.amountMinor.toString();
                amountFormatted = m.toMajorString();
              } catch {
                // keep defaults
              }

              if (act.type === 'CONVERT_CURRENCY') {
                const srcCurr = this.normalizeCurrency(act.sourceCurrency || currency);
                const dstCurr = this.normalizeCurrency(act.destinationCurrency || 'USD');
                return {
                  id: actId,
                  type: 'CONVERT_CURRENCY',
                  amount: amountFormatted,
                  amountMinor,
                  sourceCurrency: srcCurr,
                  destinationCurrency: dstCurr,
                  description: act.description || `Convert ${amountFormatted} ${srcCurr} to ${dstCurr}`,
                  dependsOn: act.dependsOn,
                } as ConvertCurrencyAction;
              }

              if (act.type === 'CREATE_RESERVE' || act.type === 'UPDATE_RESERVE') {
                return {
                  id: actId,
                  type: act.type,
                  amount: amountFormatted,
                  amountMinor,
                  currency,
                  purpose: act.purpose || 'reserve',
                  description: act.description || `Reserve ${amountFormatted} ${currency} for ${act.purpose || 'reserve'}`,
                  dependsOn: act.dependsOn,
                } as CreateReserveAction;
              }

              // Default to SEND_MONEY
              const rec = this.capitalize(act.recipient || 'unspecified recipient');
              return {
                id: actId,
                type: 'SEND_MONEY',
                amount: amountFormatted,
                amountMinor,
                currency,
                recipient: rec,
                sourceWallet: act.sourceWallet,
                description: act.description || `Send ${amountFormatted} ${currency} to ${rec}`,
                dependsOn: act.dependsOn,
              } as SendMoneyAction;
            });

            // Completeness check
            const completeness = this.validateCompleteness(trimmed, rawActions);

            // If incomplete, run deterministic repair
            const finalActions = completeness.isReparseSuggested
              ? this.repairExtractedActions(trimmed, rawActions, intentId)
              : rawActions;

            const primaryAction = finalActions[0];
            const primarySend = finalActions.find((a) => a.type === 'SEND_MONEY') as SendMoneyAction | undefined;

            return {
              intentId,
              originalPrompt: trimmed,
              actions: finalActions,
              requiresClarification: false,
              clarificationQuestions: [],
              completeness: this.validateCompleteness(trimmed, finalActions),
              explanation: parsed.explanation || `Interpreted ${finalActions.length} financial action(s).`,
              confidenceScore: Math.min(1.0, Math.max(0.0, parsed.confidenceScore ?? 0.95)),
              requiresExplicitApproval: true,
              provider: 'gemini',
              // Backwards compatibility
              operationType: primaryAction.type === 'SEND_MONEY' ? 'TRANSFER' : primaryAction.type,
              parameters: primarySend
                ? {
                    recipientIdentifier: primarySend.recipient,
                    sourceCurrency: primarySend.currency,
                    amountMinor: primarySend.amountMinor,
                    amountFormatted: primarySend.amount,
                    description: primarySend.description,
                  }
                : undefined,
            };
          }
        }
      } catch (err) {
        console.warn('[Gemini AI] Call failed, falling back to deterministic extraction:', err);
      }
    }

    return this.interpretDeterministic(trimmed, intentId);
  }

  /**
   * Deterministic multi-action parser (instant, offline, zero API-key requirement).
   * Identifies all actionable instructions, parses natural language conjunctions,
   * handles word numbers, preserves repeated types, mixed intents, and dependencies.
   */
  static interpretDeterministic(prompt: string, intentId?: string): FinancialIntent {
    const trimmed = prompt.trim();
    const id = intentId || `intent_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // Rule: Multi-country / aggregate payroll command
    if (/payroll|pay (all|team|employees)/i.test(trimmed)) {
      return {
        intentId: id,
        originalPrompt: trimmed,
        actions: [
          {
            id: `act_${id}_1`,
            type: 'SEND_MONEY',
            amount: '0.00',
            amountMinor: '0',
            currency: 'USD',
            recipient: 'All Employees',
            description: 'Multi-country payroll disbursement',
          },
        ],
        requiresClarification: false,
        clarificationQuestions: [],
        completeness: {
          score: 1.0,
          detectedActionCount: 1,
          unresolvedActionCount: 0,
          isReparseSuggested: false,
        },
        explanation: 'Run payroll for all linked employees in their local currencies with aggregate USD settlement.',
        confidenceScore: 0.95,
        requiresExplicitApproval: true,
        provider: 'deterministic-fallback',
        operationType: 'PAYROLL_RUN',
        parameters: {
          sourceCurrency: 'USD',
          description: 'Multi-country payroll disbursement',
        },
      };
    }

    // Replace word numbers before clause splitting
    const normalizedText = this.normalizeWordNumbers(trimmed);

    // Extract sentence-level constraints (e.g. "from my USD wallet")
    let sharedSourceWallet: string | undefined;
    const walletMatch = normalizedText.match(/from (?:my\s+)?([A-Za-z0-9]+)\s+wallet/i);
    if (walletMatch) {
      sharedSourceWallet = `${walletMatch[1].toUpperCase()} Wallet`;
    }

    // Split into candidate clauses
    const clauses = this.splitIntoSemanticClauses(normalizedText);
    const extractedActions: FinancialAction[] = [];

    for (let i = 0; i < clauses.length; i++) {
      const clause = clauses[i].trim();
      if (!clause) continue;

      const act = this.parseSingleClause(clause, `act_${id}_${extractedActions.length + 1}`, sharedSourceWallet);
      if (act) {
        extractedActions.push(act);
      }
    }

    // If no actions extracted, try single-clause fallback
    if (extractedActions.length === 0) {
      const single = this.parseSingleClause(normalizedText, `act_${id}_1`, sharedSourceWallet);
      if (single) {
        extractedActions.push(single);
      }
    }

    // Run completeness check
    const completeness = this.validateCompleteness(normalizedText, extractedActions);

    // Repair if any actions were missed
    const finalActions = completeness.isReparseSuggested
      ? this.repairExtractedActions(normalizedText, extractedActions, id, sharedSourceWallet)
      : extractedActions;

    // Detect dependencies (e.g. "convert 1000 eur to usd and use it to send 500 to mom")
    if (finalActions.length >= 2) {
      const isDependency = /use it to|and use it to|then use it to/i.test(normalizedText);
      if (isDependency) {
        const convertAct = finalActions.find((a) => a.type === 'CONVERT_CURRENCY');
        const sendAct = finalActions.find((a) => a.type === 'SEND_MONEY');
        if (convertAct && sendAct) {
          sendAct.dependsOn = [convertAct.id];
        }
      }
    }

    const primaryAction = finalActions[0];
    const primarySend = finalActions.find((a) => a.type === 'SEND_MONEY') as SendMoneyAction | undefined;

    return {
      intentId: id,
      originalPrompt: trimmed,
      actions: finalActions,
      requiresClarification: false,
      clarificationQuestions: [],
      completeness: this.validateCompleteness(normalizedText, finalActions),
      explanation: this.generateExplanation(finalActions),
      confidenceScore: finalActions.length > 0 ? 0.95 : 0.4,
      requiresExplicitApproval: true,
      provider: 'deterministic-fallback',
      operationType: primaryAction?.type === 'SEND_MONEY' ? 'TRANSFER' : primaryAction?.type || 'TRANSFER',
      parameters: primarySend
        ? {
            recipientIdentifier: primarySend.recipient,
            sourceCurrency: primarySend.currency,
            amountMinor: primarySend.amountMinor,
            amountFormatted: primarySend.amount,
            description: primarySend.description,
          }
        : {
            sourceCurrency: 'USD',
            amountMinor: '0',
            amountFormatted: '0.00',
            description: 'FlowPay Intent',
          },
    };
  }

  /**
   * Splits input into semantic action clauses based on conjunctions and punctuation.
   */
  private static splitIntoSemanticClauses(text: string): string[] {
    // Strip trailing constraint like "from my USD wallet" so it doesn't break clause splits
    let cleaned = text.replace(/,?\s*(?:from|using) (?:my\s+)?[A-Za-z0-9]+\s+wallet/i, '');

    // Split on delimiters: comma, semicolon, period, and, also, then, plus, as well as, &
    const regex = /(?<!\d),(?!\d)|;\s*|\.\s+|\s+(?:and\s+then|then|as\s+well\s+as|and|also|plus|&)\s+/i;
    return cleaned.split(regex).map((s) => s.trim()).filter((s) => s.length > 0);
  }

  /**
   * Parses an individual clause into a FinancialAction.
   */
  private static parseSingleClause(clause: string, actionId: string, sourceWallet?: string): FinancialAction | null {
    const lower = clause.toLowerCase();

    // 1. Conversion clause (e.g. "convert 100 eur to usd", "convert €1,000 to dollars")
    if (lower.includes('convert') || lower.includes('swap')) {
      const convMatch = clause.match(
        /(?:convert|swap)\s+(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|euros?|dollars?|naira|pesos?)?\s+(?:to|into)\s*(usd|ngn|eur|mxn|cad|euros?|dollars?|naira|pesos?)/i
      );
      if (convMatch) {
        const rawAmt = convMatch[1].replace(/,/g, '');
        const srcCurr = this.normalizeCurrency(convMatch[2] || (clause.includes('€') ? 'EUR' : 'USD'));
        const dstCurr = this.normalizeCurrency(convMatch[3] || 'USD');
        const money = Money.fromMajor(rawAmt, srcCurr);
        return {
          id: actionId,
          type: 'CONVERT_CURRENCY',
          amount: money.toMajorString(),
          amountMinor: money.amountMinor.toString(),
          sourceCurrency: srcCurr,
          destinationCurrency: dstCurr,
          description: `Convert ${money.toMajorString()} ${srcCurr} to ${dstCurr}`,
        };
      }
    }

    // 2. Reserve clause (e.g. "keep $300 for tax", "reserve $300 for tax", "keep 300 for taxes")
    if (lower.includes('keep') || lower.includes('reserve') || lower.includes('aside') || lower.includes('tax')) {
      const resMatch = clause.match(
        /(?:keep|reserve|save|set aside)?\s*(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?\s*(?:for|as)?\s*(tax(?:es)?|emergency|savings|reserve)/i
      );
      if (resMatch) {
        const rawAmt = resMatch[1].replace(/,/g, '');
        const curr = this.normalizeCurrency(resMatch[2] || this.detectCurrency(clause));
        const purpose = resMatch[3].toLowerCase().startsWith('tax') ? 'tax' : resMatch[3].toLowerCase();
        const money = Money.fromMajor(rawAmt, curr);
        return {
          id: actionId,
          type: 'CREATE_RESERVE',
          amount: money.toMajorString(),
          amountMinor: money.amountMinor.toString(),
          currency: curr,
          purpose,
          description: `Reserve ${money.toMajorString()} ${curr} for ${purpose}`,
        };
      }
    }

    // 3. Send / Pay / Transfer clause or implicit clause
    // e.g. "send 20 usd to mom", "30 usd to dad", "$50 to my brother", "pay my designer $2,000", "Mom gets $20", "Give Mom 20 dollars"
    const send = this.parseSendAction(clause, actionId, sourceWallet);
    if (send) return send;

    return null;
  }

  /**
   * Parses send money actions including implicit verb clauses.
   */
  private static parseSendAction(clause: string, actionId: string, sourceWallet?: string): SendMoneyAction | null {
    // Pattern 1: "Mom gets $20" or "Dad receives $30"
    const getsMatch = clause.match(
      /^([A-Za-z0-9._%+-]+(?:\s+[A-Za-z0-9]+)?)\s+(?:gets|receives|takes)\s+(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?/i
    );
    if (getsMatch) {
      const recipient = getsMatch[1].trim();
      const rawAmt = getsMatch[2].replace(/,/g, '');
      const curr = this.normalizeCurrency(getsMatch[3] || this.detectCurrency(clause));
      const money = Money.fromMajor(rawAmt, curr);
      return {
        id: actionId,
        type: 'SEND_MONEY',
        amount: money.toMajorString(),
        amountMinor: money.amountMinor.toString(),
        currency: curr,
        recipient,
        sourceWallet,
        description: `Send ${money.toMajorString()} ${curr} to ${recipient}`,
      };
    }

    // Pattern 2: "Give Mom 20 dollars" or "Pay Dad 30"
    const giveMatch = clause.match(
      /^(?:give|pay)\s+([A-Za-z0-9._%+-]+(?:\s+[A-Za-z0-9]+)?)\s+(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?/i
    );
    if (giveMatch) {
      const recipient = giveMatch[1].trim();
      const rawAmt = giveMatch[2].replace(/,/g, '');
      const curr = this.normalizeCurrency(giveMatch[3] || this.detectCurrency(clause));
      const money = Money.fromMajor(rawAmt, curr);
      return {
        id: actionId,
        type: 'SEND_MONEY',
        amount: money.toMajorString(),
        amountMinor: money.amountMinor.toString(),
        currency: curr,
        recipient,
        sourceWallet,
        description: `Send ${money.toMajorString()} ${curr} to ${recipient}`,
      };
    }

    // Pattern 2b: "Dad 30" or "Dad $30" or "Dad 30 dollars" (implicit conjunction clause)
    const implicitRecipientMatch = clause.match(
      /^([A-Za-z0-9._%+-]+(?:\s+[A-Za-z0-9]+)?)\s+(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?\.?$/i
    );
    if (implicitRecipientMatch) {
      const recipient = implicitRecipientMatch[1].trim();
      const rawAmt = implicitRecipientMatch[2].replace(/,/g, '');
      const curr = this.normalizeCurrency(implicitRecipientMatch[3] || this.detectCurrency(clause));
      const money = Money.fromMajor(rawAmt, curr);
      return {
        id: actionId,
        type: 'SEND_MONEY',
        amount: money.toMajorString(),
        amountMinor: money.amountMinor.toString(),
        currency: curr,
        recipient,
        sourceWallet,
        description: `Send ${money.toMajorString()} ${curr} to ${recipient}`,
      };
    }

    // Pattern 3: Standard "[send/pay/wire] [amt] [curr] to [recipient]" or implicit "[amt] [curr] to [recipient]"
    const standardMatch = clause.match(
      /(?:send|pay|wire|transfer)?\s*(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?\s+(?:to|for)\s+(?:my\s+|our\s+)?(0x[a-fA-F0-9]{40}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)?)/i
    );
    if (standardMatch) {
      const rawAmt = standardMatch[1].replace(/,/g, '');
      const curr = this.normalizeCurrency(standardMatch[2] || this.detectCurrency(clause));
      let recipient = standardMatch[3].trim();
      recipient = recipient.replace(/^(?:my\s+|our\s+)/i, '').trim();

      // Avoid capturing keywords
      if (!['tax', 'taxes', 'reserve', 'savings', 'wallet'].includes(recipient.toLowerCase())) {
        const money = Money.fromMajor(rawAmt, curr);
        return {
          id: actionId,
          type: 'SEND_MONEY',
          amount: money.toMajorString(),
          amountMinor: money.amountMinor.toString(),
          currency: curr,
          recipient: this.capitalize(recipient),
          sourceWallet,
          description: `Send ${money.toMajorString()} ${curr} to ${this.capitalize(recipient)}`,
        };
      }
    }

    // Pattern 4: "pay [recipient] [amt]" (e.g. "pay designer $2,000")
    const payMatch = clause.match(
      /(?:pay|send)\s+(?:my\s+|our\s+)?([A-Za-z0-9]+(?:\s+[A-Za-z0-9]+)?)\s+(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?/i
    );
    if (payMatch) {
      const recipient = payMatch[1].trim();
      const rawAmt = payMatch[2].replace(/,/g, '');
      const curr = this.normalizeCurrency(payMatch[3] || this.detectCurrency(clause));
      if (!['tax', 'taxes', 'reserve', 'savings', 'wallet'].includes(recipient.toLowerCase())) {
        const money = Money.fromMajor(rawAmt, curr);
        return {
          id: actionId,
          type: 'SEND_MONEY',
          amount: money.toMajorString(),
          amountMinor: money.amountMinor.toString(),
          currency: curr,
          recipient: this.capitalize(recipient),
          sourceWallet,
          description: `Send ${money.toMajorString()} ${curr} to ${this.capitalize(recipient)}`,
        };
      }
    }

    return null;
  }

  /**
   * Deterministic Completeness Checker:
   * Counts signals (monetary amounts, recipients, verbs) in the raw message
   * to determine if all intended actions were extracted.
   */
  static validateCompleteness(text: string, actions: FinancialAction[]): CompletenessReport {
    // Detect all monetary amounts e.g. "$20", "30 usd", "2000 usd", "100 eur", "300 for tax", "20 to mom"
    const amountMatches =
      text.match(
        /(?:[\$₦€£]\s*[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|\b[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?(?:\s*(?:usd|ngn|eur|mxn|cad|dollars?|naira|pesos?|euros?))?)/gi
      ) || [];

    // Detect all targets: "to <recipient>", "keep <amt> for <target>", "convert <amt> <curr> to <curr>"
    const targetMatches = text.match(/(?:to|for)\s+(?:my\s+)?[A-Za-z0-9._%+-]+/gi) || [];

    const detectedCount = Math.max(1, amountMatches.length);
    const extractedCount = actions.length;

    const isReparseSuggested = extractedCount < detectedCount;
    const score = isReparseSuggested
      ? Math.min(0.9, extractedCount / detectedCount)
      : 1.0;

    return {
      score,
      detectedActionCount: detectedCount,
      unresolvedActionCount: Math.max(0, detectedCount - extractedCount),
      isReparseSuggested,
    };
  }

  /**
   * Reparses/repairs missing actions when the completeness check signals missing actions.
   */
  private static repairExtractedActions(
    text: string,
    existing: FinancialAction[],
    intentId: string,
    sourceWallet?: string
  ): FinancialAction[] {
    // Find all amount-recipient pairs in the text that weren't captured
    const pairRegex = /(?:[\$₦€£])?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(usd|ngn|eur|mxn|cad|dollars?|naira|pesos?)?\s+(?:to|for)\s+(?:my\s+)?([A-Za-z0-9._%+-]+)/gi;
    const repaired: FinancialAction[] = [...existing];
    let match: RegExpExecArray | null;

    while ((match = pairRegex.exec(text)) !== null) {
      const rawAmt = match[1].replace(/,/g, '');
      const curr = this.normalizeCurrency(match[2] || 'USD');
      const target = match[3].trim();

      const alreadyExists = repaired.some(
        (a) =>
          'amount' in a &&
          (a as any).amount === Money.fromMajor(rawAmt, curr).toMajorString() &&
          ((a.type === 'SEND_MONEY' && (a as SendMoneyAction).recipient.toLowerCase() === target.toLowerCase()) ||
            (a.type === 'CREATE_RESERVE' && (a as CreateReserveAction).purpose.toLowerCase() === target.toLowerCase()))
      );

      if (!alreadyExists) {
        const money = Money.fromMajor(rawAmt, curr);
        const actId = `act_${intentId}_${repaired.length + 1}`;
        if (target.toLowerCase() === 'tax' || target.toLowerCase() === 'taxes') {
          repaired.push({
            id: actId,
            type: 'CREATE_RESERVE',
            amount: money.toMajorString(),
            amountMinor: money.amountMinor.toString(),
            currency: curr,
            purpose: 'tax',
            description: `Reserve ${money.toMajorString()} ${curr} for tax`,
          });
        } else {
          repaired.push({
            id: actId,
            type: 'SEND_MONEY',
            amount: money.toMajorString(),
            amountMinor: money.amountMinor.toString(),
            currency: curr,
            recipient: this.capitalize(target),
            sourceWallet,
            description: `Send ${money.toMajorString()} ${curr} to ${this.capitalize(target)}`,
          });
        }
      }
    }

    return repaired;
  }

  /**
   * Normalizes word numbers like "twenty" -> "20", "thirty" -> "30", etc.
   */
  private static normalizeWordNumbers(text: string): string {
    const wordToNumber: Record<string, string> = {
      zero: '0',
      one: '1',
      two: '2',
      three: '3',
      four: '4',
      five: '5',
      six: '6',
      seven: '7',
      eight: '8',
      nine: '9',
      ten: '10',
      twenty: '20',
      thirty: '30',
      forty: '40',
      fifty: '50',
      sixty: '60',
      seventy: '70',
      eighty: '80',
      ninety: '90',
      hundred: '100',
      thousand: '1000',
    };

    let result = text;
    for (const [word, num] of Object.entries(wordToNumber)) {
      result = result.replace(new RegExp(`\\b${word}\\b`, 'gi'), num);
    }
    return result;
  }

  private static detectCurrency(text: string): SupportedCurrency {
    const lower = text.toLowerCase();
    if (lower.includes('₦') || lower.includes('ngn') || lower.includes('naira')) return 'NGN';
    if (lower.includes('€') || lower.includes('eur') || lower.includes('euro')) return 'EUR';
    if (lower.includes('mxn') || lower.includes('peso')) return 'MXN';
    if (lower.includes('cad')) return 'CAD';
    return 'USD';
  }

  private static normalizeCurrency(curr?: string): SupportedCurrency {
    if (!curr) return 'USD';
    const c = curr.toUpperCase();
    if (c.includes('NGN') || c.includes('NAIRA')) return 'NGN';
    if (c.includes('EUR') || c.includes('EURO')) return 'EUR';
    if (c.includes('MXN') || c.includes('PESO')) return 'MXN';
    if (c.includes('CAD')) return 'CAD';
    return 'USD';
  }

  private static capitalize(str: string): string {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  private static generateExplanation(actions: FinancialAction[]): string {
    if (actions.length === 0) return 'No financial actions found in request.';
    if (actions.length === 1) return actions[0].description;
    const summaries = actions.map((a, i) => `${i + 1}. ${a.description}`).join('; ');
    return `Plan containing ${actions.length} actions: ${summaries}.`;
  }
}
