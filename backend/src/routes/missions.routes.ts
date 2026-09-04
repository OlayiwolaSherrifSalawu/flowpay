import { Router } from 'express';
import { MoneyMissionService } from '../modules/missions/service.js';

export const missionsRouter = Router();

// GET /api/missions - List all enriched missions
missionsRouter.get('/', async (req, res, next) => {
  try {
    const list = await MoneyMissionService.listMissions();
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions/propose - Generate proposal and signing payload hash for intent
missionsRouter.post('/propose', async (req, res, next) => {
  try {
    const { intent } = req.body;
    if (!intent) {
      return res.status(400).json({ success: false, message: 'Mission intent is required' });
    }
    const proposal = await MoneyMissionService.proposeMission(intent);
    res.json({ success: true, data: proposal });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions/:id/execute - Complete BMONI mission with on-device signature
missionsRouter.post('/:id/execute', async (req, res, next) => {
  try {
    const { signature, pinValidated } = req.body;
    const missionId = req.params.id;

    if (!signature) {
      return res.status(400).json({ success: false, message: 'BMONI signature is required' });
    }

    const result = await MoneyMissionService.executeMission({
      missionId,
      signature,
      pinValidated: pinValidated !== false,
    });

    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions - Generic creation
missionsRouter.post('/', async (req, res, next) => {
  try {
    const mission = await MoneyMissionService.createMission(req.body);
    res.json({ success: true, data: mission });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/missions/:id/toggle - Toggle active/paused state
missionsRouter.patch('/:id/toggle', async (req, res, next) => {
  try {
    const result = await MoneyMissionService.toggleMission(req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});
