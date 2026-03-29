import { PrismaClient } from '@prisma/client';

// Use a single global instance (Singleton) of Prisma across the entire application.
// This prevents exhausting the database connections (Supabase) if PrismaClient 
// is imported across multiple files (controllers, sockets, auth, etc.).

export const prisma = new PrismaClient();
