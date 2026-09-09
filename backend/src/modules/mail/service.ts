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

  private constructor() {
    this.transporter = this.createTransporter();
  }

  public static getInstance(): MailService {
    if (!MailService.instance) {
      MailService.instance = new MailService();
    }
    return MailService.instance;
  }

  /**
   * Initializes the Nodemailer SMTP transporter using the configured credentials.
   * Equivalent to Spring Boot:
   * spring.mail.host=smtp.gmail.com
   * spring.mail.port=587
   * spring.mail.username=fwaffiyyi@gmail.com
   * spring.mail.password=cujynpeeagqlmkpz
   * spring.mail.properties.mail.smtp.auth=true
   * spring.mail.properties.mail.smtp.starttls.enable=true
   */
  private createTransporter(): Transporter {
    const isGmail = env.SMTP_HOST.includes('gmail');

    const transportConfig: TransportOptions = {
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_SECURE, // false for port 587 (uses STARTTLS)
      requireTLS: true,
      family: 4,
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      auth: {
        user: env.SMTP_USER,
        pass: env.SMTP_PASS,
      },
      tls: {
        rejectUnauthorized: false,
      },
    } as any;

    if (isGmail && env.SMTP_PORT === 587) {
      console.log(`[MailService] Configured Gmail SMTP relay (${env.SMTP_HOST}:${env.SMTP_PORT}) with STARTTLS.`);
    } else {
      console.log(`[MailService] Configured SMTP host: ${env.SMTP_HOST}:${env.SMTP_PORT}`);
    }

    this.isConfigured = Boolean(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS);
    return nodemailer.createTransport(transportConfig);
  }

  /**
   * Verifies SMTP server handshake and credentials.
   */
  public async verifyConnection(): Promise<SmtpConnectionStatus> {
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
      console.log(`[MailService] ✅ SMTP Connection Verified: ${env.SMTP_HOST}:${env.SMTP_PORT} as ${env.SMTP_USER}`);
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
