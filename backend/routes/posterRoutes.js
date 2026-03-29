import express from 'express';
import { listPosters, getPosterById, getTerritoryStats } from '../controllers/posterController.js';

const router = express.Router();

router.get('/', listPosters);
router.get('/:id/stats', getTerritoryStats);
router.get('/:id', getPosterById);

export default router;
