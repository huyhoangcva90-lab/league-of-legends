const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'src', 'data', 'manual-data.json');
const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const unique = values => [...new Set(values.filter(Boolean))];
let converted = 0;

for (const champion of source.champions || []) {
  const combat = champion.combat || {};
  const legacy = [combat.primary, combat.secondary, combat.macro];
  const hadFlex = legacy.includes('Flex') || (combat.tags || []).includes('Flex');
  if (hadFlex) converted += 1;
  if (combat.primary === 'Flex') combat.primary = 'Split';
  if (combat.secondary === 'Flex') combat.secondary = 'Catch';
  if (combat.macro === 'Flex') combat.macro = 'Split';
  combat.tags = unique([
    combat.primary,
    combat.secondary,
    combat.macro,
    ...(combat.tags || []).filter(tag => tag !== 'Flex'),
    ...(hadFlex ? ['Split', 'Catch'] : [])
  ]);
  champion.combat = combat;
  champion.evidence = {
    ...(champion.evidence || {}),
    combatTags: hadFlex
      ? 'sheet-normalized-v2: Flex expands to Split + Catch'
      : 'sheet-normalized-v2: primary + secondary + macro'
  };
}

source.logic = {
  ...(source.logic || {}),
  combatTags: {
    id: 'sheet-normalized-v2',
    rule: 'Legacy Team Flex means the champion contributes to both Split and Catch; Flex is never emitted as a combat tag.'
  }
};

fs.writeFileSync(sourcePath, JSON.stringify(source), 'utf8');
console.log(`Normalized ${source.champions.length} champion combat records; expanded ${converted} Flex records.`);
