import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { pool } from '../db/index.js';
import type { WebhookDeliveryPayload } from './types.js';

export class BmoniWebhookService {
  /**
   * Verify HMAC-SHA256 signature over raw Buffer bytes
   * Uses constant-time comparison to prevent timing side-channel attacks
   */
  static verifySignature(rawBody: Buffer, signatureHeader: string | undefined): boolean {
    if (!signatureHeader || !rawBody) {
      return false;
    }

    try {
      const expected = crypto
        .createHmac('sha256', env.BMONI_WEBHOOK_SECRET)
        .update(rawBody)
        .digest('hex');

      // Strip any whitespace
      const received = signatureHeader.trim();

      // Check length first: timingSafeEqual throws if lengths differ
      if (expected.length !== received.length) {
        return false;
      }

      return crypto.timingSafeEqual(
        Buffer.from(expected, 'hex'),
        Buffer.from(received, 'hex')
      );
    } catch (err) {
      console.error('[BMONI Webhook] Signature verification error:', err);
      return false;
    }
  }

  /**
   * Process and dispatch verified webhook event
   */
  static async processEvent(event: WebhookDeliveryPayload): Promise<{ handled: boolean; message: string }> {
    try {
      // 1. Deduplication check
      const { rows } = await pool.query(
        'SELECT id FROM webhook_events WHERE bmoni_event_id = $1',
        [event.id]
      );

      if (rows.length > 0) {
        return { handled: true, message: `Event ${event.id} already processed (idempotent skip)` };
      }

      // 2. Persist raw event
      await pool.query(
        `INSERT INTO webhook_events (id, bmoni_event_id, event_type, payload_json)
         VALUES ($1, $2, $3, $4)`,
        [
          `whk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          event.id,
          event.eventType,
          JSON.stringify(event.payload),
        ]
      );

      // 3. Handle specific event families
      switch (event.eventType) {
        case 'employee.linked': {
          const { userId, email } = event.payload as { userId?: string; email?: string };
          if (userId && email) {
            await pool.query(
              `UPDATE employees 
               SET bmoni_user_id = $1, status = 'LINKED', updated_at = now()
               WHERE email = $2`,
              [userId, email]
            );
            await this.logAudit('BUSINESS', 'EMPLOYEE_LINKED', 'BMONI_WEBHOOK', { email, userId });
          }
          break;
        }

        case 'onboarding.completed': {
          const { userId } = event.payload as { userId?: string };
          if (userId) {
            await pool.query(
              `UPDATE employees 
               SET status = 'ACTIVE', updated_at = now()
               WHERE bmoni_user_id = $1`,
              [userId]
            );
            await this.logAudit('BUSINESS', 'ONBOARDING_COMPLETED', 'BMONI_WEBHOOK', { userId });
          }
          break;
        }

        case 'employee.deposit.completed': {
          const { userId, amount } = event.payload as { userId?: string; amount?: string };
          await this.logAudit('PERSONAL', 'DEPOSIT_COMPLETED', 'BMONI_WEBHOOK', { userId, amount });
          break;
        }

        case 'employee.withdrawal.completed': {
          const { userId, amount } = event.payload as { userId?: string; amount?: string };
          await this.logAudit('PERSONAL', 'WITHDRAWAL_COMPLETED', 'BMONI_WEBHOOK', { userId, amount });
          break;
        }

        default:
          console.log(`[BMONI Webhook] Unhandled event type: ${event.eventType}`);
      }
    } catch (err) {
      console.warn('[BMONI Webhook] Non-critical persistence note:', err);
    }

    return { handled: true, message: `Successfully processed ${event.eventType}` };
  }

  private static async logAudit(category: string, action: string, actor: string, details: Record<string, unknown>): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO audit_activity (id, category, action, actor, details_json)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          `aud_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          category,
          action,
          actor,
          JSON.stringify(details),
        ]
      );
    } catch (err) {
      console.error('[Audit] Failed to log audit event:', err);
    }
  }
}
