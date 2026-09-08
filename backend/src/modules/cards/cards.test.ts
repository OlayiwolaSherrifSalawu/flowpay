import test, { describe } from 'node:test';
import assert from 'node:assert/strict';
import { CardService } from './service.js';
import { bmoniClient } from '../../bmoni/client.js';
import { BmoniApiError, BmoniUnavailableError, CardEnrollmentRequiredError, ValidationError } from '../../core/errors.js';

describe('Virtual Employee Cards & Proposal Lifecycle', () => {
  test('parses minor-unit string correctly for card detail ledger', () => {
    const parsedNgn = CardService.parseMinorUnitString('250000', 'NGN');
    assert.equal(parsedNgn.minor, 250000);
    assert.equal(parsedNgn.major, 2500.0);
    assert.equal(parsedNgn.formatted, '₦2,500.00');

    const parsedUsd = CardService.parseMinorUnitString('4250', 'USD');
    assert.equal(parsedUsd.minor, 4250);
    assert.equal(parsedUsd.major, 42.5);
    assert.equal(parsedUsd.formatted, '$42.50');
  });

  test('parses major-unit number correctly for card transactions', () => {
    const parsedUsd = CardService.parseMajorUnitNumber(25.5, 'USD');
    assert.equal(parsedUsd.major, 25.5);
    assert.equal(parsedUsd.minor, 2550);
    assert.equal(parsedUsd.formatted, '$25.50');

    const parsedNgn = CardService.parseMajorUnitNumber(15000.75, 'NGN');
    assert.equal(parsedNgn.major, 15000.75);
    assert.equal(parsedNgn.minor, 1500075);
    assert.equal(parsedNgn.formatted, '₦15,000.75');
  });

  test('creates virtual card proposal auto-approved with FlowPay Amber color (#F4B740)', async () => {
    const originalCreate = bmoniClient.createVirtualCard;
    bmoniClient.createVirtualCard = async () => ({
      flow: 'group',
      feeAmount: '1000',
      feeCurrency: 'NGN',
      proposalId: 'prop_real_card_01',
      proposalStatus: 'PENDING_APPROVALS',
      signPayload: {
        hashToSign: '0x' + 'ab'.repeat(32),
        safeTxHash: '0x' + 'ab'.repeat(32),
        deadline: new Date(Date.now() + 3600000).toISOString(),
      },
      signPayloadPending: false,
      card: {
        id: 'card_real_01',
        userId: 'usr_test_employee_01',
        smartWalletId: 'sw_cngn_test_01',
        cardName: 'Payroll Spend Card',
        cardColor: '#F4B740',
        currency: 'NGN',
        type: 'virtual',
        status: 'RESERVED',
        isReserved: true,
        proposalId: 'prop_real_card_01',
        proposalStatus: 'PENDING_APPROVALS',
        last4: '4289',
        maskedPan: '•••• •••• •••• 4289',
        expirationDate: '08/29',
        createdAt: new Date().toISOString(),
      },
    } as any);

    try {
      const res = await CardService.createVirtualCard({
        userId: 'usr_test_employee_01',
        cardName: 'Payroll Spend Card',
        currency: 'NGN',
        smartWalletId: 'sw_cngn_test_01',
        nin: '12345678901',
      });

      assert.ok(res.proposalId, 'proposalId must be present');
      assert.equal(res.proposalStatus, 'PENDING_APPROVALS', 'Proxy auto-approves proposals');
      assert.ok(res.signPayload, 'signPayload must be present');
      assert.equal(res.card?.cardColor, '#F4B740', 'Must use FlowPay Amber');
      assert.equal(res.card?.isReserved, true, 'Pre-signed card starts in reserved state');
    } finally {
      bmoniClient.createVirtualCard = originalCreate;
    }
  });

  test('throws BmoniUnavailableError when BMONI card creation fails with 5xx (never fabricates fake card)', async () => {
    const originalCreate = bmoniClient.createVirtualCard;
    bmoniClient.createVirtualCard = async () => {
      throw new BmoniApiError('BMONI 500: Card provider gateway timeout', 500);
    };

    try {
      await assert.rejects(
        async () => {
          await CardService.createVirtualCard({
            userId: 'usr_test_employee_01',
            cardName: 'Payroll Spend Card',
            currency: 'NGN',
            smartWalletId: 'sw_cngn_test_01',
          });
        },
        BmoniUnavailableError,
        'Must propagate 5xx failure as BmoniUnavailableError'
      );
    } finally {
      bmoniClient.createVirtualCard = originalCreate;
    }
  });

  test('throws CardEnrollmentRequiredError when BMONI card creation returns 400 E101', async () => {
    const originalCreate = bmoniClient.createVirtualCard;
    bmoniClient.createVirtualCard = async () => {
      throw new BmoniApiError('E101: Card owner is not enrolled for cards yet', 400, 'E101', { isEnrollmentRequired: true });
    };

    try {
      await assert.rejects(
        async () => {
          await CardService.createVirtualCard({
            userId: 'usr_test_employee_01',
            cardName: 'Payroll Spend Card',
            currency: 'NGN',
            smartWalletId: 'sw_cngn_test_01',
          });
        },
        CardEnrollmentRequiredError,
        'Must propagate E101 as CardEnrollmentRequiredError'
      );
    } finally {
      bmoniClient.createVirtualCard = originalCreate;
    }
  });

  test('enforces smartWalletId and cardName validation on card creation', async () => {
    await assert.rejects(
      async () => {
        await CardService.createVirtualCard({
          userId: 'usr_test_01',
          cardName: 'Valid Name',
          currency: 'USD',
          smartWalletId: '',
        });
      },
      ValidationError,
      'Should reject missing smartWalletId'
    );

    await assert.rejects(
      async () => {
        await CardService.createVirtualCard({
          userId: 'usr_test_01',
          cardName: '',
          currency: 'USD',
          smartWalletId: 'sw_valid',
        });
      },
      ValidationError,
      'Should reject empty cardName'
    );
  });

  test('retrieves proposal sign payload for hardware signing', async () => {
    const originalGet = bmoniClient.getProposalSignPayload;
    bmoniClient.getProposalSignPayload = async () => ({
      hashToSign: '0x' + '12'.repeat(32),
      isPending: false,
    });

    try {
      const payload = await CardService.getProposalSignPayload({
        userId: 'usr_test_01',
        proposalId: 'prop_card_123',
      });

      assert.ok(payload.hashToSign, 'hashToSign must be returned');
      assert.ok(payload.hashToSign.startsWith('0x'), 'hash must be 0x hex');
      assert.equal(payload.isPending, false);
    } finally {
      bmoniClient.getProposalSignPayload = originalGet;
    }
  });

  test('throws BmoniUnavailableError when getProposalSignPayload fails (never fabricates dummy hash)', async () => {
    const originalGet = bmoniClient.getProposalSignPayload;
    bmoniClient.getProposalSignPayload = async () => {
      throw new Error('BMONI sign payload connection refused');
    };

    try {
      await assert.rejects(
        async () => {
          await CardService.getProposalSignPayload({
            userId: 'usr_test_01',
            proposalId: 'prop_card_123',
          });
        },
        BmoniUnavailableError,
        'Must reject with BmoniUnavailableError when sign payload cannot be retrieved'
      );
    } finally {
      bmoniClient.getProposalSignPayload = originalGet;
    }
  });

  test('submits valid 0x hex signature for card issuance proposal when BMONI succeeds', async () => {
    const originalSubmit = bmoniClient.submitProposalSignature;
    bmoniClient.submitProposalSignature = async () => ({
      success: true,
      status: 'COMPLETED',
      transactionHash: '0x' + '34'.repeat(32),
    });

    try {
      const result = await CardService.submitProposalSignature({
        userId: 'usr_test_01',
        proposalId: 'prop_card_123',
        signature: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b',
      });

      assert.equal(result.success, true);
      assert.equal(result.status, 'COMPLETED');
    } finally {
      bmoniClient.submitProposalSignature = originalSubmit;
    }
  });

  test('throws BmoniUnavailableError when submitProposalSignature fails (never returns fake COMPLETED)', async () => {
    const originalSubmit = bmoniClient.submitProposalSignature;
    bmoniClient.submitProposalSignature = async () => {
      throw new Error('BMONI 500: On-chain transaction revert');
    };

    try {
      await assert.rejects(
        async () => {
          await CardService.submitProposalSignature({
            userId: 'usr_test_01',
            proposalId: 'prop_card_123',
            signature: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b',
          });
        },
        BmoniUnavailableError,
        'Must reject with BmoniUnavailableError when signature submission fails'
      );
    } finally {
      bmoniClient.submitProposalSignature = originalSubmit;
    }
  });

  test('rejects malformed signature when submitting proposal', async () => {
    await assert.rejects(
      async () => {
        await CardService.submitProposalSignature({
          userId: 'usr_test_01',
          proposalId: 'prop_card_123',
          signature: 'invalid_non_hex',
        });
      },
      ValidationError,
      'Should reject signatures without 0x prefix'
    );
  });

  test('lists wallet cards and preserves reserved state for pending issuance', async () => {
    const cards = await CardService.listCards('usr_test_01', 'sw_cngn_test_01');
    assert.ok(Array.isArray(cards));
    assert.ok(cards.length > 0);
    for (const card of cards) {
      assert.equal(card.cardColor, '#F4B740', 'Card face color must be FlowPay Amber');
      assert.equal(typeof card.isReserved, 'boolean');
    }
  });

  test('retrieves card detail with balance and ledger items', async () => {
    const card = await CardService.getCardDetail('usr_test_01', 'sw_cngn_test_01', 'card_virt_ngn_02');
    assert.equal(card.id, 'card_virt_ngn_02');
    assert.ok(card.balanceMinor, 'balanceMinor must be present');
    assert.ok(Array.isArray(card.ledger), 'ledger must be an array');
    if (card.ledger && card.ledger.length > 0) {
      const entry = card.ledger[0];
      assert.equal(typeof entry.amount, 'string', 'ledger amounts are minor-unit strings');
      const parsed = CardService.parseMinorUnitString(entry.amount, entry.currency);
      assert.ok(parsed.major > 0);
    }
  });

  test('retrieves sensitive card details with unmasked PAN and CVV', async () => {
    const sensitive = await CardService.getCardSensitiveData('usr_test_01', 'card_virt_ngn_02');
    assert.ok(sensitive.pan, 'PAN must be present');
    assert.ok(sensitive.cvv, 'CVV must be present');
    assert.ok(sensitive.expirationDate, 'expirationDate must be present');
  });

  test('retrieves transactions with major-unit numeric amounts', async () => {
    const txs = await CardService.getCardTransactions({
      userId: 'usr_test_01',
      cardId: 'card_virt_usd_01',
      size: 10,
    });
    assert.ok(Array.isArray(txs));
    assert.ok(txs.length > 0);
    for (const tx of txs) {
      assert.equal(typeof tx.amount, 'number', 'Transaction amounts must be numeric');
      assert.ok(tx.amount > 0);
    }
  });

  test('updates card status strictly accepting BLOCKED and ACTIVE', async () => {
    const blocked = await CardService.updateCardStatus('usr_test_01', 'card_virt_usd_01', 'BLOCKED');
    assert.equal(blocked.status, 'BLOCKED');

    const active = await CardService.updateCardStatus('usr_test_01', 'card_virt_usd_01', 'ACTIVE');
    assert.equal(active.status, 'ACTIVE');

    await assert.rejects(
      async () => {
        // @ts-expect-error test invalid status
        await CardService.updateCardStatus('usr_test_01', 'card_virt_usd_01', 'FROZEN');
      },
      ValidationError,
      'Should reject any status other than BLOCKED or ACTIVE'
    );
  });
});
