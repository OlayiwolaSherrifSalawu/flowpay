import { describe, it } from 'node:test';
import assert from 'node:assert';
import { EmployeeService } from './service.js';

describe('Employee Management Validation & Lifecycle', () => {
  it('validates a valid Nigerian employee creation payload', () => {
    const result = EmployeeService.validateCreateInput({
      firstName: 'Bunch',
      lastName: 'Dillon',
      email: 'bunch.dillon@example.ng',
      country: 'NG',
      payrollAmountMinor: 310000000, // 3,100,000 NGN in kobo
    });

    assert.strictEqual(result.valid, true);
    assert.strictEqual(result.errors.length, 0);
  });

  it('validates a valid Mexican employee creation payload', () => {
    const result = EmployeeService.validateCreateInput({
      firstName: 'Samson',
      lastName: 'Jabo',
      email: 'samson.jabo@example.mx',
      country: 'MX',
      payrollAmountMinor: 3500000, // 35,000 MXN in centavos
    });

    assert.strictEqual(result.valid, true);
    assert.strictEqual(result.errors.length, 0);
  });

  it('rejects invalid email formats', () => {
    const result = EmployeeService.validateCreateInput({
      firstName: 'Test',
      lastName: 'User',
      email: 'invalid-email-no-domain',
      country: 'NG',
      payrollAmountMinor: 100000,
    });

    assert.strictEqual(result.valid, false);
    assert.ok(result.errors.some((e) => e.includes('valid email')));
  });

  it('rejects missing or empty names', () => {
    const result = EmployeeService.validateCreateInput({
      firstName: '',
      lastName: '   ',
      email: 'test@example.com',
      country: 'NG',
      payrollAmountMinor: 100000,
    });

    assert.strictEqual(result.valid, false);
    assert.ok(result.errors.some((e) => e.includes('firstName')));
    assert.ok(result.errors.some((e) => e.includes('lastName')));
  });

  it('rejects unsupported countries', () => {
    const result = EmployeeService.validateCreateInput({
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      country: 'XX',
      payrollAmountMinor: 100000,
    });

    assert.strictEqual(result.valid, false);
    assert.ok(result.errors.some((e) => e.includes('country must be one of')));
  });

  it('rejects non-positive or non-integer payroll amounts', () => {
    const zeroResult = EmployeeService.validateCreateInput({
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      country: 'NG',
      payrollAmountMinor: 0,
    });
    assert.strictEqual(zeroResult.valid, false);

    const negativeResult = EmployeeService.validateCreateInput({
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      country: 'NG',
      payrollAmountMinor: -5000,
    });
    assert.strictEqual(negativeResult.valid, false);

    const floatResult = EmployeeService.validateCreateInput({
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      country: 'NG',
      payrollAmountMinor: 123.45 as any,
    });
    assert.strictEqual(floatResult.valid, false);
  });

  it('resolves correct settlement currency for countries', () => {
    assert.strictEqual(EmployeeService.resolveCurrency('NG'), 'NGN');
    assert.strictEqual(EmployeeService.resolveCurrency('MX'), 'MXN');
    assert.strictEqual(EmployeeService.resolveCurrency('CA'), 'CAD');
    assert.strictEqual(EmployeeService.resolveCurrency('US'), 'USD');
  });

  it('rejects and sets status FAILED with null bmoniUserId when BMONI user creation fails', async () => {
    const { bmoniClient } = await import('../../bmoni/client.js');
    const { prisma, isPostgresDb } = await import('../../db/index.js');
    const { FlowPayError } = await import('../../core/errors.js');

    const originalCreate = bmoniClient.createEmployeeUser;
    bmoniClient.createEmployeeUser = async () => {
      throw new Error('BMONI connection timeout (504)');
    };

    let createdRecordId: string | undefined;
    try {
      await assert.rejects(
        async () => {
          await EmployeeService.createEmployee({
            firstName: 'TestFail',
            lastName: 'User',
            email: 'fail-test@example.com',
            country: 'NG',
            payrollAmountMinor: 100000,
          });
        },
        FlowPayError,
        'createEmployee must throw FlowPayError / BmoniUnavailableError on failure'
      );

      if (isPostgresDb()) {
        const record = await prisma.employee.findFirst({
          where: { email: 'fail-test@example.com' },
        });
        assert.ok(record, 'Employee record should be persisted for audit tracking');
        createdRecordId = record.id;
        assert.strictEqual(record.status, 'FAILED');
        assert.strictEqual(record.failedStage, 'BMONI_USER_CREATION');
        assert.strictEqual(record.bmoniUserId, null, 'Must never assign a fake bmoniUserId');
      }
    } finally {
      bmoniClient.createEmployeeUser = originalCreate;
      if (createdRecordId && isPostgresDb()) {
        await prisma.employee.delete({ where: { id: createdRecordId } }).catch(() => {});
      }
    }
  });

  it('succeeds and records real bmoniUserId when BMONI user creation succeeds', async () => {
    const { bmoniClient } = await import('../../bmoni/client.js');
    const { prisma, isPostgresDb } = await import('../../db/index.js');

    const originalCreate = bmoniClient.createEmployeeUser;
    bmoniClient.createEmployeeUser = async () => {
      return {
        id: 'usr_real_bmoni_99999',
        bmoniUserId: 'usr_real_bmoni_99999',
        firstName: 'TestSuccess',
        lastName: 'User',
        email: 'success-test@example.com',
        partnerId: 'part_flowpay_01',
        createdAt: new Date().toISOString(),
      };
    };

    let createdRecordId: string | undefined;
    try {
      const result = await EmployeeService.createEmployee({
        firstName: 'TestSuccess',
        lastName: 'User',
        email: 'success-test@example.com',
        country: 'NG',
        payrollAmountMinor: 100000,
      });

      assert.strictEqual(result.bmoniUserId, 'usr_real_bmoni_99999');
      assert.strictEqual(result.employee.status, 'CREATED');
      assert.strictEqual(result.employee.bmoniUserId, 'usr_real_bmoni_99999');
      createdRecordId = result.employee.id;
    } finally {
      bmoniClient.createEmployeeUser = originalCreate;
      if (createdRecordId && isPostgresDb()) {
        await prisma.employee.delete({ where: { id: createdRecordId } }).catch(() => {});
      }
    }
  });
});
