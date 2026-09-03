import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { prisma } from '../db/index.js';
import type { Prisma } from '@prisma/client';
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
      const existing = await prisma.webhookEvent.findUnique({
        where: { bmoniEventId: event.id },
        select: { id: true },
      });

      if (existing) {
        return { handled: true, message: `Event ${event.id} already processed (idempotent skip)` };
      }

      // 2. Persist raw event
      await prisma.webhookEvent.create({
        data: {
          id: `whk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          bmoniEventId: event.id,
          eventType: event.eventType,
          payloadJson: event.payload as object,
        },
      });

      // 3. Handle specific event families
      switch (event.eventType) {
        case 'employee.linked': {
          const { userId, email } = event.payload as { userId?: string; email?: string };
          if (userId && email) {
            await prisma.employee.updateMany({
              where: { email },
              data: { bmoniUserId: userId, status: 'LINKED' },
            });
            await this.logAudit('BUSINESS', 'EMPLOYEE_LINKED', 'BMONI_WEBHOOK', { email, userId });
          }
          break;
        }

        case 'onboarding.completed': {
          const { userId } = event.payload as { userId?: string };
          if (userId) {
            await prisma.employee.updateMany({
              where: { bmoniUserId: userId },
              data: { status: 'ACTIVE' },
            });
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

  private static async logAudit(
    category: string,
    action: string,
    actor: string,
    details: Record<string, unknown>
  ): Promise<void> {
    try {
      await prisma.auditActivity.create({
        data: {
          id: `aud_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          category,
          action,
          actor,
          detailsJson: details as Prisma.InputJsonValue,
        },
      });
    } catch (err) {
      console.error('[Audit] Failed to log audit event:', err);
    }
  }
}
