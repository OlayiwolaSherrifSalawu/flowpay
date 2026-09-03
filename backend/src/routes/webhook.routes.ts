import express, { Router } from 'express';
import { BmoniWebhookService } from '../bmoni/webhooks.js';

export const webhookRouter = Router();

/**
 * BMONI Webhook Endpoint
 * Uses express.raw({ type: 'application/json' }) to capture raw Buffer bytes
 * for cryptographic HMAC-SHA256 signature verification.
 */
webhookRouter.post(
  '/bmoni',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const rawBody = req.body as Buffer;
    const signature = req.get('X-Webhook-Signature') || req.get('x-webhook-signature');

    // 1. Mandatory HMAC verification
    const isValid = BmoniWebhookService.verifySignature(rawBody, signature);
    if (!isValid) {
      console.warn('[BMONI Webhook] Rejected invalid or unsigned webhook delivery.');
      return res.status(401).json({
        statusCode: 401,
        message: 'Invalid webhook signature',
        error: 'Unauthorized',
      });
    }

    // 2. Parse verified payload
    let eventPayload: any;
    try {
      eventPayload = JSON.parse(rawBody.toString('utf-8'));
    } catch {
      return res.status(400).json({
        statusCode: 400,
        message: 'Malformed JSON payload',
        error: 'Bad Request',
      });
    }

    // 3. Process event
    const result = await BmoniWebhookService.processEvent(eventPayload);
    return res.status(200).json({ received: true, ...result });
  }
);
