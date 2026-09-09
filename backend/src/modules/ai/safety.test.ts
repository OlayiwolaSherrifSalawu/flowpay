import test from 'node:test';
import assert from 'node:assert';
import { FinancialIntentInterpreter } from './interpreter.js';
import { FinancialSafetyValidator } from './validator.js';
import { FinancialSafetyError } from '../../core/errors.js';
import type { SendMoneyAction, ConvertCurrencyAction, CreateReserveAction } from './types.js';

test('Financial Safety - interprets single transfer with backward compatibility', async () => {
  const prompt = 'Send $500 to bunch.dillon@example.ng';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 1);
  const send = intent.actions[0] as SendMoneyAction;
  assert.strictEqual(send.type, 'SEND_MONEY');
  assert.strictEqual(send.currency, 'USD');
  assert.strictEqual(send.amountMinor, '50000'); // $500.00
  assert.strictEqual(send.recipient, 'Bunch.dillon@example.ng');
  assert.strictEqual(intent.requiresExplicitApproval, true);

  // Backward-compatibility properties
  assert.strictEqual(intent.operationType, 'TRANSFER');
  assert.strictEqual(intent.parameters?.sourceCurrency, 'USD');
  assert.strictEqual(intent.parameters?.amountMinor, '50000');
});

test('Financial Safety - CRITICAL: "send 20 usd to mom and 30 usd to dad" extracts 2 independent actions', async () => {
  const prompt = 'send 20 usd to mom and 30 usd to dad';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2, 'Must extract exactly 2 actions');

  const act1 = intent.actions[0] as SendMoneyAction;
  assert.strictEqual(act1.type, 'SEND_MONEY');
  assert.strictEqual(act1.amount, '20.00');
  assert.strictEqual(act1.currency, 'USD');
  assert.strictEqual(act1.recipient, 'Mom');

  const act2 = intent.actions[1] as SendMoneyAction;
  assert.strictEqual(act2.type, 'SEND_MONEY');
  assert.strictEqual(act2.amount, '30.00');
  assert.strictEqual(act2.currency, 'USD');
  assert.strictEqual(act2.recipient, 'Dad');

  assert.strictEqual(intent.completeness.score, 1.0);
  assert.strictEqual(intent.completeness.detectedActionCount, 2);
  assert.strictEqual(intent.completeness.unresolvedActionCount, 0);
});

test('Financial Safety - 3 transfers: "send 20 to mom, 30 to dad, and 40 to my brother"', async () => {
  const prompt = 'send 20 to mom, 30 to dad, and 40 to my brother';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 3);
  assert.strictEqual((intent.actions[0] as SendMoneyAction).recipient, 'Mom');
  assert.strictEqual((intent.actions[0] as SendMoneyAction).amount, '20.00');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).recipient, 'Dad');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).amount, '30.00');
  assert.strictEqual((intent.actions[2] as SendMoneyAction).recipient, 'Brother');
  assert.strictEqual((intent.actions[2] as SendMoneyAction).amount, '40.00');
});

test('Financial Safety - Same intent type is never deduplicated: "send 500 to mom and 2000 to designer"', async () => {
  const prompt = 'send 500 to mom and 2000 to designer';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  assert.strictEqual(intent.actions[0].type, 'SEND_MONEY');
  assert.strictEqual(intent.actions[1].type, 'SEND_MONEY');
  assert.strictEqual((intent.actions[0] as SendMoneyAction).amount, '500.00');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).amount, '2000.00');
});

test('Financial Safety - Mixed intents: "send 500 to mom and convert 100 eur to usd"', async () => {
  const prompt = 'send 500 to mom and convert 100 eur to usd';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  const send = intent.actions[0] as SendMoneyAction;
  assert.strictEqual(send.type, 'SEND_MONEY');
  assert.strictEqual(send.amount, '500.00');
  assert.strictEqual(send.recipient, 'Mom');

  const conv = intent.actions[1] as ConvertCurrencyAction;
  assert.strictEqual(conv.type, 'CONVERT_CURRENCY');
  assert.strictEqual(conv.amount, '100.00');
  assert.strictEqual(conv.sourceCurrency, 'EUR');
  assert.strictEqual(conv.destinationCurrency, 'USD');
});

test('Financial Safety - Transfer + reserve: "send 500 to mom and keep 300 for taxes"', async () => {
  const prompt = 'send 500 to mom and keep 300 for taxes';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  assert.strictEqual(intent.actions[0].type, 'SEND_MONEY');
  assert.strictEqual((intent.actions[0] as SendMoneyAction).amount, '500.00');

  const res = intent.actions[1] as CreateReserveAction;
  assert.strictEqual(res.type, 'CREATE_RESERVE');
  assert.strictEqual(res.amount, '300.00');
  assert.strictEqual(res.purpose, 'tax');
});

