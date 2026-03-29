import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const POSTERS = [
  {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Hol principal — iTEC',
    referenceImage:
      'https://placehold.co/800x600/16213e/e94560?text=iTEC+OVERRIDE',
    audioUrl: null,
  },
  {
    id: '22222222-2222-2222-2222-222222222222',
    name: 'Scara A — etaj 1',
    referenceImage:
      'https://placehold.co/800x600/0f3460/eee?text=ANCHOR+B',
    audioUrl: null,
  },
];

async function main() {
  for (const p of POSTERS) {
    await prisma.poster.upsert({
      where: { id: p.id },
      update: {
        name: p.name,
        referenceImage: p.referenceImage,
        audioUrl: p.audioUrl,
      },
      create: p,
    });
  }
  console.log('Seed: posters OK', POSTERS.map((x) => x.id));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
