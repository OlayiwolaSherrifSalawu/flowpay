import { Router } from 'express';
import { mailService } from '../modules/mail/service.js';

export const mailRouter = Router();

/**
 * GET /api/mail/health
 * Verifies SMTP connection to smtp.gmail.com:587
 */
mailRouter.get('/health', async (req, res) => {
  try {
    const status = await mailService.verifyConnection();
    return res.status(status.connected ? 200 : 503).json({
      success: status.connected,
      data: status,
    });
  } catch (err: any) {
    return res.status(500).json({
      success: false,
      message: err.message || 'SMTP health check failed',
    });
  }
});

/**
 * POST /api/mail/test
 * Sends a test diagnostic email to the specified address or configured default
 */
mailRouter.post('/test', async (req, res) => {
  try {
    const { to } = req.body || {};
    const result = await mailService.sendTestEmail(to);

    if (result.success) {
      return res.json({
        success: true,
        message: 'Test email successfully sent',
        data: result,
      });
    } else {
      return res.status(502).json({
        success: false,
        message: 'Failed to deliver test email',
        error: result.error,
      });
    }
  } catch (err: any) {
    return res.status(500).json({
      success: false,
      message: err.message || 'Error executing email test',
    });
  }
});

/**
 * POST /api/mail/otp
 * Dispatches a verification code email
 */
mailRouter.post('/otp', async (req, res) => {
  try {
    const { to, code, recipientName, expiryMinutes, actionDescription } = req.body || {};

    if (!to || !code) {
      return res.status(400).json({
        success: false,
        message: 'Recipient email ("to") and "code" are required',
      });
    }

    const result = await mailService.sendOtp({
      to,
      code,
      recipientName,
      expiryMinutes,
      actionDescription,
    });

    return res.json({
      success: result.success,
      data: result,
    });
  } catch (err: any) {
    return res.status(500).json({
      success: false,
      message: err.message || 'Failed to dispatch OTP email',
    });
  }
});

/**
 * POST /api/mail/invite
 * Dispatches an employee payroll onboarding invitation
 */
mailRouter.post('/invite', async (req, res) => {
  try {
    const { to, recipientName, companyName, employerName, inviteUrl, country, payrollAmount, currency } = req.body || {};

    if (!to || !inviteUrl || !country) {
      return res.status(400).json({
        success: false,
        message: '"to", "inviteUrl", and "country" are required',
      });
    }

    const result = await mailService.sendEmployeeInvite({
      to,
      recipientName: recipientName || 'Team Member',
      companyName,
      employerName,
      inviteUrl,
      country,
      payrollAmount,
      currency,
    });

    return res.json({
      success: result.success,
      data: result,
    });
  } catch (err: any) {
    return res.status(500).json({
      success: false,
      message: err.message || 'Failed to dispatch invite email',
    });
  }
});

/**
 * POST /api/mail/send
 * Generic email dispatch
 */
mailRouter.post('/send', async (req, res) => {
  try {
    const { to, subject, html, text, replyTo } = req.body || {};

    if (!to || !subject || (!html && !text)) {
      return res.status(400).json({
        success: false,
        message: '"to", "subject", and either "html" or "text" are required',
      });
    }

    const result = await mailService.sendMail({
      to,
      subject,
      html: html || `<p>${text}</p>`,
      text,
      replyTo,
    });

    return res.status(result.success ? 200 : 502).json({
      success: result.success,
      data: result,
    });
  } catch (err: any) {
    return res.status(500).json({
      success: false,
      message: err.message || 'Failed to send email',
    });
  }
});
