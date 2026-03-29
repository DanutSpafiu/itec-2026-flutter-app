import { createServer } from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import app from './app.js'; // Import the configured Express app
import { initializeWebSockets } from './sockets/socketHandler.js';

dotenv.config();

// Create a raw HTTP server using the Express app as the engine
const serverHttp = createServer(app);

// Initialize the WebSockets brain by attaching it to the HTTP server
const serverWebSockets = new Server(serverHttp, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Delegate the heavy Socket logic to its dedicated file
initializeWebSockets(serverWebSockets);

// Start listening on port 3000
const PORT = process.env.PORT || 3000;
serverHttp.listen(PORT, () => {
  console.log(`✅ [HTTP & WebSockets] Server listening on port ${PORT}...`);
});