# Data sources

Files in this directory are the editable source of truth for LoL Analyst.

| File | Ownership | Purpose |
| --- | --- | --- |
| `riot-data.json` | Riot / Data Dragon | Patch, champion names, base stats, skills and official image URLs |
| `items.json` | Riot / Data Dragon | Current patch items flagged for Summoner's Rift (map 11) |
| `manual-data.json` | Maintained in this project | Roles, ratings, guides, strategy fields, CC and routes |
| `matchup-lanes.json` | Manually reviewed / imported | Lane bans, counters, favorable lanes and synergies |
| `sheet-details.json` | Manually reviewed / imported | Workbook flags, release metadata and strong skills |
| `jungle-details.json` | Manually reviewed / imported | Jungle route controls and ordered steps |
| `team-rules.json` | Maintained in this project | Central thresholds for warnings and tactical panels |

The normalized consumer files `champions.json`, `matchups.json`, and `meta.json`
are generated artifacts. Refresh all browser and normalized outputs with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-team-data.ps1
```

Use `update-riot-data.ps1` to fetch a new Data Dragon patch. It preserves manually maintained ability tags and alternate forms:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-riot-data.ps1
```

The same command refreshes `items.json`. To update only the Summoner's Rift item catalog:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-item-data.ps1
```

Edit manual JSON here, then validate and build browser files from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-data.ps1 -CheckGenerated
```

`-CheckGenerated` verifies that the browser `.js` payloads still match the JSON
sources. The build command runs this parity check automatically after writing.

If imported Skill cells were interpreted as Excel date serials, reconcile the known
Google Sheet values before validating:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply-sheet-data-fixes.ps1
```

The generated root-level `.js` files expose global constants because the app is designed to work when `index.html` is opened directly from disk. Do not edit those generated files by hand.

Every JSON file must use UTF-8. Champion keys use the normalized lowercase ID already used by `app.js` (for example `leesin`, `jarvaniv`, and `aurelionsol`). Missing source values should remain empty or absent instead of being guessed.
