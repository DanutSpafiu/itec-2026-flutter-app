import { prisma } from '../config/prisma.js';

export const initializeWebSockets = (io) => {

  io.on('connection', async (connectedUser) => {

    let userId = connectedUser.id;
    let userName = 'Anonymous';
    console.log(`📱 A new user opened the app! Socket ID: ${userId}`);

    connectedUser.on('register_user', async (userData) => {
      try {
        userName = userData?.name || 'Anonymous';
        const requestedUserId = userData?.dbUserId;

        if (requestedUserId) {
          const existingUser = await prisma.user.findUnique({
            where: { id: requestedUserId }
          });

          if (existingUser) {
            userId = existingUser.id;
            userName = existingUser.name;
          } else {
            userId = connectedUser.id;
          }
        } else {
          userId = connectedUser.id;
        }
        
        connectedUser.emit('user_registered', { userId, userName });
        console.log(`✅ User registered: ${userName} (${userId})`);
      } catch (error) {
        console.error('Error registering user:', error);
      }
    });

    // === EVENT 1: ENTERING A POSTER'S ROOM ===
    // The phone emits this when AR detects a previously saved poster
    connectedUser.on('phone_sees_poster', async (posterId) => {
      // 1. Join the specific Poster's live Room
      connectedUser.join(posterId);
      console.log(`👀 Socket ${userId} is viewing poster: ${posterId}`);

      // 2. DATABASE MAGIC: Auto-create poster if it doesn't exist
      try {
        let poster = await prisma.poster.findFirst({
          where: { name: posterId }
        });

        if (!poster) {
          poster = await prisma.poster.create({
            data: {
              name: posterId,
              referenceImage: `/posters/${posterId}.png`
            }
          });
          console.log(`📝 Created new poster: ${posterId}`);
        }

        // 3. Fetch all old Graffiti saved by others
        const oldDrawings = await prisma.graffiti.findMany({
          where: { posterId: poster.id },
          include: {
            user: { select: { id: true, name: true, teamId: true } },
          },
        });

        // 4. Send the entire "history" to the newly connected user
        connectedUser.emit('load_drawing_history', oldDrawings);

      } catch (error) {
        console.error("Error reading old drawings from DB: ", error);
      }
    });

    // === EVENT 2: LIVE DRAWING ON THE POSTER (No Database) ===
    // 60 frames per second traffic! 
    // Do NOT write to DB here, otherwise Supabase will crash under pressure.
    connectedUser.on('user_draws_line_live', (drawingData) => {
      const currentPosterId = drawingData.posterId;

      // Broadcast the entire payload (points, color, size) to others in the room
      connectedUser.to(currentPosterId).emit('receive_live_line', drawingData);
    });

    // === EVENT 3: PERMANENTLY SAVING THE DRAWING ===
    // Triggered by the Frontend ONLY WHEN THE USER LIFTS THEIR FINGER OFF THE SCREEN.
    // This sends the full array of coordinates (Vector Array JSON) into the DB.
    connectedUser.on('phone_saves_final_drawing', async (finalPayload) => {
      const { posterId, dbUserId, completeLineJSON, color = "#FF6B6B", size = 12 } = finalPayload;

      try {
        if (!posterId || !Array.isArray(completeLineJSON) || completeLineJSON.length === 0) {
          connectedUser.emit('save_error', {
            error: 'Invalid drawing payload: posterId and vector array are required.'
          });
          return;
        }

        // Get or create the poster
        let poster = await prisma.poster.findFirst({
          where: { name: posterId }
        });

        if (!poster) {
          poster = await prisma.poster.create({
            data: {
              name: posterId,
              referenceImage: `/posters/${posterId}.png`
            }
          });
        }

        const effectiveUserId = dbUserId || userId;
        const user = await prisma.user.findUnique({
          where: { id: effectiveUserId }
        });

        if (!user) {
          connectedUser.emit('save_error', {
            error: 'Authentication required before saving drawings.'
          });
          return;
        }

        // Prisma cleanly inserts the arrays into PostgreSQL
        const created = await prisma.graffiti.create({
          data: {
            posterId: poster.id,
            userId: user.id,
            linesData: completeLineJSON,
            color: color,
            size: size,
          },
          include: {
            user: { select: { id: true, name: true, teamId: true } },
          },
        });
        console.log(`✅ Successfully saved drawing for user ${user.name} on poster ${posterId}`);
        connectedUser.to(posterId).emit('remote_graffiti_saved', created);
      } catch (error) {
        console.error("Prisma Save Error:", error);
      }
    });

    // === EVENT 4: LEAVING THE POSTER ===
    connectedUser.on('phone_loses_poster', (posterId) => {
      connectedUser.leave(posterId);
      console.log(`🏃 Socket ${userId} withdrew from poster: ${posterId}`);
    });

    // === DISCONNECTION ===
    connectedUser.on('disconnect', () => {
      console.log(`❌ Connection closed: ${userId}`);
    });

  });
};
