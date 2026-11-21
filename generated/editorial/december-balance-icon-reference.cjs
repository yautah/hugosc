const sharp = require('/Users/yang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const path = require('node:path');
const base = path.resolve(__dirname, '../../content/posts/clashroyale/2026-11-20/season-90-balance-wip-december-2026');
const icons = ['index-1795190461578.png', 'card-hero-valkyrie.webp', 'card-furnace.webp', 'card-royal-chef.webp', 'card-elite-barbarians-evolution.png', 'card-battle-ram-evolution.webp', 'card-cannon-evolution.webp', 'card-ram-rider.webp', 'card-royal-giant.webp', 'card-pekka.webp', 'card-executioner.webp', 'card-void.webp', 'card-giant-skeleton.webp'];
(async () => {
  const layers = [];
  for (let i = 0; i < icons.length; i++) {
    const left = (i % 4) * 240;
    const top = Math.floor(i / 4) * 285;
    layers.push({ input: await sharp(path.join(base, icons[i])).resize(195, 230, {fit: 'contain', background: '#ffffff'}).png().toBuffer(), left: left + 22, top: top + 8 });
    layers.push({input: Buffer.from(`<svg width="240" height="40"><text x="120" y="30" text-anchor="middle" font-size="27" font-family="Arial" fill="#111">${i + 1}</text></svg>`),left, top: top + 240});
  }
  await sharp({create:{width:960,height:1140,channels:3,background:'#ffffff'}}).composite(layers).png().toFile(path.join(__dirname,'december-balance-icon-reference.png'));
})();
