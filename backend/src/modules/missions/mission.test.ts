import test, { describe, it } from 'node:test';
import assert from 'node:assert';
import { MissionInterpreter } from '../ai/mission_interpreter.js';
import { MissionValidator } from './validator.js';
import { MoneyMissionService } from './service.js';
import type { MissionIntent } from './types.js';

describe('Money Missions Flagship Feature Tests', () => {
  const flagshipPrompt =
    'Whenever I receive $2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax.';

  it('interprets the flagship natural language instruction into structured intent', async () => {
    const { intent, validation } = await MissionInterpreter.interpret(flagshipPrompt);

    // Verify AI output is structured and validated
    assert.strictEqual(validation.valid, true);
    assert.strictEqual(intent.intentType, 'SPLIT_INCOMING');
    assert.strictEqual(intent.triggerCondition.sourceCurrency, 'USD');
    assert.strictEqual(intent.triggerCondition.sourceAmountMinor, '200000'); // $2,000.00 in cents

    // Verify allocations: 3 items (USD 30%, NGN 50%, Tax 20%)
    assert.strictEqual(intent.allocations.length, 3);

    const usdReserve = intent.allocations.find((a) => a.category === 'RESERVE');
    assert.ok(usdReserve, 'USD Reserve allocation must exist');
    assert.strictEqual(usdReserve.percentage, 30);
    assert.strictEqual(usdReserve.sourceAmountMinor, '60000'); // $600.00
    assert.strictEqual(usdReserve.targetCurrency, 'USD');
    assert.strictEqual(usdReserve.actionType, 'HOLD');

    const ngnExpenses = intent.allocations.find((a) => a.category === 'EXPENSES');
    assert.ok(ngnExpenses, 'NGN Expenses allocation must exist');
    assert.strictEqual(ngnExpenses.percentage, 50);
    assert.strictEqual(ngnExpenses.sourceAmountMinor, '100000'); // $1,000.00
    assert.strictEqual(ngnExpenses.targetCurrency, 'NGN');
    assert.strictEqual(ngnExpenses.actionType, 'CONVERT_FX');

    const taxReserve = intent.allocations.find((a) => a.category === 'TAX');
    assert.ok(taxReserve, 'Tax Reserve allocation must exist');
    assert.strictEqual(taxReserve.percentage, 20);
    assert.strictEqual(taxReserve.sourceAmountMinor, '40000'); // $400.00
    assert.ok(
      ['SWEEP_VAULT', 'HOLD'].includes(taxReserve.actionType),
      `Expected SWEEP_VAULT or HOLD, got ${taxReserve.actionType}`
    );

    // Invariant: Always requires explicit approval
    assert.strictEqual(intent.requiresExplicitApproval, true);
  });

  it('rejects allocations where percentage sum does not equal 100%', () => {
    const invalidIntent: MissionIntent = {
      intentId: 'test_invalid',
      originalPrompt: 'test',
      intentType: 'SPLIT_INCOMING',
      ruleTitle: 'Invalid Split',
      triggerCondition: {
        type: 'WHEN_RECEIVE',
        sourceCurrency: 'USD',
        sourceAmount: '1000.00',
        sourceAmountMinor: '100000',
        description: 'Test',
      },
      allocations: [
        {
          id: '1',
          category: 'RESERVE',
          label: 'USD',
          percentage: 40,
          targetCurrency: 'USD',
          sourceAmountMinor: '40000',
          sourceAmountFormatted: '400.00',
          destinationWalletTag: 'Vault',
          actionType: 'HOLD',
        },
        {
          id: '2',
          category: 'EXPENSES',
          label: 'NGN',
          percentage: 40, // Sum = 80%, not 100%
          targetCurrency: 'NGN',
          sourceAmountMinor: '40000',
          sourceAmountFormatted: '400.00',
          destinationWalletTag: 'Wallet',
          actionType: 'CONVERT_FX',
        },
      ],
      destinationWallets: {},
      explanation: 'Invalid',
      confidenceScore: 0.9,
      requiresExplicitApproval: true,
    };

    const result = MissionValidator.validate(invalidIntent);
    assert.strictEqual(result.valid, false);
    assert.ok(result.errors.some((e) => e.includes('must equal exactly 100%')));
  });

  it('rejects unsupported currencies in allocations', () => {
    const invalidCurrencyIntent: MissionIntent = {
      intentId: 'test_currency',
      originalPrompt: 'test',
      intentType: 'SPLIT_INCOMING',
      ruleTitle: 'Unsupported Currency',
      triggerCondition: {
        type: 'WHEN_RECEIVE',
        sourceCurrency: 'USD',
        sourceAmount: '1000.00',
        sourceAmountMinor: '100000',
        description: 'Test',
      },
      allocations: [
        {
          id: '1',
          category: 'CUSTOM',
          label: 'YEN',
          percentage: 100,
          targetCurrency: 'JPY' as any, // Unsupported
          sourceAmountMinor: '100000',
          sourceAmountFormatted: '1000.00',
          destinationWalletTag: 'Vault',
          actionType: 'HOLD',
        },
      ],
      destinationWallets: {},
      explanation: 'Unsupported currency',
      confidenceScore: 0.9,
      requiresExplicitApproval: true,
    };

    const result = MissionValidator.validate(invalidCurrencyIntent);
    assert.strictEqual(result.valid, false);
    assert.ok(result.errors.some((e) => e.includes('unsupported')));
  });

  it('generates proposal and signing hash payload for valid mission', async () => {
    const { intent } = await MissionInterpreter.interpret(flagshipPrompt);
    const proposal = await MoneyMissionService.proposeMission(intent);

    assert.ok(proposal.proposalId.startsWith('bmoni_prop_'));
    assert.ok(proposal.missionId.startsWith('mission_'));
    assert.ok(proposal.hashToSign.startsWith('0x'));
    assert.strictEqual(proposal.hashToSign.length, 66); // '0x' + 64 hex chars (32 bytes)
    assert.strictEqual(proposal.allocations.length, 3);
  });

  it('executes mission with explicit B-Key signature', async () => {
    const mockSignature = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1c';
    const execution = await MoneyMissionService.executeMission({
      missionId: 'mission_test_exec',
      signature: mockSignature,
      pinValidated: true,
    });

    assert.strictEqual(execution.success, true);
    assert.strictEqual(execution.status, 'ACTIVE');
    assert.ok(execution.transactionReference.startsWith('bmoni_tx_'));
    assert.ok(execution.auditId.startsWith('audit_'));
  });
});
