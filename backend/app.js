import express from 'express';
import cors from 'cors';
import authRoutes from './routes/authRoutes.js';
import teamRoutes from './routes/teamRoutes.js';
import posterRoutes from './routes/posterRoutes.js';

// 1. Initialize the Express application
const app = express();

// 2. Add Global Middlewares
app.use(cors());
app.use(express.json()); // Parses incoming request bodies (req.body) as JSON

// === HTTP ROUTING (REST API) ===
// All HTTP routes are registered here, keeping server.js clean
app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/posters', posterRoutes);

// A simple test route (optional)
app.get('/', (req, res) => {
  res.send('Express API is running smoothly! 🌐');
});

export default app;
