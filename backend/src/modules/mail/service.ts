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

/**
 * Sends mail via Resend's HTTPS API instead of raw SMTP. Render (and many
 * free-tier cloud hosts) throttle or block outbound SMTP ports (25/465/587)
 * even when DNS/IPv4 resolution is correct, causing indefinite connection
 * timeouts that no amount of nodemailer configuration can fix — this is a
 * documented, common limitation, not a code bug. Resend sends over HTTPS
 * (port 443), which is never blocked, and requires no SMTP handshake at all.
 */
export class MailService {
  private static instance: MailService;
  private readonly apiKey: string;
  private readonly isConfigured: boolean;

  private constructor() {
    this.apiKey = env.RESEND_API_KEY;
    this.isConfigured = Boolean(this.apiKey);
    if (!this.isConfigured) {
      console.warn('[MailService] RESEND_API_KEY is not set — email sending will fail until it is configured.');
    } else {
      console.log(`[MailService] Configured Resend API relay (from: "${env.MAIL_FROM_NAME}" <${env.MAIL_FROM_ADDRESS}>).`);
    }
  }

  public static getInstance(): MailService {
    if (!MailService.instance) {
      MailService.instance = new MailService();
    }
    return MailService.instance;
  }

  /**
   * Checks that the Resend API key is present and accepted. There's no SMTP
   * handshake to verify anymore, so this makes a lightweight authenticated
   * request (listing API keys) purely to confirm the key itself is valid.
   */
  public async verifyConnection(): Promise<SmtpConnectionStatus> {
    const status: SmtpConnectionStatus = {
      connected: false,
      host: 'api.resend.com',
      port: 443,
      secure: true,
      user: env.MAIL_FROM_ADDRESS,
      timestamp: new Date().toISOString(),
    };

    if (!this.isConfigured) {
      status.error = 'RESEND_API_KEY is not set';
      console.error('[MailService] ❌ Resend Verification Failed:', status.error);
      return status;
    }

    try {
      const res = await fetch('https://api.resend.com/api-keys', {
        method: 'GET',
        headers: { Authorization: `Bearer ${this.apiKey}` },
      });
      if (!res.ok) {
        throw new Error(`Resend responded with HTTP ${res.status}`);
      }
      status.connected = true;
      console.log(`[MailService] ✅ Resend API key verified.`);
      return status;
    } catch (err: any) {
      status.connected = false;
      status.error = err.message || String(err);
      console.error('[MailService] ❌ Resend Verification Failed:', status.error);
      return status;
    }
  }

  /**
   * Sends an email with full options via Resend's HTTPS API.
   */
  public async sendMail(options: SendMailOptions): Promise<SendMailResult> {
    if (!this.isConfigured) {
      const error = 'RESEND_API_KEY is not set';
      console.error(`[MailService] ❌ Failed to send email to ${JSON.stringify(options.to)}:`, error);
      return { success: false, error };
    }

    const defaultFrom = `${env.MAIL_FROM_NAME} <${env.MAIL_FROM_ADDRESS}>`;
    const formatAddress = (addr: string | EmailAddress): string =>
      typeof addr === 'string' ? addr : addr.name ? `${addr.name} <${addr.address}>` : addr.address;

    const recipients: string[] = (Array.isArray(options.to) ? options.to : [options.to]).map(formatAddress);
    const fromAddress = options.from ? formatAddress(options.from) : defaultFrom;

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
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      const data: any = await res.json().catch(() => ({}));

      if (!res.ok) {
        const message = data?.message || `Resend responded with HTTP ${res.status}`;
        throw new Error(message);
      }

      console.log(`[MailService] ✉️  Email sent: "${options.subject}" to ${JSON.stringify(recipients)} (ID: ${data.id})`);
      return {
        success: true,
        messageId: data.id,
        accepted: recipients,
        rejected: [],
      };
    } catch (err: any) {
      console.error(`[MailService] ❌ Failed to send email to ${JSON.stringify(recipients)}:`, err.message || err);
      return { success: false, error: err.message || String(err) };
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

  public async sendEmployeeInvite(params: EmployeeInviteParams): Promise<SendMailResult> {
    const { subject, html, text } = buildEmployeeInviteEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendPayrollReceipt(params: PayrollReceiptParams): Promise<SendMailResult> {
    const { subject, html, text } = buildPayrollReceiptEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendTransferReceipt(params: TransferReceiptParams): Promise<SendMailResult> {
    const { subject, html, text } = buildTransferReceiptEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendSecurityAlert(params: SecurityAlertParams): Promise<SendMailResult> {
    const { subject, html, text } = buildSecurityAlertEmail(params);
    return this.sendMail({ to: params.to, subject, html, text });
  }

  public async sendTestEmail(targetRecipient?: string): Promise<SendMailResult> {
    const recipient = targetRecipient || env.MAIL_FROM_ADDRESS;
    const timestamp = new Date().toISOString();

    const contentHtml = `
      <div style="text-align: center; margin-bottom: 20px;">
        <span style="display: inline-block; background-color: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3); color: #10b981; font-size: 12px; font-weight: 600; padding: 6px 14px; border-radius: 20px;">
          Resend API Test
        </span>
      </div>
      <h2 style="margin: 0 0 16px 0; font-size: 20px; font-weight: 700; color: #ffffff; text-align: center;">
        FlowPay Mail Relay is Active! ⚡
      </h2>
      <p style="margin: 0 0 20px 0; font-size: 15px; color: #d1d5db; line-height: 24px; text-align: center;">
        This test email confirms that your Resend API configuration is authenticated and delivering successfully.
      </p>
      <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; margin-bottom: 20px;">
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">Relay</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">Resend API</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">From</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${env.MAIL_FROM_ADDRESS}</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; color: #9ca3af; font-size: 13px;">Timestamp</td>
          <td align="right" style="padding: 12px 16px; color: #f3f4f6; font-size: 13px;">${timestamp}</td>
        </tr>
      </table>
    `;

    const html = wrapBaseTemplate({
      title: 'FlowPay Mail Service Test',
      preheader: 'Test verification email for FlowPay Resend relay.',
      contentHtml,
    });

    const text = `FlowPay Mail Service Test\n\nRelay: Resend API\nFrom: ${env.MAIL_FROM_ADDRESS}\nTime: ${timestamp}\n\nDelivery successful.`;

    return this.sendMail({
      to: recipient,
      subject: `[FlowPay Test] Resend Delivery Verified — ${timestamp}`,
      html,
      text,
    });
  }
}

export const mailService = MailService.getInstance();