test('Financial Safety - 4 actions: "send 500 to mom, send 200 to dad, convert 100 eur to usd, and keep 300 for tax"', async () => {
  const prompt = 'send 500 to mom, send 200 to dad, convert 100 eur to usd, and keep 300 for tax';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 4);
  assert.strictEqual(intent.actions[0].type, 'SEND_MONEY');
  assert.strictEqual(intent.actions[1].type, 'SEND_MONEY');
  assert.strictEqual(intent.actions[2].type, 'CONVERT_CURRENCY');
  assert.strictEqual(intent.actions[3].type, 'CREATE_RESERVE');
});

test('Financial Safety - Word numbers and conjunctions: "Give Mom twenty dollars and Dad thirty."', async () => {
  const prompt = 'Give Mom twenty dollars and Dad thirty.';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  assert.strictEqual((intent.actions[0] as SendMoneyAction).amount, '20.00');
  assert.strictEqual((intent.actions[0] as SendMoneyAction).recipient, 'Mom');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).amount, '30.00');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).recipient, 'Dad');
});

test('Financial Safety - Sentence structure: "Mom gets $20. Dad gets $30."', async () => {
  const prompt = 'Mom gets $20. Dad gets $30.';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  assert.strictEqual((intent.actions[0] as SendMoneyAction).amount, '20.00');
  assert.strictEqual((intent.actions[0] as SendMoneyAction).recipient, 'Mom');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).amount, '30.00');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).recipient, 'Dad');
});

test('Financial Safety - Shared wallet constraint: "send 20 to mom and 30 to dad from my USD wallet"', async () => {
  const prompt = 'send 20 to mom and 30 to dad from my USD wallet';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  assert.strictEqual((intent.actions[0] as SendMoneyAction).sourceWallet, 'USD Wallet');
  assert.strictEqual((intent.actions[1] as SendMoneyAction).sourceWallet, 'USD Wallet');
});

test('Financial Safety - Dependency representation: "convert 1000 eur to usd and use it to send 500 to mom"', async () => {
  const prompt = 'convert 1000 eur to usd and use it to send 500 to mom';
  const intent = await FinancialIntentInterpreter.interpret(prompt);

  assert.strictEqual(intent.actions.length, 2);
  const conv = intent.actions[0] as ConvertCurrencyAction;
  const send = intent.actions[1] as SendMoneyAction;

  assert.strictEqual(conv.type, 'CONVERT_CURRENCY');
  assert.strictEqual(send.type, 'SEND_MONEY');
  assert.ok(send.dependsOn && send.dependsOn.includes(conv.id), 'Send action must depend on conversion action');
});

test('Financial Safety - Completeness check detects missed actions', () => {
  const text = 'send 20 to mom and 30 to dad';
  const incompleteActions = [
    {
      id: 'act_1',
      type: 'SEND_MONEY' as const,
      amount: '20.00',
      amountMinor: '2000',
      currency: 'USD' as const,
      recipient: 'Mom',
      description: 'Send $20.00 to Mom',
    },
  ];

  const report = FinancialIntentInterpreter.validateCompleteness(text, incompleteActions);
  assert.strictEqual(report.isReparseSuggested, true);
  assert.strictEqual(report.detectedActionCount, 2);
  assert.strictEqual(report.unresolvedActionCount, 1);
});

test('Financial Safety - validates and generates preview for multi-action batch', async () => {
  const intent = await FinancialIntentInterpreter.interpret('send 20 usd to mom and 30 usd to dad');
  const availableBalance = 10000n; // $100.00 available
  const preview = FinancialSafetyValidator.validateAndPreview(intent, availableBalance);

  assert.strictEqual(preview.actions.length, 2);
  assert.strictEqual(preview.sourceAmountFormatted, '50.00'); // $20 + $30 = $50.00 total
  assert.strictEqual(preview.requiresOnDeviceSigning, true);
});

test('Financial Safety - rejects multi-action batch when total exceeds available balance', async () => {
  const intent = await FinancialIntentInterpreter.interpret('send 500 to mom and 2000 to designer');
  const availableBalance = 200000n; // Only $2,000 available, but $2,500 requested
  assert.throws(
    () => {
      FinancialSafetyValidator.validateAndPreview(intent, availableBalance);
    },
    (err: any) => err instanceof FinancialSafetyError && /Insufficient funds/.test(err.message)
  );
});

test('Financial Safety - rejects zero or negative amounts in batch', async () => {
  const intent = await FinancialIntentInterpreter.interpret('Send $0 to Bunch Dillon');
  const availableBalance = 100000n;

  assert.throws(
    () => {
      FinancialSafetyValidator.validateAndPreview(intent, availableBalance);
    },
    (err: any) => err instanceof FinancialSafetyError && /strictly greater than zero/.test(err.message)
  );
});
