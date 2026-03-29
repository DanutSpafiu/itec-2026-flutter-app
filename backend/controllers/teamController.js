import { prisma } from '../config/prisma.js';

// ---- CREATE A NEW TEAM ----
export const createTeam = async (req, res) => {
  try {
    const { name, userId } = req.body;

    if (!name || !userId) {
      return res.status(400).json({ error: "Team name and User ID are required!" });
    }

    // 1. Check if the team name already exists
    const existingTeam = await prisma.team.findUnique({ where: { name: name } });
    if (existingTeam) {
      return res.status(400).json({ error: "A team with this name already exists!" });
    }

    // 2. Generate a 6-character random Join Code (e.g. "A9X2BQ")
    const joinCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    // 3. Create the team and instantly add the creator as its first member
    const newTeam = await prisma.team.create({
      data: {
        name: name,
        joinCode: joinCode,
        members: {
          connect: { id: userId } // Links the existing user to this new Team
        }
      },
      include: {
        members: true // Returns the newly created relationships so we can view them
      }
    });

    res.status(201).json({
      message: "Team successfully created!",
      team: newTeam
    });
  } catch (error) {
    res.status(500).json({ error: "Error creating team: " + error.message });
  }
};

// ---- JOIN AN EXISTING TEAM ----
export const joinTeam = async (req, res) => {
  try {
    const { joinCode, userId } = req.body;

    if (!joinCode || !userId) {
      return res.status(400).json({ error: "Join Code and User ID are required!" });
    }

    // 1. Find the team by code and bring its current array of members along
    const team = await prisma.team.findUnique({
      where: { joinCode: joinCode },
      include: { members: true }
    });

    if (!team) {
      return res.status(404).json({ error: "Invalid Join Code!" });
    }

    // 2. Enforce the maximum of 4 users per team
    if (team.members.length >= 4) {
      return res.status(400).json({ error: "This team is already full (Max 4 members)!" });
    }

    // 3. Ensure the user isn't already inside
    const isAlreadyMember = team.members.find(member => member.id === userId);
    if (isAlreadyMember) {
      return res.status(400).json({ error: "User is already in this team!" });
    }

    // 4. Update the Database by "connecting" the User to the Team
    const updatedTeam = await prisma.team.update({
      where: { id: team.id },
      data: {
        members: {
          connect: { id: userId }
        }
      },
      include: { members: true }
    });

    res.status(200).json({
      message: "Successfully joined the team!",
      team: updatedTeam
    });
  } catch (error) {
    res.status(500).json({ error: "Error joining team: " + error.message });
  }
};
