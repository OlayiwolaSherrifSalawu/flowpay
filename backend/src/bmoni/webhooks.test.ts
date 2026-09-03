import test from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { BmoniWebhookService } from './webhooks.js';
import { env } from '../config/env.js';

test('Webhook - accepts valid HMAC-SHA256 signature over raw buffer', () => {
  const payload = JSON.stringify({
    id: 'evt_test_123',
    eventType: 'employee.deposit.completed',
    payload: { userId: 'usr_1', amount: '1000' },
    timestamp: new Date().toISOString(),
  });
  const rawBuffer = Buffer.from(payload, 'utf-8');
  const validSignature = crypto
    .createHmac('sha256', env.BMONI_WEBHOOK_SECRET)
    .update(rawBuffer)
    .digest('hex');

  const isValid = BmoniWebhookService.verifySignature(rawBuffer, validSignature);
  assert.strictEqual(isValid, true);
});

test('Webhook - rejects invalid or tampered signature', () => {
  const payload = JSON.stringify({ id: 'evt_tampered' });
  const rawBuffer = Buffer.from(payload, 'utf-8');

  const invalidSignature = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
  const isValid = BmoniWebhookService.verifySignature(rawBuffer, invalidSignature);
  assert.strictEqual(isValid, false);
});

test('Webhook - rejects tampered payload with original signature', () => {
  const original = Buffer.from(JSON.stringify({ amount: 100 }));
  const tampered = Buffer.from(JSON.stringify({ amount: 1000000 }));
  
  const originalSig = crypto
    .createHmac('sha256', env.BMONI_WEBHOOK_SECRET)
    .update(original)
    .digest('hex');

  const isValid = BmoniWebhookService.verifySignature(tampered, originalSig);
  assert.strictEqual(isValid, false);
});
