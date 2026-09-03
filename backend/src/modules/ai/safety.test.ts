import test from 'node:test';
import assert from 'node:assert';
import { FinancialIntentInterpreter } from './interpreter.js';
import { FinancialSafetyValidator } from './validator.js';
import { FinancialSafetyError } from '../../core/errors.js';

test('Financial Safety - interprets natural language to structured intent', () => {
  const prompt = 'Send $500 to bunch.dillon@example.ng';
  const intent = FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.operationType, 'TRANSFER');
  assert.strictEqual(intent.parameters.sourceCurrency, 'USD');
  assert.strictEqual(intent.parameters.amountMinor, '50000'); // $500.00
  assert.strictEqual(intent.parameters.recipientIdentifier, 'bunch.dillon@example.ng');
  assert.strictEqual(intent.requiresExplicitApproval, true);
});

test('Financial Safety - validates and generates preview for valid intent', () => {
  const intent = FinancialIntentInterpreter.interpret('Send $100 to Samson Jabo');
  const availableBalance = 100000n; // $1,000 available
  const preview = FinancialSafetyValidator.validateAndPreview(intent, availableBalance);

  assert.strictEqual(preview.sourceAmountFormatted, '100.00');
  assert.strictEqual(preview.requiresOnDeviceSigning, true);
});

test('Financial Safety - rejects intent when amount exceeds available balance', () => {
  const intent = FinancialIntentInterpreter.interpret('Send $5000 to Samson Jabo');
  const availableBalance = 100000n; // Only $1,000 available

  assert.throws(() => {
    FinancialSafetyValidator.validateAndPreview(intent, availableBalance);
  }, (err: any) => err instanceof FinancialSafetyError && /Insufficient funds/.test(err.message));
});

test('Financial Safety - rejects zero or negative amounts', () => {
  const intent = FinancialIntentInterpreter.interpret('Send $0 to Bunch Dillon');
  const availableBalance = 100000n;

  assert.throws(() => {
    FinancialSafetyValidator.validateAndPreview(intent, availableBalance);
  }, (err: any) => err instanceof FinancialSafetyError && /strictly greater than zero/.test(err.message));
});
