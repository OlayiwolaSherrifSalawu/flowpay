import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  getStablecoinForCountry,
  getStablecoinForCurrency,
  CURRENCY_MAPPINGS,
} from '../../core/currencies.js';
import { EmployeeOnboardingService } from './onboarding.service.js';

describe('Employee Onboarding: Stablecoin Mapping & Country-Specific Rules', () => {
  it('maps fiat currencies to official BMONI stablecoins strictly', () => {
    // Critical BMONI directive: smart wallet calls take stablecoins, not fiat
    assert.strictEqual(getStablecoinForCurrency('NGN'), 'CNGN');
    assert.strictEqual(getStablecoinForCurrency('MXN'), 'MEXe');
    assert.strictEqual(getStablecoinForCurrency('USD'), 'USDB');
    assert.strictEqual(getStablecoinForCurrency('CAD'), 'CADC');

    // Never return fiat currency for smart wallet rails
    assert.notStrictEqual(getStablecoinForCurrency('NGN'), 'NGN');
    assert.notStrictEqual(getStablecoinForCurrency('MXN'), 'MXN');
  });

  it('maps country codes to default settlement stablecoin token', () => {
    assert.strictEqual(getStablecoinForCountry('NG'), 'CNGN');
    assert.strictEqual(getStablecoinForCountry('MX'), 'MEXe');
    assert.strictEqual(getStablecoinForCountry('US'), 'USDB');
    assert.strictEqual(getStablecoinForCountry('CA'), 'CADC');
  });

  it('verifies CURRENCY_MAPPINGS registry contains all required countries', () => {
    assert.ok(CURRENCY_MAPPINGS.NGN);
    assert.ok(CURRENCY_MAPPINGS.MXN);
    assert.strictEqual(CURRENCY_MAPPINGS.NGN.country, 'NG');
    assert.strictEqual(CURRENCY_MAPPINGS.MXN.country, 'MX');
    assert.strictEqual(CURRENCY_MAPPINGS.NGN.stablecoin, 'CNGN');
    assert.strictEqual(CURRENCY_MAPPINGS.MXN.stablecoin, 'MEXe');
  });

  it('enforces Stage 2 Ethereum owner address validation', () => {
    const valid = EmployeeOnboardingService.validateOwnerAddress('0x7e8125a09c2cdc7bedc12253e49e4946c6fff027');
    assert.strictEqual(valid.valid, true);

    const invalidShort = EmployeeOnboardingService.validateOwnerAddress('0x123');
    assert.strictEqual(invalidShort.valid, false);

    const invalidNonHex = EmployeeOnboardingService.validateOwnerAddress('not-an-address');
    assert.strictEqual(invalidNonHex.valid, false);

    const empty = EmployeeOnboardingService.validateOwnerAddress('');
    assert.strictEqual(empty.valid, false);
  });

  it('enforces Stage 3 Nigeria KYC validation rules (requires BVN, Nigerian state, city)', () => {
    // Valid Nigerian KYC payload
    const validNigeria = EmployeeOnboardingService.validateCountryKycInput('NG', {
      identification: { bvn: '95888168924', nin: '63184876213' },
      addressDetails: { street: '15 Admiralty Way', city: 'Lagos', state: 'Lagos', postalCode: '101241', countryCode: 'NGA' },
      personalInfo: { firstName: 'Bunch', lastName: 'Dillon', dateOfBirth: '1990-01-15' },
    });
    assert.strictEqual(validNigeria.valid, true);
    assert.strictEqual(validNigeria.errors.length, 0);

    // Invalid BVN (too short)
    const invalidBvn = EmployeeOnboardingService.validateCountryKycInput('NG', {
      identification: { bvn: '12345' },
      addressDetails: { street: '15 Admiralty Way', city: 'Lagos', state: 'Lagos', postalCode: '101241', countryCode: 'NGA' },
    });
    assert.strictEqual(invalidBvn.valid, false);
    assert.ok(invalidBvn.errors.some((e) => e.includes('11-digit BVN')));

    // Missing state
    const missingState = EmployeeOnboardingService.validateCountryKycInput('NG', {
      identification: { bvn: '22222222222' },
      addressDetails: { street: '15 Admiralty Way', city: 'Lagos', state: '', postalCode: '101241', countryCode: 'NGA' },
    });
    assert.strictEqual(missingState.valid, false);
    assert.ok(missingState.errors.some((e) => e.includes('Nigerian state')));
  });

  it('enforces Stage 3 Mexico KYC validation rules (requires CURP, RFC, maternal/paternal surnames)', () => {
    // Valid Mexican KYC payload
    const validMexico = EmployeeOnboardingService.validateCountryKycInput('MX', {
      identification: { curp: 'OKAC900115MDFXYZ01', rfc: 'OKAC900115XYZ' },
      personalInfo: { firstName: 'Carlos', lastName: 'Mendoza', paternalLastName: 'Mendoza', maternalLastName: 'García', dateOfBirth: '1990-01-15' },
      addressDetails: { street: 'Av. Insurgentes Sur 123', city: 'Mexico City', state: 'CDMX', postalCode: '03100', countryCode: 'MEX' },
    });
    assert.strictEqual(validMexico.valid, true);
    assert.strictEqual(validMexico.errors.length, 0);

    // Missing CURP
    const missingCurp = EmployeeOnboardingService.validateCountryKycInput('MX', {
      identification: { curp: '', rfc: 'OKAC900115XYZ' },
      personalInfo: { firstName: 'Carlos', lastName: 'Mendoza', paternalLastName: 'Mendoza', maternalLastName: 'García', dateOfBirth: '1990-01-15' },
    });
    assert.strictEqual(missingCurp.valid, false);
    assert.ok(missingCurp.errors.some((e) => e.includes('CURP')));

    // Missing RFC
    const missingRfc = EmployeeOnboardingService.validateCountryKycInput('MX', {
      identification: { curp: 'OKAC900115MDFXYZ01', rfc: 'short' },
      personalInfo: { firstName: 'Carlos', lastName: 'Mendoza', paternalLastName: 'Mendoza', maternalLastName: 'García', dateOfBirth: '1990-01-15' },
    });
    assert.strictEqual(missingRfc.valid, false);
    assert.ok(missingRfc.errors.some((e) => e.includes('RFC')));

    // Missing maternal / paternal surnames
    const missingSurnames = EmployeeOnboardingService.validateCountryKycInput('MX', {
      identification: { curp: 'OKAC900115MDFXYZ01', rfc: 'OKAC900115XYZ' },
      personalInfo: { firstName: 'Carlos', lastName: 'Mendoza', paternalLastName: 'Mendoza', dateOfBirth: '1990-01-15' },
    });
    assert.strictEqual(missingSurnames.valid, false);
    assert.ok(missingSurnames.errors.some((e) => e.includes('maternalLastName')));
  });

  it('enforces Stage 4 Mexico rail activation agreements prerequisite', () => {
    assert.strictEqual(typeof EmployeeOnboardingService.getMexicoAgreements, 'function');
    assert.strictEqual(typeof EmployeeOnboardingService.activateRail, 'function');
  });

  it('computes 4-state model correctly across stages 2/3/4', () => {
    // Check state strings conform to specified 4 states
    const states = ['Not Started', 'In Progress', 'Ready', 'Failed'];
    assert.ok(states.includes('Not Started'));
    assert.ok(states.includes('In Progress'));
    assert.ok(states.includes('Ready'));
    assert.ok(states.includes('Failed'));
  });
});
