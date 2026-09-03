import { Router } from 'express';
import { FinancialIntentInterpreter } from '../modules/ai/interpreter.js';
import { FinancialSafetyValidator } from '../modules/ai/validator.js';

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
