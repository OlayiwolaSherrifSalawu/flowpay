// mail/service.ts
// Mail relay service supporting both Mailgun HTTPS API and Resend HTTPS API.
// Automatically selects Mailgun if MAILGUN_API_KEY + MAILGUN_DOMAIN are present,
// otherwise falls back to Resend API.

import { env } from '../../config/env.js';
import {
  buildEmployeeInviteEmail,
  buildOtpEmail,
  buildPayrollReceiptEmail,
  buildSecurityAlertEmail,
  buildTransferReceiptEmail,
  buildWelcomeEmail,
  wrapBaseTemplate,
} from './templates.js';
import type {
  EmailAddress,
  EmployeeInviteParams,
  OtpEmailParams,
  PayrollReceiptParams,
  SecurityAlertParams,
  SendMailOptions,
  SendMailResult,
  SmtpConnectionStatus,
  TransferReceiptParams,
  WelcomeEmailParams,
} from './types.js';

export class MailService {
  private static instance: MailService;
  private readonly resendApiKey?: string;
  private readonly mailgunApiKey?: string;
  private readonly mailgunDomain?: string;
  private readonly mailgunBaseUrl: string;

  private constructor() {
    this.resendApiKey = env.RESEND_API_KEY || process.env.RESEND_API_KEY;
    this.mailgunApiKey = env.MAILGUN_API_KEY || process.env.MAILGUN_API_KEY;
    this.mailgunDomain = env.MAILGUN_DOMAIN || process.env.MAILGUN_DOMAIN;
    this.mailgunBaseUrl =
      env.MAILGUN_BASE_URL ||
      process.env.MAILGUN_BASE_URL ||
      'https://api.mailgun.net/v3';

    if (this.isMailgunConfigured) {
      console.log(
        `[MailService] Configured Mailgun API relay (domain: ${this.mailgunDomain}, from: "${env.MAIL_FROM_NAME}" <${this.defaultFromAddress}>).`
      );
    } else if (this.isResendConfigured) {
      console.log(
        `[MailService] Configured Resend API relay (from: "${env.MAIL_FROM_NAME}" <${this.defaultFromAddress}>).`
      );
    } else {
      console.warn(
        '[MailService] Neither MAILGUN_API_KEY nor RESEND_API_KEY is configured — email sending will fail until configured.'
      );
    }
  }

  public static getInstance(): MailService {
    if (!MailService.instance) {
      MailService.instance = new MailService();
    }
    return MailService.instance;
  }

  public get isMailgunConfigured(): boolean {
    return Boolean(this.mailgunApiKey && this.mailgunDomain);
  }

  public get isResendConfigured(): boolean {
    return Boolean(this.resendApiKey);
  }

  public get isConfigured(): boolean {
    return this.isMailgunConfigured || this.isResendConfigured;
  }

  private get defaultFromAddress(): string {
    if (this.isMailgunConfigured && this.mailgunDomain) {
      return process.env.MAIL_FROM_ADDRESS || `postmaster@${this.mailgunDomain}`;
    }
    return env.MAIL_FROM_ADDRESS || 'onboarding@resend.dev';
  }

