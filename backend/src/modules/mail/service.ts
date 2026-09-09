import dns from 'node:dns';
import nodemailer, { type Transporter, type TransportOptions } from 'nodemailer';
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
  private transporter: Transporter;
  private isConfigured: boolean = false;
  private currentHost: string = env.SMTP_HOST;
  private lastDnsLookupTime: number = 0;
  private dnsLookupPromise: Promise<void> | null = null;
  private static readonly DNS_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

  private constructor() {
    this.currentHost = env.SMTP_HOST;
    this.transporter = this.createTransporter(env.SMTP_HOST);
    // Kick off async IPv4 DNS resolution immediately in background
    this.ensureTransporter().catch((err) => {
      console.warn('[MailService] Initial async IPv4 DNS resolution warning:', err?.message || err);
    });
  }

  public static getInstance(): MailService {
    if (!MailService.instance) {
      MailService.instance = new MailService();
    }
    return MailService.instance;
  }

  /**
   * Resolves the SMTP host to an IPv4 address using Node's dns.promises.lookup with family: 4.
   * If lookup fails (DNS issue, no A record), falls back to the original hostname.
   */
  private async resolveIpv4Address(hostname: string): Promise<string> {
    try {
      const { address } = await dns.promises.lookup(hostname, { family: 4 });
      if (address) {
        return address;
      }
    } catch (err: any) {
      console.warn(
        `[MailService] DNS IPv4 lookup failed for "${hostname}", falling back to hostname:`,
        err?.message || String(err)
      );
    }
    return hostname;
  }

  /**
   * Initializes the Nodemailer SMTP transporter using the configured credentials.
   * Connects to targetHost (an IPv4 address when resolved, or env.SMTP_HOST as fallback)
   * while setting tls.servername to env.SMTP_HOST for SNI/TLS certificate validation.
   */
  private createTransporter(targetHost: string = env.SMTP_HOST): Transporter {
    const isGmail = env.SMTP_HOST.includes('gmail');

    const transportConfig: TransportOptions = {
      host: targetHost,
      port: env.SMTP_PORT,
      secure: env.SMTP_SECURE, // false for port 587 (uses STARTTLS)
      requireTLS: true,
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      auth: {
        user: env.SMTP_USER,
        pass: env.SMTP_PASS,
      },
      tls: {
        servername: env.SMTP_HOST,
        rejectUnauthorized: false,
      },
    } as any;

    if (isGmail && env.SMTP_PORT === 587) {
      console.log(
        `[MailService] Configured Gmail SMTP relay (${targetHost}:${env.SMTP_PORT}, SNI: ${env.SMTP_HOST}) with STARTTLS.`
      );
    } else {
      console.log(`[MailService] Configured SMTP host: ${targetHost}:${env.SMTP_PORT} (SNI: ${env.SMTP_HOST})`);
    }

    this.isConfigured = Boolean(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS);
    return nodemailer.createTransport(transportConfig);
  }

  /**
   * Ensures the transporter has a fresh IPv4 connection target, caching the resolved IP
   * for 5 minutes (DNS_CACHE_TTL_MS) to pick up DNS updates while preventing redundant lookups.
   */
  private async ensureTransporter(): Promise<Transporter> {
    const now = Date.now();
    const isExpired = now - this.lastDnsLookupTime > MailService.DNS_CACHE_TTL_MS;

    if (isExpired) {
      if (!this.dnsLookupPromise) {
        this.dnsLookupPromise = (async () => {
          const resolvedIp = await this.resolveIpv4Address(env.SMTP_HOST);
          if (resolvedIp !== this.currentHost || !this.transporter) {
            this.currentHost = resolvedIp;
            this.transporter = this.createTransporter(resolvedIp);
            console.log(`[MailService] Updated SMTP transporter host to IPv4: ${resolvedIp}`);
          }
          this.lastDnsLookupTime = Date.now();
        })().finally(() => {
          this.dnsLookupPromise = null;
        });
      }
      await this.dnsLookupPromise;
    } else if (this.dnsLookupPromise) {
      await this.dnsLookupPromise;
    }

    return this.transporter;
  }

  /**
   * Verifies SMTP server handshake and credentials.
   */
  public async verifyConnection(): Promise<SmtpConnectionStatus> {
    await this.ensureTransporter();

    const status: SmtpConnectionStatus = {
      connected: false,
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_SECURE,
      user: env.SMTP_USER,
      timestamp: new Date().toISOString(),
    };

    try {
      await this.transporter.verify();
      status.connected = true;
      console.log(
        `[MailService] ✅ SMTP Connection Verified: ${this.currentHost}:${env.SMTP_PORT} (SNI: ${env.SMTP_HOST}) as ${env.SMTP_USER}`
      );
      return status;
    } catch (err: any) {
      status.connected = false;
      status.error = err.message || String(err);
      console.error(`[MailService] ❌ SMTP Verification Failed:`, status.error);
      return status;
    }
  }

  /**
   * Sends an email with full options.
   */
  public async sendMail(options: SendMailOptions): Promise<SendMailResult> {
    const defaultFrom = `"${env.MAIL_FROM_NAME}" <${env.MAIL_FROM_ADDRESS}>`;

    const mailOptions = {
      from: options.from || defaultFrom,
      to: options.to,
      subject: options.subject,
      html: options.html,
      text: options.text,
      replyTo: options.replyTo,
      cc: options.cc,
      bcc: options.bcc,
      attachments: options.attachments,
    };

    try {
      await this.ensureTransporter();
      const info = await this.transporter.sendMail(mailOptions);
      console.log(`[MailService] ✉️  Email sent: "${options.subject}" to ${JSON.stringify(options.to)} (ID: ${info.messageId})`);

      return {
        success: true,
        messageId: info.messageId,
        accepted: (info.accepted as string[]) || [],
        rejected: (info.rejected as string[]) || [],
      };
    } catch (err: any) {
      console.error(`[MailService] ❌ Failed to send email to ${JSON.stringify(options.to)}:`, err.message || err);
      return {
        success: false,
        error: err.message || String(err),
      };
    }
  }

  /**
   * Send One-Time Verification Code (OTP)
   */
  public async sendOtp(params: OtpEmailParams): Promise<SendMailResult> {
    const { subject, html, text } = buildOtpEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send Welcome Email
   */
  public async sendWelcome(params: WelcomeEmailParams): Promise<SendMailResult> {
    const { subject, html, text } = buildWelcomeEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send Employee Invitation for Global Payroll
   */
  public async sendEmployeeInvite(params: EmployeeInviteParams): Promise<SendMailResult> {
    const { subject, html, text } = buildEmployeeInviteEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send Payroll Disbursement Receipt
   */
  public async sendPayrollReceipt(params: PayrollReceiptParams): Promise<SendMailResult> {
    const { subject, html, text } = buildPayrollReceiptEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send Transfer Receipt / Notification
   */
  public async sendTransferReceipt(params: TransferReceiptParams): Promise<SendMailResult> {
    const { subject, html, text } = buildTransferReceiptEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Send Critical Security Alert
   */
  public async sendSecurityAlert(params: SecurityAlertParams): Promise<SendMailResult> {
    const { subject, html, text } = buildSecurityAlertEmail(params);
    return this.sendMail({
      to: params.to,
      subject,
      html,
      text,
    });
  }

  /**
   * Sends a test diagnostic email to verify end-to-end SMTP deliverability.
   */
  public async sendTestEmail(targetRecipient?: string): Promise<SendMailResult> {
    const recipient = targetRecipient || env.SMTP_USER;
    const timestamp = new Date().toISOString();

    const contentHtml = `
      <div style="text-align: center; margin-bottom: 20px;">
        <span style="display: inline-block; background-color: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3); color: #10b981; font-size: 12px; font-weight: 600; padding: 6px 14px; border-radius: 20px;">
          SMTP Test Diagnostic
        </span>
      </div>
      <h2 style="margin: 0 0 16px 0; font-size: 20px; font-weight: 700; color: #ffffff; text-align: center;">
        FlowPay Mail Relay is Active! ⚡
      </h2>
      <p style="margin: 0 0 20px 0; font-size: 15px; color: #d1d5db; line-height: 24px; text-align: center;">
        This test email confirms that your Node.js Gmail SMTP configuration has connected, authenticated, and delivered successfully.
      </p>

      <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; margin-bottom: 20px;">
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">Host</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${env.SMTP_HOST}</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">Port</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${env.SMTP_PORT} (STARTTLS)</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #9ca3af; font-size: 13px;">Authenticated User</td>
          <td align="right" style="padding: 12px 16px; border-bottom: 1px solid #374151; color: #f3f4f6; font-size: 13px; font-family: monospace;">${env.SMTP_USER}</td>
        </tr>
        <tr>
          <td style="padding: 12px 16px; color: #9ca3af; font-size: 13px;">Timestamp</td>
          <td align="right" style="padding: 12px 16px; color: #f3f4f6; font-size: 13px;">${timestamp}</td>
        </tr>
      </table>
    `;

    const html = wrapBaseTemplate({
      title: 'FlowPay Mail Service Test',
      preheader: 'Test verification email for FlowPay Node.js backend relay.',
      contentHtml,
    });

    const text = `FlowPay Mail Service Test\n\nHost: ${env.SMTP_HOST}\nPort: ${env.SMTP_PORT}\nUser: ${env.SMTP_USER}\nTime: ${timestamp}\n\nDelivery successful.`;

    return this.sendMail({
      to: recipient,
      subject: `[FlowPay Test] SMTP Delivery Verified — ${timestamp}`,
      html,
      text,
    });
  }
}

export const mailService = MailService.getInstance();
