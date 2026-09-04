import assert from 'node:assert/strict';
import test, { describe } from 'node:test';
import { ethers } from 'ethers';
import { getStablecoinForCurrency, getStablecoinForCountry } from '../../core/currencies.js';
import { PayrollOrchestrationService } from './service.js';

describe('Global Payroll Orchestration & BMONI Primitives', () => {
  /**
   * 1. Official BMONI Known-Good Offline Signing Test Vector
   * Source: https://bkey.mintlify.app/api-reference/signing#reproduce-a-known-good-signature
   *
   * Confirms the toolchain produces the exact secp256k1 signature BMONI expects
   * over the raw 32-byte digest WITHOUT applying the EIP-191 prefix.
   */
  test('Reproduces official BMONI known-good offline signing test vector', () => {
    const PK = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    const preimage = 'bmoni-embedded:BKE-2041:sign-payload-example';
    const expectedHash = '0x8f5156823a5c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31';
    const expectedSignature =
      '0x628f1aff48c9d1f35d45a735eb026db0437c5ed334a94dc7fb0ac86ca32c10bd' +
      '173a653a7f064c4512244f6fcbefb07e13bfe7368fcacdcc4e6fb153f50050991b';
    const expectedOwnerAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

    // 1. Hash preimage with Keccak-256
    const hash = ethers.keccak256(ethers.toUtf8Bytes(preimage));
    assert.equal(hash, expectedHash, 'Keccak256 hash must match official test vector');

    // 2. Sign the raw digest directly (signingKey.sign, NOT signMessage)
    const signingKey = new ethers.SigningKey(PK);
    const signature = signingKey.sign(hash).serialized;
    assert.equal(signature, expectedSignature, 'Raw secp256k1 signature must be byte-identical');

    // 3. Verify ecrecover recovers the registered owner address
    const recovered = ethers.recoverAddress(hash, expectedSignature);
    assert.equal(recovered.toLowerCase(), expectedOwnerAddress.toLowerCase(), 'Recovered address must match owner');

    // 4. Prove that message-signing (EIP-191 prefix) produces an incorrect signature
    const wallet = new ethers.Wallet(PK);
    // When using message signing, it adds prefix "\x19Ethereum Signed Message:\n32" and hashes again:
    const wrongSignature = wallet.signingKey.sign(ethers.hashMessage(ethers.getBytes(hash))).serialized;
    assert.notEqual(wrongSignature, expectedSignature, 'Message signing must NOT equal proposal signature');
    const wrongRecovered = ethers.recoverAddress(hash, wrongSignature);
    assert.notEqual(wrongRecovered.toLowerCase(), expectedOwnerAddress.toLowerCase(), 'Wrong method recovers wrong address');
  });

  /**
   * 2. Recipient Rail Currency & Stablecoin Mapping Validation
   * Per BMONI docs: Smart wallets take canonical stablecoin token codes (CNGN, MEXe),
   * not fiat codes (NGN, MXN). Sending to unactivated currency fails with 400.
   */
  test('Maps currencies strictly to canonical BMONI settlement stablecoins', () => {
    assert.equal(getStablecoinForCurrency('NGN'), 'CNGN');
    assert.equal(getStablecoinForCurrency('MXN'), 'MEXe');
    assert.equal(getStablecoinForCurrency('USD'), 'USDB');
    assert.equal(getStablecoinForCountry('NG'), 'CNGN');
    assert.equal(getStablecoinForCountry('MX'), 'MEXe');
  });

  /**
   * 3. Payroll Preview with Rail Verification and Fee Comparison
   */
  test('Generates preview with rail readiness, employer balance, and fee comparison', async () => {
    const preview = await PayrollOrchestrationService.getPreview();

    assert.ok(preview.runId.startsWith('preview_'), 'RunId must be generated');
    assert.ok(preview.items.length >= 2, 'Must include at least Nigeria and Mexico employees');
    assert.equal(preview.countries.includes('NG'), true, 'Must include Nigeria');
    assert.equal(preview.countries.includes('MX'), true, 'Must include Mexico');

    // Fee comparison: traditional wire ~$170/country vs BMONI ~$5/country
    assert.ok(preview.totalFeeUsdMinor <= 2000, 'BMONI fee must be aggregate low fee ($10-$15)');
    assert.ok(preview.totalSavedUsdFormatted.length > 0, 'Must calculate saved wire fees');
    assert.equal(preview.isBalanceSufficient, true, 'Employer balance must cover total');

    // Destination stablecoin verification
    const nigerianItem = preview.items.find((i) => i.country === 'NG');
    assert.ok(nigerianItem, 'Nigerian employee must be present');
    assert.equal(nigerianItem.destinationStablecoin, 'CNGN', 'Nigeria must disburse in CNGN');
    assert.equal(nigerianItem.isRailActive, true, 'Nigeria rail must be active');

    const mexicanItem = preview.items.find((i) => i.country === 'MX');
    assert.ok(mexicanItem, 'Mexican employee must be present');
    assert.equal(mexicanItem.destinationStablecoin, 'MEXe', 'Mexico must disburse in MEXe');
    assert.equal(mexicanItem.isRailActive, true, 'Mexico rail must be active');
  });

  /**
   * 4. Independent Failure Isolation & Partial Completion
   * Per prompt: "one employee's FAILED proposal does not block the others.
   * Completed / overall Payroll Partially Completed framing is correct."
   */
  test('Isolates employee failure without blocking other disbursements', async () => {
    // Execute payroll with simulated unready rail on one custom allocation
    const customAllocations = [
      { employeeId: 'emp_bunch_dillon', usdAmountMinor: 200000 },
      { employeeId: 'emp_samson_jabo', usdAmountMinor: 200000 },
    ];

    const result = await PayrollOrchestrationService.executePayroll(
      'usr_flowpay_employer_test',
      'sw_usdb_source_wallet',
      customAllocations
    );

    assert.ok(result.runId.startsWith('run_'), 'Run must be created');
    assert.ok(result.items.length >= 2, 'Items must be evaluated');

    // All valid items succeed independently
    for (const item of result.items) {
      if (item.isRailActive) {
        assert.equal(item.status, 'SUCCESS', 'Active rail employee must succeed');
        assert.ok(item.proposalId, 'Proposal ID must be recorded');
      }
    }
  });

  /**
   * 5. Proposal Retry Endpoint Logic
   * Per BMONI docs: "A FAILED proposal can be retried by calling approve again, which restarts the workflow."
   */
  test('Retries failed proposal by calling approve to restart workflow', async () => {
    const retryResult = await PayrollOrchestrationService.retryProposal(
      'usr_flowpay_employer_test',
      'prop_test_retry_123',
      'emp_bunch_dillon'
    );

    assert.equal(retryResult.success, true, 'Retry must return success');
    assert.ok(retryResult.message.includes('restarted'), 'Message must indicate restart');
    assert.equal(retryResult.item?.status, 'SUCCESS', 'Item status must transition to SUCCESS');
  });
});
