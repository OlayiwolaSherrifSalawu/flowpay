import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { db } from '../db/index.js';
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
  static processEvent(event: WebhookDeliveryPayload): { handled: boolean; message: string } {
    // 1. Deduplication check
    const existing = db
      .prepare('SELECT id FROM webhook_events WHERE bmoni_event_id = ?')
      .get(event.id);

    if (existing) {
      return { handled: true, message: `Event ${event.id} already processed (idempotent skip)` };
    }

    // 2. Persist raw event
    db.prepare(`
      INSERT INTO webhook_events (id, bmoni_event_id, event_type, payload_json)
      VALUES (?, ?, ?, ?)
    `).run(
      `whk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      event.id,
      event.eventType,
      JSON.stringify(event.payload)
    );

    // 3. Handle specific event families
    switch (event.eventType) {
      case 'employee.linked': {
        const { userId, email } = event.payload as { userId?: string; email?: string };
        if (userId && email) {
          db.prepare(`
            UPDATE employees 
            SET bmoni_user_id = ?, status = 'LINKED', updated_at = CURRENT_TIMESTAMP
            WHERE email = ?
          `).run(userId, email);
          
          this.logAudit('BUSINESS', 'EMPLOYEE_LINKED', 'BMONI_WEBHOOK', { email, userId });
        }
        break;
      }

      case 'onboarding.completed': {
        const { userId } = event.payload as { userId?: string };
        if (userId) {
          db.prepare(`
            UPDATE employees 
            SET status = 'ACTIVE', updated_at = CURRENT_TIMESTAMP
            WHERE bmoni_user_id = ?
          `).run(userId);
          
          this.logAudit('BUSINESS', 'ONBOARDING_COMPLETED', 'BMONI_WEBHOOK', { userId });
        }
        break;
      }

      case 'employee.deposit.completed': {
        const { userId, amount } = event.payload as { userId?: string; amount?: string };
        this.logAudit('PERSONAL', 'DEPOSIT_COMPLETED', 'BMONI_WEBHOOK', { userId, amount });
        break;
      }

      case 'employee.withdrawal.completed': {
        const { userId, amount } = event.payload as { userId?: string; amount?: string };
        this.logAudit('PERSONAL', 'WITHDRAWAL_COMPLETED', 'BMONI_WEBHOOK', { userId, amount });
        break;
      }

      default:
        console.log(`[BMONI Webhook] Unhandled event type: ${event.eventType}`);
    }

    return { handled: true, message: `Successfully processed ${event.eventType}` };
  }

  private static logAudit(category: string, action: string, actor: string, details: Record<string, unknown>): void {
    try {
      db.prepare(`
        INSERT INTO audit_activity (id, category, action, actor, details_json)
        VALUES (?, ?, ?, ?, ?)
      `).run(
        `aud_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        category,
        action,
        actor,
        JSON.stringify(details)
      );
    } catch (err) {
      console.error('[Audit] Failed to log audit event:', err);
    }
  }
}
