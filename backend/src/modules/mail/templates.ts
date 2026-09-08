import type {
  EmployeeInviteParams,
  OtpEmailParams,
  PayrollReceiptParams,
  SecurityAlertParams,
  TransferReceiptParams,
  WelcomeEmailParams,
} from './types.js';

/**
 * Base email layout wrapper with modern, dark-mode fintech FlowPay styling.
 * Table-based HTML structure for maximum cross-client deliverability (Gmail, Outlook, Apple Mail).
 */
export function wrapBaseTemplate(options: {
  title: string;
  preheader?: string;
  contentHtml: string;
}): string {
  const currentYear = new Date().getFullYear();
  const preheaderHtml = options.preheader
    ? `<div style="display:none;font-size:1px;color:#333333;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">${options.preheader}</div>`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${options.title}</title>
  <style>
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; }
      .mobile-padding { padding-left: 20px !important; padding-right: 20px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; background-color: #0b0f19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #f3f4f6;">
  ${preheaderHtml}
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #0b0f19;">
    <tr>
      <td align="center" style="padding: 40px 15px;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="560" class="container" style="max-width: 560px; width: 100%; background-color: #111827; border: 1px solid #1f2937; border-radius: 16px; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);">
          
          <!-- Header Bar -->
          <tr>
            <td style="padding: 32px 36px 20px 36px; border-bottom: 1px solid #1f2937; background: linear-gradient(180deg, #161e2e 0%, #111827 100%);" class="mobile-padding">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td>
                    <div style="font-size: 24px; font-weight: 800; letter-spacing: -0.5px; color: #ffffff;">
                      <span style="color: #6366f1;">Flow</span>Pay
                    </div>
                    <div style="font-size: 11px; color: #9ca3af; text-transform: uppercase; letter-spacing: 1.5px; margin-top: 4px;">
                      Autonomous Financial Operating Layer
                    </div>
                  </td>
                  <td align="right">
                    <span style="display: inline-block; background-color: rgba(99, 102, 241, 0.15); border: 1px solid rgba(99, 102, 241, 0.3); color: #818cf8; font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 20px;">
                      Verified Relay
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content Body -->
          <tr>
            <td style="padding: 36px;" class="mobile-padding">
              ${options.contentHtml}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 36px; background-color: #0b0f19; border-top: 1px solid #1f2937; text-align: center; color: #6b7280; font-size: 12px; line-height: 18px;" class="mobile-padding">
              <p style="margin: 0 0 8px 0; color: #9ca3af; font-weight: 500;">
                FlowPay Financial Infrastructure &bull; Powered by BMONI Rails
              </p>
              <p style="margin: 0 0 8px 0;">
                This is an automated notification sent to your registered FlowPay email address. Never share your 6-digit B-Key wallet PIN or one-time codes with anyone.
              </p>
              <p style="margin: 0; color: #4b5563;">
                &copy; ${currentYear} FlowPay Technologies Ltd. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * OTP / One-Time Verification Code Email
 */
export function buildOtpEmail(params: OtpEmailParams): {
  subject: string;
  html: string;
  text: string;
} {
  const expiry = params.expiryMinutes || 10;
  const greeting = params.recipientName ? `Hi ${params.recipientName},` : 'Hello,';
  const action = params.actionDescription || 'your verification request';
  const subject = `Your FlowPay Verification Code: ${params.code}`;

  const contentHtml = `
    <h2 style="margin: 0 0 16px 0; font-size: 20px; font-weight: 700; color: #ffffff;">
      Verification Code
    </h2>
    <p style="margin: 0 0 24px 0; font-size: 15px; color: #d1d5db; line-height: 24px;">
      ${greeting} Use the single-use code below to complete ${action}. This code expires in <strong>${expiry} minutes</strong>.
    </p>

    <!-- Code Block -->
    <div style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; padding: 24px; text-align: center; margin: 0 0 28px 0;">
      <span style="font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #10b981; display: inline-block;">
        ${params.code}
      </span>
    </div>

    <div style="background-color: rgba(239, 68, 68, 0.1); border-left: 3px solid #ef4444; padding: 12px 16px; border-radius: 4px; margin-bottom: 24px;">
      <p style="margin: 0; font-size: 13px; color: #fca5a5; line-height: 18px;">
        <strong>Security Warning:</strong> FlowPay will never ask for this code via phone, chat, or direct message. If you did not initiate this request, ignore this email.
      </p>
    </div>
  `;

  const html = wrapBaseTemplate({
    title: 'FlowPay Security Verification',
    preheader: `Your one-time code is ${params.code}. Valid for ${expiry} minutes.`,
    contentHtml,
  });

  const text = `${greeting}\n\nYour FlowPay verification code is: ${params.code}\n\nValid for ${expiry} minutes to complete ${action}.\n\nDo not share this code with anyone.\n\nFlowPay Security`;

  return { subject, html, text };
}

/**
 * Welcome Email for New Personal / Business Accounts
 */
export function buildWelcomeEmail(params: WelcomeEmailParams): {
  subject: string;
  html: string;
  text: string;
} {
  const accountTypeLabel =
    params.accountType === 'business'
      ? 'Business Organization'
      : params.accountType === 'both'
      ? 'Personal & Business'
      : 'Personal Account';

  const subject = `Welcome to FlowPay — Autonomous Financial Operating Layer`;

  const contentHtml = `
    <h2 style="margin: 0 0 16px 0; font-size: 22px; font-weight: 700; color: #ffffff;">
      Welcome aboard, ${params.recipientName}! 🚀
    </h2>
    <p style="margin: 0 0 20px 0; font-size: 15px; color: #d1d5db; line-height: 24px;">
      Your FlowPay <strong>${accountTypeLabel}</strong> is ready. FlowPay bridges multi-currency smart wallets with autonomous AI execution and frictionless cross-border BMONI rails.
    </p>

    <div style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; padding: 20px; margin-bottom: 28px;">
      <div style="font-size: 14px; font-weight: 600; color: #e5e7eb; margin-bottom: 12px;">
        Key Capabilities Activated:
      </div>
      <ul style="margin: 0; padding-left: 20px; color: #9ca3af; font-size: 14px; line-height: 22px;">
        <li><strong style="color: #f3f4f6;">Hardware-Protected B-Key Wallets:</strong> Multi-currency smart wallets with zero seed phrase friction.</li>
        <li><strong style="color: #f3f4f6;">Autonomous Money Missions:</strong> Auto-split international income, protect tax reserves, and save in USD stablecoins.</li>
        <li><strong style="color: #f3f4f6;">One-Click Global Payroll:</strong> Pay remote workers across Nigeria &amp; Mexico with one aggregate bill.</li>
        <li><strong style="color: #f3f4f6;">Instant Virtual Cards:</strong> Provision local or international spend cards on demand.</li>
      </ul>
    </div>

    <div style="text-align: center; margin-bottom: 28px;">
      <a href="${params.dashboardUrl || 'https://flowpay.finance'}" style="display: inline-block; background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%); color: #ffffff; text-decoration: none; font-size: 15px; font-weight: 600; padding: 14px 32px; border-radius: 8px; box-shadow: 0 4px 14px rgba(99, 102, 241, 0.4);">
        Open FlowPay Dashboard
      </a>
    </div>

    <p style="margin: 0; font-size: 13px; color: #6b7280; text-align: center;">
      Need help? Reach our dedicated concierge at support@flowpay.finance
    </p>
  `;

  const html = wrapBaseTemplate({
    title: 'Welcome to FlowPay',
    preheader: 'Your autonomous financial layer is ready.',
    contentHtml,
  });

  const text = `Welcome to FlowPay, ${params.recipientName}!\n\nYour ${accountTypeLabel} is ready.\n\nEnjoy multi-currency smart wallets, Money Missions, and instant global payouts.\n\nOpen your dashboard: ${params.dashboardUrl || 'https://flowpay.finance'}\n\nFlowPay Team`;

  return { subject, html, text };
}

/**
 * Employee Invitation Email for Global Payroll Onboarding
 */
export function buildEmployeeInviteEmail(params: EmployeeInviteParams): {
  subject: string;
  html: string;
  text: string;
} {
  const employer = params.companyName || params.employerName || 'Your Employer';
  const payrollDetails =
    params.payrollAmount && params.currency
      ? `<div style="margin-top: 8px; color: #10b981; font-weight: 600;">Monthly Compensation: ${params.payrollAmount} ${params.currency}</div>`
      : '';

  const subject = `Invitation to join ${employer} Global Payroll on FlowPay`;

  const contentHtml = `
    <h2 style="margin: 0 0 16px 0; font-size: 20px; font-weight: 700; color: #ffffff;">
      You've Been Invited to FlowPay Payroll 💼
    </h2>
    <p style="margin: 0 0 20px 0; font-size: 15px; color: #d1d5db; line-height: 24px;">
      Hi ${params.recipientName}, <strong>${employer}</strong> has invited you to set up your direct deposit and smart employee wallet on FlowPay.
    </p>

    <!-- Details Box -->
    <div style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; padding: 20px; margin-bottom: 28px;">
      <div style="font-size: 13px; color: #9ca3af; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">
        Onboarding Summary
      </div>
      <div style="font-size: 15px; color: #f3f4f6; margin-bottom: 6px;">
        <strong>Employer:</strong> ${employer}
      </div>
      <div style="font-size: 15px; color: #f3f4f6; margin-bottom: 6px;">
        <strong>Country / Rail:</strong> ${params.country}
      </div>
      ${payrollDetails}
    </div>

    <p style="margin: 0 0 24px 0; font-size: 14px; color: #9ca3af; line-height: 22px;">
      Complete your one-time onboarding to generate your personal smart wallet address, activate your local currency payout rail, and receive your corporate virtual card.
    </p>

    <div style="text-align: center; margin-bottom: 28px;">
      <a href="${params.inviteUrl}" style="display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; text-decoration: none; font-size: 15px; font-weight: 600; padding: 14px 32px; border-radius: 8px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4);">
        Accept Invitation &amp; Complete Setup
      </a>
    </div>

    <p style="margin: 0; font-size: 12px; color: #6b7280; word-break: break-all;">
      Or copy your invitation link:<br />
      <span style="color: #818cf8;">${params.inviteUrl}</span>
    </p>
  `;

  const html = wrapBaseTemplate({
    title: `Invitation to FlowPay Payroll from ${employer}`,
    preheader: `${employer} has invited you to set up your payout wallet on FlowPay.`,
    contentHtml,
  });

  const text = `Hi ${params.recipientName},\n\n${employer} has invited you to set up your employee smart wallet and payroll payouts on FlowPay (${params.country}).\n\nAccept your invitation here: ${params.inviteUrl}\n\nFlowPay Team`;

  return { subject, html, text };
}

/**
 * Payroll Disbursement Payout Receipt
 */
export function buildPayrollReceiptEmail(params: PayrollReceiptParams): {
  subject: string;
  html: string;
  text: string;
} {
  const company = params.companyName || 'FlowPay Business';
  const dateStr = params.date || new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
  const subject = `Payroll Disbursement Confirmed: ${params.amount} ${params.currency}`;

  const contentHtml = `
    <div style="text-align: center; margin-bottom: 24px;">
      <span style="display: inline-block; background-color: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3); color: #10b981; font-size: 12px; font-weight: 600; padding: 6px 14px; border-radius: 20px; text-transform: uppercase; letter-spacing: 1px;">
        Disbursement Succeeded
      </span>
      <h2 style="margin: 16px 0 6px 0; font-size: 26px; font-weight: 800; color: #ffffff;">
        ${params.amount} <span style="color: #6366f1;">${params.currency}</span>
      </h2>
      <p style="margin: 0; font-size: 14px; color: #9ca3af;">
        Disbursed on ${dateStr} via BMONI Rails
      </p>
    </div>

    <!-- Receipt Card -->
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; margin-bottom: 28px;">
      <tr>
        <td style="padding: 16px 20px; border-bottom: 1px solid #374151; font-size: 14px; color: #9ca3af;">
          Recipient
        </td>
        <td align="right" style="padding: 16px 20px; border-bottom: 1px solid #374151; font-size: 14px; font-weight: 600; color: #f3f4f6;">
          ${params.recipientName}
        </td>
      </tr>
      <tr>
        <td style="padding: 16px 20px; border-bottom: 1px solid #374151; font-size: 14px; color: #9ca3af;">
          Originating Company
        </td>
        <td align="right" style="padding: 16px 20px; border-bottom: 1px solid #374151; font-size: 14px; font-weight: 600; color: #f3f4f6;">
          ${company}
        </td>
      </tr>
      ${
        params.txHash
          ? `<tr>
              <td style="padding: 16px 20px; font-size: 14px; color: #9ca3af;">
                Transaction Reference
              </td>
              <td align="right" style="padding: 16px 20px; font-size: 12px; font-family: monospace; color: #818cf8;">
                ${params.txHash.slice(0, 16)}...
              </td>
            </tr>`
          : ''
      }
    </table>

    <p style="margin: 0; font-size: 13px; color: #9ca3af; text-align: center; line-height: 20px;">
      Funds have settled directly to your designated smart wallet or local bank account. View complete details in the FlowPay mobile app.
    </p>
  `;

  const html = wrapBaseTemplate({
    title: 'FlowPay Payroll Receipt',
    preheader: `Payment of ${params.amount} ${params.currency} has been disbursed.`,
    contentHtml,
  });

  const text = `FlowPay Payroll Receipt\n\nRecipient: ${params.recipientName}\nAmount: ${params.amount} ${params.currency}\nCompany: ${company}\nDate: ${dateStr}\nReference: ${params.txHash || 'N/A'}\n\nSettled successfully via BMONI Rails.`;

  return { subject, html, text };
}

/**
 * Transfer Notification (Sent or Received)
 */
export function buildTransferReceiptEmail(params: TransferReceiptParams): {
  subject: string;
  html: string;
  text: string;
} {
  const isSent = params.type === 'SENT';
  const actionTitle = isSent ? 'Transfer Sent' : 'Transfer Received';
  const directionText = isSent
    ? `You sent funds to ${params.recipientEmail || 'recipient'}`
    : `You received funds from ${params.senderName || 'FlowPay user'}`;
  const subject = `${actionTitle}: ${params.amount} ${params.currency}`;

  const contentHtml = `
    <div style="text-align: center; margin-bottom: 24px;">
      <h2 style="margin: 0 0 8px 0; font-size: 22px; font-weight: 700; color: #ffffff;">
        ${actionTitle}
      </h2>
      <div style="font-size: 32px; font-weight: 800; color: ${isSent ? '#f3f4f6' : '#10b981'}; margin-bottom: 8px;">
        ${isSent ? '-' : '+'}${params.amount} <span style="font-size: 20px; color: #818cf8;">${params.currency}</span>
      </div>
      <p style="margin: 0; font-size: 14px; color: #9ca3af;">
        ${directionText}
      </p>
    </div>

    ${
      params.txHash
        ? `<div style="background-color: #1f2937; border: 1px solid #374151; border-radius: 8px; padding: 12px 16px; margin-bottom: 24px; text-align: center;">
            <span style="font-size: 12px; color: #9ca3af;">Transaction Hash: </span>
            <span style="font-size: 12px; font-family: monospace; color: #818cf8;">${params.txHash}</span>
          </div>`
        : ''
    }
  `;

  const html = wrapBaseTemplate({
    title: actionTitle,
    preheader: `${actionTitle}: ${params.amount} ${params.currency}`,
    contentHtml,
  });

  const text = `${actionTitle}\n\nAmount: ${params.amount} ${params.currency}\n${directionText}\nTxHash: ${params.txHash || 'N/A'}\n\nFlowPay`;

  return { subject, html, text };
}

/**
 * Security Alert Email
 */
export function buildSecurityAlertEmail(params: SecurityAlertParams): {
  subject: string;
  html: string;
  text: string;
} {
  const timestamp = params.timestamp || new Date().toUTCString();
  const subject = `Security Alert: ${params.action}`;

  const contentHtml = `
    <div style="background-color: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 12px; padding: 20px; margin-bottom: 24px;">
      <h3 style="margin: 0 0 8px 0; font-size: 18px; color: #ef4444;">
        ⚠️ Security Activity Detected
      </h3>
      <p style="margin: 0; font-size: 14px; color: #fca5a5; line-height: 20px;">
        Hi ${params.recipientName}, we noticed a critical security event on your FlowPay account: <strong>${params.action}</strong>.
      </p>
    </div>

    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #1f2937; border: 1px solid #374151; border-radius: 12px; margin-bottom: 28px;">
      <tr>
        <td style="padding: 14px 20px; border-bottom: 1px solid #374151; font-size: 13px; color: #9ca3af;">Time</td>
        <td align="right" style="padding: 14px 20px; border-bottom: 1px solid #374151; font-size: 13px; color: #f3f4f6;">${timestamp}</td>
      </tr>
      ${
        params.ipAddress
          ? `<tr>
              <td style="padding: 14px 20px; border-bottom: 1px solid #374151; font-size: 13px; color: #9ca3af;">IP Address</td>
              <td align="right" style="padding: 14px 20px; border-bottom: 1px solid #374151; font-size: 13px; color: #f3f4f6;">${params.ipAddress}</td>
            </tr>`
          : ''
      }
      ${
        params.device
          ? `<tr>
              <td style="padding: 14px 20px; font-size: 13px; color: #9ca3af;">Device / Agent</td>
              <td align="right" style="padding: 14px 20px; font-size: 13px; color: #f3f4f6;">${params.device}</td>
            </tr>`
          : ''
      }
    </table>

    <p style="margin: 0; font-size: 14px; color: #d1d5db; line-height: 22px;">
      If this was you, you can safely ignore this email. If you did not authorize this action, please immediately lock your smart wallet from your device or contact support@flowpay.finance.
    </p>
  `;

  const html = wrapBaseTemplate({
    title: 'FlowPay Security Alert',
    preheader: `Security notification regarding ${params.action}`,
    contentHtml,
  });

  const text = `Security Alert: ${params.action}\n\nHi ${params.recipientName},\nA security event occurred at ${timestamp}.\nDevice: ${params.device || 'N/A'}\nIP: ${params.ipAddress || 'N/A'}\n\nIf this was not you, secure your account immediately.\n\nFlowPay Security`;

  return { subject, html, text };
}
