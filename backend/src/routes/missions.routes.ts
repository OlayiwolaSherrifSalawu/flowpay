import { Router } from 'express';
import { MoneyMissionService } from '../modules/missions/service.js';

export const missionsRouter = Router();

// GET /api/missions
missionsRouter.get('/', async (req, res, next) => {
  try {
    const list = await MoneyMissionService.listMissions();
    res.json({ success: true, data: list });
  } catch (err) {
    next(err);
  }
});

// POST /api/missions
missionsRouter.post('/', async (req, res, next) => {
  try {
    const mission = await MoneyMissionService.createMission(req.body);
    res.json({ success: true, data: mission });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/missions/:id/toggle
missionsRouter.patch('/:id/toggle', async (req, res, next) => {
  try {
    const result = await MoneyMissionService.toggleMission(req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});
