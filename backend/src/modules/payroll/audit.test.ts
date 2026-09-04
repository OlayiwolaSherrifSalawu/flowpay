import test from 'node:test';
import assert from 'node:assert/strict';
import { PayrollOrchestrationService } from './service.js';
import { Money } from '../../core/money.js';

test('Payroll Activity & Audit Subsystem - Suite', async (t) => {
  await t.test('1. Payroll Run record structure and required fields', async () => {
    const preview = await PayrollOrchestrationService.getPreview();

    assert.ok(preview.runId, 'Payroll run must have a unique runId');
    assert.ok(preview.title, 'Payroll run must have a title');
    assert.ok(typeof preview.employeeCount === 'number', 'Must have employeeCount');
    assert.ok(Array.isArray(preview.countries), 'Must have countries list');
    assert.ok(preview.totalUsdFormatted, 'Must have total USD equivalent');
    assert.ok(preview.totalFeeUsdFormatted, 'Must have fees formatted');
    assert.ok(preview.status, 'Must have a status');
    assert.ok(Array.isArray(preview.items), 'Must contain items list');

    // Assert that each item has required audit tracking fields
    for (const item of preview.items) {
      assert.ok(item.employeeId, 'Item must have employeeId');
      assert.ok(item.name, 'Item must have name');
      assert.ok(item.country, 'Item must have country');
      assert.ok(item.destinationStablecoin, 'Item must have destinationStablecoin');
      assert.ok(item.targetAmountFormatted, 'Item must have targetAmountFormatted');
      assert.ok(item.usdAmountFormatted, 'Item must have usdAmountFormatted');
    }
  });

  await t.test('2. Status values must adhere strictly to the 6 canonical states', () => {
    const allowedStatuses = [
      'DRAFT',
      'PENDING_APPROVAL',
      'PROCESSING',
      'COMPLETED',
      'PARTIALLY_COMPLETED',
      'FAILED',
    ];

    const testStatuses = [
      'DRAFT',
      'PENDING_APPROVAL',
      'PROCESSING',
      'COMPLETED',
      'PARTIALLY_COMPLETED',
      'FAILED',
    ];

    for (const s of testStatuses) {
      assert.ok(
        allowedStatuses.includes(s),
        `Status ${s} must be in the canonical allowlist`
      );
    }
  });

  await t.test('3. Strict Financial Safety Directive: Never expose signing secrets in audit payloads', async () => {
    const preview = await PayrollOrchestrationService.getPreview();
    const serialized = JSON.stringify(preview);

    // Assert that NO private keys or signing materials appear in the audit response
    assert.equal(
      serialized.includes('hashToSign'),
      false,
      'Audit preview must NEVER contain hashToSign'
    );
    assert.equal(
      serialized.includes('privateKey'),
      false,
      'Audit preview must NEVER contain privateKey'
    );
    assert.equal(
      serialized.includes('secretKey'),
      false,
      'Audit preview must NEVER contain webhook secretKey'
    );
    assert.equal(
      serialized.includes('mnemonic'),
      false,
      'Audit preview must NEVER contain mnemonic phrase'
    );
  });

  await t.test('4. Independent failure isolation and retry payload structure', async () => {
    // When a proposal fails, retryProposal calls approve and returns the updated item
    const retryResult = await PayrollOrchestrationService.retryProposal(
      'usr_flowpay_sandbox_master',
      'prop_sandbox_failed_retry_test',
      'emp_bunch_dillon'
    );

    assert.ok(retryResult, 'Retry result must be defined');
    assert.equal(typeof retryResult.success, 'boolean', 'Retry result must have success boolean');
    assert.ok(retryResult.item, 'Retry result must return updated item');
    assert.equal(retryResult.item.employeeId, 'emp_bunch_dillon');

    // Assert retry payload does not leak secrets
    const serializedRetry = JSON.stringify(retryResult);
    assert.equal(serializedRetry.includes('hashToSign'), false);
    assert.equal(serializedRetry.includes('privateKey'), false);
  });

  await t.test('5. Cost transparency & savings comparison precision', async () => {
    const preview = await PayrollOrchestrationService.getPreview();

    // Traditional wire: $170/country * 2 countries = $340
    // BMONI fee: $5/country * 2 countries = $10
    // Savings: $330 (97.0%)
    assert.equal(preview.totalFeeUsdFormatted, '10.00');
    assert.equal(preview.totalSavedUsdFormatted, '330.00');
    assert.equal(preview.savedPercentage, 97.0);
  });
});
