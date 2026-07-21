const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const manualPath = path.join(root, 'src', 'data', 'manual-data.json');
const riotPath = path.join(root, 'src', 'data', 'riot-data.json');

const manual = JSON.parse(fs.readFileSync(manualPath, 'utf8'));
const riot = JSON.parse(fs.readFileSync(riotPath, 'utf8'));
const riotById = new Map((riot.champions || []).map(champion => [champion.id, champion]));

const PHASES = ['early', 'mid', 'late'];
const SOURCE = {
  id: 'derived-riot-ddragon-kit-tags-v1',
  name: 'Derived from Riot Data Dragon champion stats, imported ability tags, workbook guide text, class/role profile, and phase power.',
  references: [
    'https://developer.riotgames.com/docs/lol#data-dragon',
    'https://wiki.leagueoflegends.com/en-us/Attack_timer'
  ],
  scale: '0-100; legacy ratings.clearwave and ratings.tower store the mid-game value for old UI compatibility.'
};

const phasePower = { Weak: -8, Average: 0, Strong: 8 };
const clamp = (value, min = 5, max = 100) => Math.max(min, Math.min(max, Math.round(value)));
const norm = value => String(value || '').toLowerCase();
const hasAny = (text, needles) => needles.some(needle => text.includes(norm(needle)));
const countAny = (text, needles) => needles.reduce((count, needle) => count + (text.includes(norm(needle)) ? 1 : 0), 0);

const waveSpecial = {
  anivia: 10, asol: 9, aurelionsol: 9, azir: 8, brand: 8, cassiopeia: 6, corki: 6,
  gangplank: 8, graves: 7, heimerdinger: 9, hwei: 10, illaoi: 7, karthus: 9,
  kayle: 7, lux: 6, malzahar: 10, missfortune: 6, morgana: 7, rumble: 8,
  ryze: 8, seraphine: 6, sivir: 12, taliyah: 7, viktor: 8, xerath: 7,
  ziggs: 12, zyra: 6
};
const towerSpecial = {
  azir: 6, belveth: 8, camille: 7, corki: 6, fiora: 11, gangplank: 6, gwen: 7,
  jax: 12, jayce: 7, jinx: 8, kayle: 8, kindred: 6, kogmaw: 8, masteryi: 12,
  nasus: 12, nilah: 6, olaf: 7, tristana: 12, trundle: 12, tryndamere: 12,
  twitch: 6, vayne: 7, viego: 6, volibear: 7, yorick: 14, ziggs: 14, zeri: 6
};

function championText(manualChampion, riotChampion) {
  const abilityText = (riotChampion?.abilities || []).map(ability => [
    ability.name,
    ability.description,
    ...(ability.tags || [])
  ].join(' ')).join(' ');
  const guide = manualChampion.guide || {};
  return norm([
    manualChampion.id,
    manualChampion.classification?.primary,
    manualChampion.classification?.secondary,
    manualChampion.combat?.primary,
    manualChampion.combat?.secondary,
    manualChampion.combat?.macro,
    manualChampion.damage?.profile,
    ...(manualChampion.capabilities || []),
    abilityText,
    guide.strengths,
    guide.weaknesses,
    ...PHASES.map(phase => guide.gamePlan?.[phase]),
    ...PHASES.map(phase => guide.powerSpikes?.[phase])
  ].filter(Boolean).join(' '));
}

function clearwaveBase(champion, official, text) {
  const ratings = champion.ratings || {};
  let score = 26 + (Number(ratings.clearwave) || 45) * 0.42;
  score += (Number(ratings.damage) || 0) * 1.4;
  score += countAny(text, ['clearwave', 'wave clear', 'push the wave', 'shoving', 'shove', 'aoe']) * 1.8;
  score += hasAny(text, ['pet', 'turret', 'minion', 'zone']) ? 2 : 0;
  score += hasAny(text, ['artillery', 'battlemage', 'mage']) ? 2 : 0;
  score += hasAny(text, ['marksman']) ? 1 : 0;
  score += champion.range === 'Ranged' ? 3 : -1;
  score += champion.roles?.includes('Support') && !champion.roles?.includes('Mid') ? -10 : 0;
  score += Number(waveSpecial[champion.id]) || 0;
  score += official?.baseStats?.range >= 525 ? 2 : 0;
  return score;
}

function towerBase(champion, official, text) {
  const ratings = champion.ratings || {};
  const stats = official?.baseStats || {};
  const isMarksman = champion.classification?.primary === 'Marksman' || champion.roles?.includes('AD');
  let score = 18 + (Number(ratings.tower) || 45) * 0.4;
  score += (Number(ratings.damage) || 0) * 1.4;
  score += isMarksman ? 11 : 0;
  score += hasAny(text, ['on-hit', 'bonus as', 'reset']) ? 5 : 0;
  score += hasAny(text, ['split', 'side lane', 'split push', 'take that tower', 'siege', 'demolish']) ? 6 : 0;
  score += hasAny(text, ['pet', 'turret']) ? 3 : 0;
  score += champion.range === 'Ranged' ? 4 : 0;
  score += Number(stats.asGrowth || 0) * 1.2;
  score += Number(stats.range || 0) >= 525 ? 2 : 0;
  score += hasAny(text, ['mage', 'burst ap', 'support']) && !isMarksman && !['ziggs', 'azir'].includes(champion.id) ? -5 : 0;
  score += champion.roles?.includes('Support') && !champion.roles?.includes('AD') ? -16 : 0;
  score += Number(towerSpecial[champion.id]) || 0;
  return score;
}

function phased(base, champion, kind) {
  const macro = norm(champion.combat?.macro);
  const phaseOffset = {
    early: kind === 'tower' ? -8 : -5,
    mid: 0,
    late: kind === 'tower' ? 9 : 6
  };
  return Object.fromEntries(PHASES.map(phase => {
    let value = base + phaseOffset[phase] + (phasePower[champion.power?.[phase]] || 0) * 0.7;
    if (kind === 'tower' && macro === 'split') value += phase === 'early' ? 2 : phase === 'mid' ? 7 : 6;
    if (kind === 'clearwave' && macro === 'split') value += phase === 'mid' ? 3 : 1;
    if (kind === 'clearwave' && champion.roles?.includes('Jungle') && phase === 'early') value += 4;
    if (kind === 'tower' && champion.classification?.primary === 'Marksman') value += phase === 'late' ? 5 : 2;
    return [phase, clamp(value)];
  }));
}

let updated = 0;
for (const champion of manual.champions || []) {
  const official = riotById.get(champion.id);
  const text = championText(champion, official);
  const clearwave = phased(clearwaveBase(champion, official, text), champion, 'clearwave');
  const tower = phased(towerBase(champion, official, text), champion, 'tower');
  champion.phaseRatings = { clearwave, tower, source: SOURCE.id };
  champion.ratings = { ...(champion.ratings || {}), clearwave: clearwave.mid, tower: tower.mid };
  champion.evidence = { ...(champion.evidence || {}), phaseRatings: `${SOURCE.id}: riot baseStats + kit tags + guide text + phase power` };
  updated += 1;
}

manual.logic = {
  ...(manual.logic || {}),
  phaseRatings: SOURCE
};

fs.writeFileSync(manualPath, JSON.stringify(manual), 'utf8');
console.log(`Updated phase clearwave/tower ratings for ${updated} champions.`);