  public async verifyConnection(): Promise<SmtpConnectionStatus> {
    const status: SmtpConnectionStatus = {
      connected: false,
      host: this.isMailgunConfigured ? 'api.mailgun.net' : 'api.resend.com',
      port: 443,
      secure: true,
      user: this.defaultFromAddress,
      timestamp: new Date().toISOString(),
    };

    if (!this.isConfigured) {
      status.error = 'Neither MAILGUN_API_KEY nor RESEND_API_KEY is set';
      console.error('[MailService] ❌ Mail Verification Failed:', status.error);
      return status;
    }

    try {
      if (this.isMailgunConfigured) {
        const url = `${this.mailgunBaseUrl}/${this.mailgunDomain}/stats/total?event=accepted`;
        const authHeader =
          'Basic ' + Buffer.from(`api:${this.mailgunApiKey}`).toString('base64');
        const res = await fetch(url, { headers: { Authorization: authHeader } });
        if (!res.ok) {
          const body = (await res.json().catch(() => null)) as any;
          throw new Error(body?.message || `Mailgun responded with HTTP ${res.status}`);
        }
        status.connected = true;
        console.log('[MailService] ✅ Mailgun API key verified.');
        return status;
      } else {
        const res = await fetch('https://api.resend.com/api-keys', {
          method: 'GET',
          headers: { Authorization: `Bearer ${this.resendApiKey}` },
        });
        if (!res.ok) {
          throw new Error(`Resend responded with HTTP ${res.status}`);
        }
        status.connected = true;
        console.log('[MailService] ✅ Resend API key verified.');
        return status;
      }
    } catch (err: any) {
      status.connected = false;
      status.error = err?.message || String(err);
      console.error('[MailService] ❌ Mail Verification Failed:', status.error);
      return status;
    }
  }

