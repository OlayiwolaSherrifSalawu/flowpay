import test from 'node:test';
import assert from 'node:assert';
import { Money } from './money.js';

test('Money - handles minor units correctly without float drift', () => {
  const m1 = Money.fromMinor(1050n, 'USD'); // $10.50
  const m2 = Money.fromMinor(425n, 'USD');  // $4.25
  const sum = m1.add(m2);

  assert.strictEqual(sum.amountMinor, 1475n);
  assert.strictEqual(sum.toMajorString(), '14.75');
});

test('Money - parses major decimal strings accurately', () => {
  const m = Money.fromMajor('1250.75', 'NGN');
  assert.strictEqual(m.amountMinor, 125075n);
  assert.strictEqual(m.toMajorString(), '1250.75');
});

test('Money - prevents currency mismatch', () => {
  const usd = Money.fromMinor(1000n, 'USD');
  const ngn = Money.fromMinor(1000n, 'NGN');

  assert.throws(() => {
    usd.add(ngn);
  }, /Currency mismatch/);
});

test('Money - basis points multiplication for fees', () => {
  const amount = Money.fromMajor('1000.00', 'USD'); // $1000.00 = 100,000 minor
  // 150 basis points = 1.5% -> $15.00
  const fee = amount.multiplyBasisPoints(150);
  assert.strictEqual(fee.toMajorString(), '15.00');
});
