import { Router } from 'express';
import { FinancialIntentInterpreter } from '../modules/ai/interpreter.js';
import { FinancialSafetyValidator } from '../modules/ai/validator.js';
import { MissionInterpreter } from '../modules/ai/mission_interpreter.js';

export const aiRouter = Router();

// POST /api/ai/interpret
// Step 1: Natural Language Interpretation -> Structured Intent (Gemini 2.5 Flash / fallback)
aiRouter.post('/interpret', async (req, res, next) => {
  try {
    const { prompt } = req.body;
    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({ success: false, message: 'Prompt is required' });
    }
    const structuredIntent = await FinancialIntentInterpreter.interpret(prompt);
    res.json({ success: true, data: structuredIntent });
  } catch (err) {
    next(err);
  }
});

// POST /api/ai/validate-preview
// Step 2: Deterministic validation & preview generation
aiRouter.post('/validate-preview', (req, res, next) => {
  try {
    const { intent, availableBalanceMinor } = req.body;
    const balance = BigInt(availableBalanceMinor ?? 10000000); // Defaults to $100,000 for test
    const preview = FinancialSafetyValidator.validateAndPreview(intent, balance);
    res.json({ success: true, data: preview });
  } catch (err) {
    next(err);
  }
});

// POST /api/ai/missions/interpret
// FlowPay Flagship Money Missions: NL -> Structured Intent -> Deterministic Validation
aiRouter.post('/missions/interpret', async (req, res, next) => {
  try {
    const { prompt } = req.body;
    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({ success: false, message: 'Natural language prompt is required' });
    }

    const { intent, validation } = await MissionInterpreter.interpret(prompt);

    res.json({
      success: true,
      data: {
        intent,
        validation,
        requiresApproval: true,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/ai/transfers/interpret
// Send Money NL -> Structured TransferIntent -> Zod Validation
aiRouter.post('/transfers/interpret', async (req, res, next) => {
  try {
    const { prompt } = req.body;
    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({ success: false, message: 'Natural language prompt is required' });
    }

    const { TransferService } = await import('../modules/transfers/service.js');
    const intent = await TransferService.interpret(prompt);

    res.json({
      success: true,
      data: {
        intent,
        requiresApproval: true,
      },
    });
  } catch (err) {
    next(err);
  }
});