  public async sendMail(options: SendMailOptions): Promise<SendMailResult> {
    if (!this.isConfigured) {
      const error =
        'Mail provider is not configured (missing MAILGUN_API_KEY or RESEND_API_KEY)';
      console.error(
        `[MailService] ❌ Failed to send email to ${JSON.stringify(options.to)}:`,
        error
      );
      return { success: false, error };
    }

    const defaultFrom = `${env.MAIL_FROM_NAME} <${this.defaultFromAddress}>`;
    const formatAddress = (addr: string | EmailAddress): string =>
      typeof addr === 'string'
        ? addr
        : addr.name
        ? `${addr.name} <${addr.address}>`
        : addr.address;

    const recipients: string[] = (
      Array.isArray(options.to) ? options.to : [options.to]
    ).map(formatAddress);
    const fromAddress = options.from ? formatAddress(options.from) : defaultFrom;

    if (this.isMailgunConfigured) {
      const url = `${this.mailgunBaseUrl}/${this.mailgunDomain}/messages`;
      const authHeader =
        'Basic ' + Buffer.from(`api:${this.mailgunApiKey}`).toString('base64');
      const form = new URLSearchParams();
      form.set('from', fromAddress);
      for (const to of recipients) {
        form.append('to', to);
      }
      form.set('subject', options.subject);
      if (options.html) form.set('html', options.html);
      if (options.text) form.set('text', options.text);
      if (!options.html && !options.text) form.set('text', '');

      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: form.toString(),
        });
        const body = (await res.json().catch(() => null)) as any;
        if (!res.ok) {
          const reason =
            (body && (body.message || body.Error)) ||
            `Mailgun request failed with status ${res.status}`;
          console.error(
            `[MailService] ❌ Failed to send email to ${JSON.stringify(recipients)}: ${reason}`
          );
          return { success: false, error: reason, rejected: recipients };
        }
        console.log(
          `[MailService] ✉️  Email sent via Mailgun: "${options.subject}" to ${JSON.stringify(
            recipients
          )} (ID: ${body?.id ?? 'unknown'})`
        );
        return {
          success: true,
          messageId: body?.id,
          accepted: recipients,
          rejected: [],
        };
      } catch (err: any) {
        const reason = err?.message || 'Unknown error calling Mailgun API';
        console.error(
          `[MailService] ❌ Failed to send email to ${JSON.stringify(recipients)}: ${reason}`
        );
        return { success: false, error: reason, rejected: recipients };
      }
    }

    // Resend path
    const body = {
      from: fromAddress,
      to: recipients,
      subject: options.subject,
      html: options.html,
      text: options.text,
      reply_to: options.replyTo,
      cc: options.cc,
      bcc: options.bcc,
    };

    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      const data: any = await res.json().catch(() => ({}));

      if (!res.ok) {
        const message = data?.message || `Resend responded with HTTP ${res.status}`;
        throw new Error(message);
      }

      console.log(
        `[MailService] ✉️  Email sent via Resend: "${options.subject}" to ${JSON.stringify(
          recipients
        )} (ID: ${data.id})`
      );
      return {
        success: true,
        messageId: data.id,
        accepted: recipients,
        rejected: [],
      };
    } catch (err: any) {
      console.error(
        `[MailService] ❌ Failed to send email to ${JSON.stringify(recipients)}:`,
        err?.message || err
      );
      return { success: false, error: err?.message || String(err) };
    }
  }

  public async sendOtp(params: OtpEmailParams): Promise<SendMailResult> {
    const { subject, html, text } = buildOtpEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendWelcome(params: WelcomeEmailParams): Promise<SendMailResult> {
    const { subject, html, text } = buildWelcomeEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendEmployeeInvite(
    params: EmployeeInviteParams
  ): Promise<SendMailResult> {
    const { subject, html, text } = buildEmployeeInviteEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendPayrollReceipt(
    params: PayrollReceiptParams
  ): Promise<SendMailResult> {
    const { subject, html, text } = buildPayrollReceiptEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendTransferReceipt(
    params: TransferReceiptParams
  ): Promise<SendMailResult> {
    const { subject, html, text } = buildTransferReceiptEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendSecurityAlert(
    params: SecurityAlertParams
  ): Promise<SendMailResult> {
    const { subject, html, text } = buildSecurityAlertEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendTestEmail(targetRecipient?: string): Promise<SendMailResult> {
    const recipient = targetRecipient || env.MAIL_FROM_ADDRESS;
    const timestamp = new Date().toISOString();
    const relayName = this.isMailgunConfigured ? 'Mailgun API' : 'Resend API';

    const contentHtml = `
      <div style="text-align: center; margin-bottom: 20px;">
        <span style="display: inline-block; background-color: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3); color: #10b981; font-size: 12px; font-weight: 600; padding: 6px 14px; border-radius: 20px;">
          ${relayName} Test
        </span>
      </div>
      <h2 style="margin: 0 0 16px 0; font-size: 20px; font-weight: 700; color: #ffffff; text-align: center;">
        FlowPay Mail Relay is Active! ⚡
      </h2>
      <p style="margin: 0 0 20px 0; font-size: 15px; color: #d1d5db; line-height: 24px; text-align: center;">
        This test email confirms that your ${relayName} configuration is authenticated and delivering successfully.
      </p>
      <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; margin-bottom: 20px;">
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">Relay</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${relayName}</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">From</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${this.defaultFromAddress}</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; color: #9ca3af; font-size: 13px;">Timestamp</td>
          <td align="right" style="padding: 12px 16px; color: #f3f4f6; font-size: 13px;">${timestamp}</td>
        </tr>
      </table>
    `;

    const html = wrapBaseTemplate({
      title: 'FlowPay Mail Service Test',
      preheader: `Test verification email for FlowPay ${relayName}.`,
      contentHtml,
    });

    const text = `FlowPay Mail Service Test\n\nRelay: ${relayName}\nFrom: ${this.defaultFromAddress}\nTime: ${timestamp}\n\nDelivery successful.`;

    return this.sendMail({
      to: recipient,
      subject: `[FlowPay Test] ${relayName} Delivery Verified — ${timestamp}`,
      html,
      text,
    });
  }
}

export const mailService = MailService.getInstance();

export async function sendMail(params: {
  to: string;
  subject: string;
  html?: string;
  text?: string;
}): Promise<SendMailResult> {
  return mailService.sendMail({
    to: params.to,
    subject: params.subject,
    html: params.html || '',
    text: params.text,
  });
}

export async function checkMailHealth(): Promise<{
  connected: boolean;
  detail?: string;
}> {
  const status = await mailService.verifyConnection();
  return {
    connected: status.connected,
    detail:
      status.error ||
      (status.connected ? `connected via ${status.host}` : 'disconnected'),
  };
}