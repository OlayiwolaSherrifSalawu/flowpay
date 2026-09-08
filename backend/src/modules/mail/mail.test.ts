import test from 'node:test';
import assert from 'node:assert';
import {
  buildOtpEmail,
  buildWelcomeEmail,
  buildEmployeeInviteEmail,
  buildPayrollReceiptEmail,
  buildTransferReceiptEmail,
  buildSecurityAlertEmail,
  wrapBaseTemplate,
} from './templates.js';
import { MailService, mailService } from './service.js';
import { env } from '../../config/env.js';

test('Mail Templates - wrapBaseTemplate injects title, preheader, and branding', () => {
  const html = wrapBaseTemplate({
    title: 'Test Email',
    preheader: 'This is a test preheader',
    contentHtml: '<p>Hello FlowPay</p>',
  });

  assert.ok(html.includes('Test Email'));
  assert.ok(html.includes('This is a test preheader'));
  assert.ok(html.includes('Hello FlowPay'));
  assert.ok(html.includes('FlowPay Technologies Ltd'));
});

test('Mail Templates - buildOtpEmail generates secure OTP email', () => {
  const email = buildOtpEmail({
    to: 'user@example.com',
    recipientName: 'Waffiyyi',
    code: '849201',
    expiryMinutes: 5,
    actionDescription: 'PIN authorization',
  });

  assert.strictEqual(email.subject, 'Your FlowPay Verification Code: 849201');
  assert.ok(email.html.includes('849201'));
  assert.ok(email.html.includes('5 minutes'));
  assert.ok(email.html.includes('PIN authorization'));
  assert.ok(email.text.includes('849201'));
});

test('Mail Templates - buildWelcomeEmail generates onboarding email', () => {
  const email = buildWelcomeEmail({
    to: 'founder@example.com',
    recipientName: 'Alex',
    accountType: 'business',
    dashboardUrl: 'https://app.flowpay.finance/dashboard',
  });

  assert.ok(email.subject.includes('Welcome to FlowPay'));
  assert.ok(email.html.includes('Business Organization'));
  assert.ok(email.html.includes('Alex'));
  assert.ok(email.html.includes('https://app.flowpay.finance/dashboard'));
});

test('Mail Templates - buildEmployeeInviteEmail generates payroll invite', () => {
  const email = buildEmployeeInviteEmail({
    to: 'bunch@example.ng',
    recipientName: 'Bunch Dillon',
    companyName: 'Acme Global Ltd',
    country: 'NG',
    currency: 'NGN',
    payrollAmount: '850000',
    inviteUrl: 'https://bmoni.com/invite/flowpay_123',
  });

  assert.ok(email.subject.includes('Acme Global Ltd'));
  assert.ok(email.html.includes('Bunch Dillon'));
  assert.ok(email.html.includes('850000 NGN'));
  assert.ok(email.html.includes('https://bmoni.com/invite/flowpay_123'));
});

test('Mail Templates - buildPayrollReceiptEmail formats receipt correctly', () => {
  const email = buildPayrollReceiptEmail({
    to: 'samson@example.mx',
    recipientName: 'Samson Jabo',
    amount: '18500.00',
    currency: 'MXN',
    companyName: 'Acme LatAm',
    txHash: '0x3a4b5c6d7e8f90123456789abcdef0123456789a',
  });

  assert.strictEqual(email.subject, 'Payroll Disbursement Confirmed: 18500.00 MXN');
  assert.ok(email.html.includes('18500.00'));
  assert.ok(email.html.includes('MXN'));
  assert.ok(email.html.includes('Samson Jabo'));
  assert.ok(email.html.includes('Acme LatAm'));
});

test('Mail Templates - buildTransferReceiptEmail handles SENT and RECEIVED flows', () => {
  const sent = buildTransferReceiptEmail({
    to: 'alice@flowpay.test',
    recipientName: 'Alice',
    recipientEmail: 'bob@flowpay.test',
    amount: '250.00',
    currency: 'USDB',
    type: 'SENT',
  });
  assert.strictEqual(sent.subject, 'Transfer Sent: 250.00 USDB');
  assert.ok(sent.html.includes('-250.00'));

  const received = buildTransferReceiptEmail({
    to: 'bob@flowpay.test',
    recipientName: 'Bob',
    senderName: 'Alice',
    amount: '250.00',
    currency: 'USDB',
    type: 'RECEIVED',
  });
  assert.strictEqual(received.subject, 'Transfer Received: 250.00 USDB');
  assert.ok(received.html.includes('+250.00'));
});

test('Mail Templates - buildSecurityAlertEmail formats high-priority alert', () => {
  const alert = buildSecurityAlertEmail({
    to: 'user@flowpay.test',
    recipientName: 'Waffiyyi',
    action: 'New device login from Lagos, Nigeria',
    device: 'iPhone 15 Pro (iOS 17.5)',
    ipAddress: '102.89.23.14',
  });

  assert.ok(alert.subject.includes('Security Alert'));
  assert.ok(alert.html.includes('New device login'));
  assert.ok(alert.html.includes('iPhone 15 Pro'));
  assert.ok(alert.html.includes('102.89.23.14'));
});

test('MailService - singleton and environment initialization', () => {
  const instance1 = MailService.getInstance();
  const instance2 = MailService.getInstance();

  assert.strictEqual(instance1, instance2);
  assert.strictEqual(instance1, mailService);

  // Assert environment values are correctly mapped
  assert.strictEqual(env.SMTP_HOST, 'smtp.gmail.com');
  assert.strictEqual(env.SMTP_PORT, 587);
  assert.strictEqual(env.SMTP_USER, 'fwaffiyyi@gmail.com');
  assert.ok(typeof env.SMTP_PASS === 'string');
});
