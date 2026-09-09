import test from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { BmoniWebhookService } from './webhooks.js';
import { BmoniClient } from './client.js';
import { BmoniApiError } from '../core/errors.js';
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

test('BmoniClient - retries on network error and succeeds on 3rd attempt', async () => {
  const originalFetch = globalThis.fetch;
  let attempts = 0;

  globalThis.fetch = async (...args: any[]) => {
    attempts++;
    if (attempts < 3) {
      throw new TypeError('fetch failed');
    }
    return new Response(JSON.stringify({ success: true, data: 'sandbox_user_created' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    const client = new BmoniClient({ baseUrl: 'https://embedded-dev.bmoni.com', apiKey: 'pk_test_123' });
    const result = await (client as any).request('/v1/users', {
      method: 'POST',
      body: { email: 'test@flowpay.test' },
    });

    assert.strictEqual(attempts, 3, 'Should have made exactly 3 attempts (initial + 2 retries)');
    assert.deepStrictEqual(result, { success: true, data: 'sandbox_user_created' });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('BmoniClient - throws immediately on 401 without retrying', async () => {
  const originalFetch = globalThis.fetch;
  let attempts = 0;

  globalThis.fetch = async (...args: any[]) => {
    attempts++;
    return new Response(JSON.stringify({ message: 'Unauthorized', error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    const client = new BmoniClient({ baseUrl: 'https://embedded-dev.bmoni.com', apiKey: 'pk_bad_key' });
    await assert.rejects(
      async () => {
        await (client as any).request('/v1/users', { method: 'POST', body: {} });
      },
      (err: any) => {
        assert.ok(err instanceof BmoniApiError);
        assert.strictEqual(err.statusCode, 401);
        return true;
      }
    );
    assert.strictEqual(attempts, 1, 'Should have made exactly 1 attempt with no retries');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('BmoniClient - retries on 502 Bad Gateway and succeeds on 2nd attempt', async () => {
  const originalFetch = globalThis.fetch;
  let attempts = 0;

  globalThis.fetch = async (...args: any[]) => {
    attempts++;
    if (attempts === 1) {
      return new Response(JSON.stringify({ message: 'Bad Gateway' }), {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({ success: true, recovered: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  };

  try {
    const client = new BmoniClient({ baseUrl: 'https://embedded-dev.bmoni.com', apiKey: 'pk_test_123' });
    const result = await (client as any).request('/v1/users/status', { method: 'GET' });

    assert.strictEqual(attempts, 2, 'Should have made exactly 2 attempts (1 retry on 502)');
    assert.deepStrictEqual(result, { success: true, recovered: true });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('BmoniClient - throws on timeout (AbortError) without retrying', async () => {
  const originalFetch = globalThis.fetch;
  let attempts = 0;

  globalThis.fetch = async (...args: any[]) => {
    attempts++;
    const abortErr = new Error('The operation was aborted');
    abortErr.name = 'AbortError';
    throw abortErr;
  };

  try {
    const client = new BmoniClient({ baseUrl: 'https://embedded-dev.bmoni.com', apiKey: 'pk_test_123' });
    await assert.rejects(
      async () => {
        await (client as any).request('/v1/users', { method: 'GET' });
      },
      (err: any) => {
        assert.ok(err instanceof BmoniApiError);
        assert.strictEqual(err.statusCode, 504);
        assert.ok(err.message.includes('timed out'));
        return true;
      }
    );
    assert.strictEqual(attempts, 1, 'Timeout should fail immediately with 1 attempt');
  } finally {
    globalThis.fetch = originalFetch;
  }
});
