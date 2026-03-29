import { prisma } from '../config/prisma.js';

function lineLength(points) {
  if (!Array.isArray(points) || points.length < 2) return 0;
  let len = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    const ax = Number(a?.x ?? 0);
    const ay = Number(a?.y ?? 0);
    const bx = Number(b?.x ?? 0);
    const by = Number(b?.y ?? 0);
    const dx = bx - ax;
    const dy = by - ay;
    len += Math.sqrt(dx * dx + dy * dy);
  }
  return len;
}

export const listPosters = async (req, res) => {
  try {
    const posters = await prisma.poster.findMany({
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        referenceImage: true,
        audioUrl: true,
      },
    });
    res.status(200).json({ posters });
  } catch (error) {
    res.status(500).json({ error: 'Failed to list posters: ' + error.message });
  }
};

export const getPosterById = async (req, res) => {
  try {
    const { id } = req.params;
    const poster = await prisma.poster.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        referenceImage: true,
        audioUrl: true,
      },
    });
    if (!poster) {
      return res.status(404).json({ error: 'Poster not found' });
    }
    res.status(200).json({ poster });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get poster: ' + error.message });
  }
};

/** Territory proxy: sum of stroke length per team on this poster (normalized coords). */
export const getTerritoryStats = async (req, res) => {
  try {
    const { id: posterId } = req.params;
    const rows = await prisma.graffiti.findMany({
      where: { posterId },
      include: {
        user: {
          select: { id: true, teamId: true, name: true },
        },
      },
    });

    const byTeam = new Map();
    for (const g of rows) {
      const teamId = g.user.teamId ?? 'solo';
      const len = lineLength(g.linesData);
      const prev = byTeam.get(teamId) ?? { teamId, totalLength: 0, strokes: 0, members: new Set() };
      prev.totalLength += len;
      prev.strokes += 1;
      prev.members.add(g.user.name);
      byTeam.set(teamId, prev);
    }

    const teams = [...byTeam.values()].map((t) => ({
      teamId: t.teamId,
      totalLength: Math.round(t.totalLength * 1000) / 1000,
      strokes: t.strokes,
      members: [...t.members],
    }));

    teams.sort((a, b) => b.totalLength - a.totalLength);

    const total = teams.reduce((s, t) => s + t.totalLength, 0) || 1;
    const withPercent = teams.map((t) => ({
      ...t,
      percent: Math.round((t.totalLength / total) * 1000) / 10,
    }));

    res.status(200).json({ posterId, teams: withPercent });
  } catch (error) {
    res.status(500).json({ error: 'Territory stats failed: ' + error.message });
  }
};
