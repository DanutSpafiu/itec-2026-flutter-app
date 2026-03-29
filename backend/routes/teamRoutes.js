import express from 'express';
import { createTeam, joinTeam } from '../controllers/teamController.js';

const router = express.Router();

// Route: POST /api/teams
router.post('/', createTeam);

// Route: POST /api/teams/join
router.post('/join', joinTeam);

export default router;
