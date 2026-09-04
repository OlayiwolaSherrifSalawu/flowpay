import assert from 'node:assert';
import test from 'node:test';
import { TransferInterpreter } from '../ai/transfer_interpreter.js';
import { TransferService } from './service.js';
import type { TransferIntent } from './types.js';
import { TransferValidator } from './validator.js';

test('FlowPay Send Money Feature & Balance-Aware Routing Tests', async (t) => {
  // Test 1: Natural Language Interpretation
  await t.test('interprets "Send $500 to my designer in Ghana" into structured TransferIntent', async () => {
    const prompt = 'Send $500 to my designer in Ghana.';
    const intent = await TransferInterpreter.interpret(prompt);

    assert.strictEqual(intent.amount, '500.00');
    assert.strictEqual(intent.amountMinor, '50000');
    assert.strictEqual(intent.currency, 'USD');
    assert.match(intent.recipient.toLowerCase(), /designer/);
    assert.strictEqual(intent.requiresExplicitApproval, true);
  });

  await t.test('interprets additional representative transfer prompts', async () => {
    const p1 = 'Send $150 to bunch.dillon@example.ng';
    const i1 = TransferInterpreter.interpretDeterministic(p1);
    assert.strictEqual(i1.amount, '150.00');
    assert.strictEqual(i1.currency, 'USD');
    assert.strictEqual(i1.recipient, 'bunch.dillon@example.ng');

    const p2 = 'Send ₦50,000 to Samson Jabo';
    const i2 = TransferInterpreter.interpretDeterministic(p2);
    assert.strictEqual(i2.amount, '50000.00');
    assert.strictEqual(i2.amountMinor, '5000000');
    assert.strictEqual(i2.currency, 'NGN');
    assert.match(i2.recipient, /Samson/);

    const p3 = 'Send $1,200 to contractor in Mexico';
    const i3 = TransferInterpreter.interpretDeterministic(p3);
    assert.strictEqual(i3.amount, '1200.00');
    assert.strictEqual(i3.currency, 'USD');
    assert.match(i3.recipient, /contractor/);
  });

  // Test 2: Validation
  await t.test('validates valid TransferIntent and rejects invalid payloads', () => {
    const valid: TransferIntent = {
      intentId: 'tx_test_1',
      originalPrompt: 'Send $500 to designer',
      recipient: 'my designer in Ghana',
      amount: '500.00',
      amountMinor: '50000',
      currency: 'USD',
      purpose: 'Design services',
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
      provider: 'deterministic-fallback',
    };

    const validated = TransferValidator.validateIntent(valid);
    assert.strictEqual(validated.recipient, 'my designer in Ghana');

    // Reject non-positive amount
    assert.throws(() => {
      TransferValidator.validateIntent({ ...valid, amountMinor: '0' });
    }, /amount must be greater than zero/);

    // Reject empty recipient
    assert.throws(() => {
      TransferValidator.validateIntent({ ...valid, recipient: '' });
    }, /Recipient is required/);

    // Reject unsupported currency
    assert.throws(() => {
      TransferValidator.validateIntent({ ...valid, currency: 'JPY' as any });
    }, /Invalid/);
  });

  // Test 3: Balance-Aware Flow (The prompt's primary example)
  await t.test('Balance-Aware Flow: User wants $500 USD, has $300 USD, sufficient NGN -> produces NGN funded transfer with NGN->USD conversion', () => {
    const intent: TransferIntent = {
      intentId: 'tx_balance_aware_01',
      originalPrompt: 'Send $500 to my designer in Ghana.',
      recipient: 'my designer in Ghana',
      amount: '500.00',
      amountMinor: '50000',
      currency: 'USD',
      purpose: 'Payment for design services in Ghana',
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
    };

    const userWallets = [
      {
        id: 'sw_usd_wallet',
        currency: 'USD' as const,
        balanceMinor: '30000', // $300.00 USD (insufficient for $500)
        name: 'USD Smart Wallet',
      },
      {
        id: 'sw_ngn_wallet',
        currency: 'NGN' as const,
        balanceMinor: '682000000', // ₦6,820,000.00 NGN (sufficient)
        name: 'NGN Smart Wallet',
      },
      {
        id: 'sw_mxn_wallet',
        currency: 'MXN' as const,
        balanceMinor: '4850000', // $48,500.00 MXN
        name: 'MXN Smart Wallet',
      },
    ];

    const inspection = TransferService.inspectBalances(intent, userWallets);

    assert.strictEqual(inspection.isPossible, true);
    assert.strictEqual(inspection.isDirectFunded, false, 'USD direct balance is $300, insufficient for $500');
    assert.ok(inspection.recommendedFundingOption, 'Must recommend a viable funding option');

    const funding = inspection.recommendedFundingOption!;
    assert.strictEqual(funding.fundingCurrency, 'NGN', 'Funding source must be NGN wallet');
    assert.strictEqual(funding.requiresConversion, true, 'Must require conversion');
    assert.strictEqual(funding.conversionLabel, 'NGN → USD');
    assert.strictEqual(funding.exchangeRate, 1550.0);
    assert.strictEqual(funding.convertedDebitFormatted, '775000.00'); // 500 * 1550 = ₦775,000
    assert.strictEqual(funding.targetPaymentFormatted, '500.00');
  });

  // Test 4: Direct Funding when balance is sufficient
  await t.test('Balance-Aware Flow: Direct transfer when sufficient balance exists in target currency', () => {
    const intent: TransferIntent = {
      intentId: 'tx_direct_01',
      originalPrompt: 'Send $150 to bunch.dillon@example.ng',
      recipient: 'bunch.dillon@example.ng',
      amount: '150.00',
      amountMinor: '15000',
      currency: 'USD',
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
    };

    const userWallets = [
      {
        id: 'sw_usd_wallet',
        currency: 'USD' as const,
        balanceMinor: '30000', // $300.00 USD (sufficient for $150)
        name: 'USD Smart Wallet',
      },
    ];

    const inspection = TransferService.inspectBalances(intent, userWallets);

    assert.strictEqual(inspection.isPossible, true);
    assert.strictEqual(inspection.isDirectFunded, true);
    const funding = inspection.recommendedFundingOption!;
    assert.strictEqual(funding.fundingCurrency, 'USD');
    assert.strictEqual(funding.requiresConversion, false);
    assert.strictEqual(funding.conversionLabel, 'Direct USD Transfer');
    assert.strictEqual(funding.exchangeRate, 1.0);
  });

  // Test 5: Insufficient Funds across all wallets
  await t.test('Balance-Aware Flow: Rejects with INSUFFICIENT_FUNDS when all wallets lack sufficient balance', () => {
    const intent: TransferIntent = {
      intentId: 'tx_insufficient_01',
      originalPrompt: 'Send $50,000 to contractor',
      recipient: 'contractor',
      amount: '50000.00',
      amountMinor: '5000000',
      currency: 'USD',
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
    };

    const userWallets = [
      {
        id: 'sw_usd_wallet',
        currency: 'USD' as const,
        balanceMinor: '30000', // $300.00
        name: 'USD Smart Wallet',
      },
      {
        id: 'sw_ngn_wallet',
        currency: 'NGN' as const,
        balanceMinor: '100000', // ₦1,000.00
        name: 'NGN Smart Wallet',
      },
    ];

    const inspection = TransferService.inspectBalances(intent, userWallets);
    assert.strictEqual(inspection.isPossible, false);
    assert.match(inspection.reason!, /Insufficient funds/);
  });

  // Test 6: BMONI Proposal Creation & On-Device Signing Payload
  await t.test('creates BMONI transfer proposal and provides canonical 32-byte sha256 hash for B-Key signing', async () => {
    const intent: TransferIntent = {
      intentId: 'tx_prop_01',
      originalPrompt: 'Send $500 to my designer in Ghana.',
      recipient: 'my designer in Ghana',
      amount: '500.00',
      amountMinor: '50000',
      currency: 'USD',
      purpose: 'Design payment',
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
    };

    const fundingOption = {
      fundingWalletId: 'sw_ngn_01',
      fundingCurrency: 'NGN' as const,
      fundingWalletName: 'NGN Smart Wallet',
      availableBalanceMinor: '682000000',
      availableBalanceFormatted: '6820000.00',
      requiresConversion: true,
      conversionLabel: 'NGN → USD',
      exchangeRate: 1550.0,
      convertedDebitMinor: '77500000',
      convertedDebitFormatted: '775000.00',
      networkFeeMinor: '77500',
      networkFeeFormatted: '775.00',
      fxFeeMinor: '116250',
      fxFeeFormatted: '1162.50',
      totalDebitMinor: '77693750',
      totalDebitFormatted: '776937.50',
      targetPaymentMinor: '50000',
      targetPaymentFormatted: '500.00',
    };

    const proposal = await TransferService.createProposal({
      userId: 'usr_flowpay_sandbox_master',
      intent,
      fundingOption,
    });

    assert.ok(proposal.proposalId);
    assert.strictEqual(proposal.status, 'PENDING_SIGNATURES');
    assert.match(proposal.hashToSign, /^0x[a-f0-9]{64}$/i);
    assert.strictEqual(proposal.fundingOption.conversionLabel, 'NGN → USD');
  });

  // Test 7: B-Key Signature Submission and Activity Persistence
  await t.test('executes transfer with valid on-device B-Key signature and records to PostgreSQL Activity', async () => {
    const dummySig = '0x' + 'ab'.repeat(65); // 65-byte hex signature

    const result = await TransferService.executeTransfer({
      userId: 'usr_flowpay_sandbox_master',
      proposalId: 'prop_tx_test_123',
      signature: dummySig,
    });

    assert.strictEqual(result.status, 'COMPLETED');
    assert.match(result.transactionHash, /^0x[a-f0-9]{64}$/);
    assert.ok(result.auditActivityId);
  });

  // Test 8: Human-Readable Error Formatting across all 8 failure modes
  await t.test('formats human-readable error messages for all 8 failure modes', () => {
    assert.match(TransferValidator.formatError('INSUFFICIENT_FUNDS'), /Insufficient funds/);
    assert.match(TransferValidator.formatError('UNSUPPORTED_CURRENCY'), /unsupported/);
    assert.match(TransferValidator.formatError('INVALID_RECIPIENT'), /Invalid recipient/);
    assert.match(TransferValidator.formatError('CONVERSION_UNAVAILABLE'), /conversion.*unavailable/i);
    assert.match(TransferValidator.formatError('TRANSFER_FAILURE'), /failed to settle/i);
    assert.match(TransferValidator.formatError('SIGNATURE_FAILURE'), /PIN verification failed/i);
    assert.match(TransferValidator.formatError('PROPOSAL_EXPIRATION'), /proposal expired/i);
    assert.match(TransferValidator.formatError('NETWORK_FAILURE'), /Network connection error/i);
  });
});
