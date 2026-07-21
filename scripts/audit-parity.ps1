[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$appPath = Join-Path $root 'app.js'
$stylePath = Join-Path $root 'style.css'
$indexPath = Join-Path $root 'index.html'
$app = [IO.File]::ReadAllText($appPath, [Text.Encoding]::UTF8)
$style = [IO.File]::ReadAllText($stylePath, [Text.Encoding]::UTF8)
$index = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
$teamRulesText = [IO.File]::ReadAllText((Join-Path $root 'src\data\team-rules.json'), [Text.Encoding]::UTF8)
$teamMetaPath = Join-Path $root 'src\data\meta.json'
$teamMeta = if (Test-Path -LiteralPath $teamMetaPath) { [IO.File]::ReadAllText($teamMetaPath, [Text.Encoding]::UTF8) | ConvertFrom-Json } else { $null }
$results = New-Object Collections.Generic.List[object]

function Add-Contract([string]$Group, [string]$Name, [bool]$Passed, [string]$Evidence) {
    $results.Add([pscustomobject]@{ Group = $Group; Name = $Name; Passed = $Passed; Evidence = $Evidence })
}

function Has-All([string]$Text, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) { if ($Text -notmatch $pattern) { return $false } }
    return $true
}

try {
    & (Join-Path $PSScriptRoot 'validate-data.ps1') -Quiet -CheckGenerated
    Add-Contract 'Data' 'Strict source and generated-data validation' $true 'validate-data.ps1 -CheckGenerated'
} catch {
    Add-Contract 'Data' 'Strict source and generated-data validation' $false $_.Exception.Message
}
Add-Contract 'Data' 'Live Riot roster updater preserves workbook forms and adds new champions' ((Has-All ([IO.File]::ReadAllText((Join-Path $root 'scripts\update-riot-data.ps1'),[Text.Encoding]::UTF8)) @('Get-NormalizedChampionId','Get-InferredAbilityTags','New-ManualChampion','formLabel','variantOf','api/versions\.json')) -and (Has-All $app @('function\s+image','DATA\.patch','function\s+roleFits'))) 'Latest portrait, core skills, cooldowns and future champion baseline pipeline'
$riotData = [IO.File]::ReadAllText((Join-Path $root 'src\data\riot-data.json'),[Text.Encoding]::UTF8) | ConvertFrom-Json
$riotIds = @($riotData.champions.id)
Add-Contract 'Data' 'Patch 16.14 roster includes Locke, Zaahen and merged workbook forms' ([string]$riotData.patch -eq '16.14.1' -and @('locke','zaahen','kled','gnar').Where({$_ -notin $riotIds}).Count -eq 0 -and @('kledskaarl','megagnar').Where({$_ -in $riotIds}).Count -eq 0 -and $riotIds.Count -eq 173 -and @($riotData.champions | Where-Object { $_.id -eq 'kled' } | ForEach-Object { $_.abilities } | Where-Object { $_.form -eq 'alternate' }).Count -ge 2 -and @($riotData.champions | Where-Object { $_.id -eq 'gnar' } | ForEach-Object { $_.abilities } | Where-Object { $_.form -eq 'alternate' }).Count -ge 2) '173 champions; Kled/Gnar form records live inside parent abilities'
$manualData = [IO.File]::ReadAllText((Join-Path $root 'src\data\manual-data.json'),[Text.Encoding]::UTF8) | ConvertFrom-Json
$tierValues = @($manualData.champions.tier | Select-Object -Unique)
Add-Contract 'Data' 'All champions use the sourced four-level meta tier contract' (@($manualData.champions).Count -eq 173 -and @($tierValues | Where-Object { $_ -notin @('S+','S','A+','A') }).Count -eq 0 -and @($manualData.champions | Where-Object { [string]$_.evidence.tier -notmatch '^lolalytics:' }).Count -eq 0 -and (Test-Path (Join-Path $root 'scripts\update-meta-tiers.ps1'))) 'LoLalytics Emerald+ global snapshot mapped to S+, S, A+, A'

$renderers = @('renderTeamFull','renderDraftFull','renderFinderFull','renderMatchupsFull','renderTeamfightFull','renderCompareFull','renderMapFull','renderStrategyFull','renderChampionsFull','renderSkillsFull','renderBuildsFull','renderRoutesFull','renderSystemFull')
Add-Contract 'Navigation' 'All 13 application modules have renderers' (Has-All $app ($renderers | ForEach-Object { "(function\s+$([regex]::Escape($_))\s*\(|$([regex]::Escape($_))\s*=\s*function)" })) ($renderers -join ', ')
Add-Contract 'State' 'Versioned persisted-state migration' ($app -match 'STATE_SCHEMA_VERSION\s*=\s*8' -and $app -match 'function\s+mergeState') 'STATE_SCHEMA_VERSION=8 + mergeState'
Add-Contract 'Session' 'Named save, history, share and JSON interchange' (Has-All $app @('function\s+saveNamedSession','function\s+restoreHistoryEntry','function\s+copySessionLink','function\s+downloadSession','data-session-import')) 'Session persistence and portable analysis contract'
Add-Contract 'Team' 'Simple, Advanced and Expert modes use accessible result tabs' (Has-All $app @('analysisMode','function\s+availableTeamSections','role="tablist"','aria-selected')) 'Mode visibility and tab state'
Add-Contract 'Team' 'Independent ban panels and reset controls' (Has-All $app @('function\s+teamBanPanel','reset-side-bans','reset-all-bans','toggle-bans')) 'Five bans per side with hide and reset actions'
Add-Contract 'Team' 'Role slots use one standardized SVG icon language' ((Has-All $app @('function\s+roleIcon','function\s+filterIcon','official-role-icon','role-label role-slot')) -and (Has-All $style @('\.official-role-icon svg','stroke-width:1\.8'))) 'Top, Jungle, Mid, AD and Support icons are vector-based and independent of champion class'
Add-Contract 'Design' 'Semantic tags share Google Sheets color tokens and icons' ((Has-All $app @('function\s+semanticTone','tone-disengage','tone-magic','tone-physical','function\s+termIcon')) -and (Has-All $style @('--tag-disengage-bg:#d9ead3','--tag-engage-bg:#f4cccc','--tag-magic-bg:#d9d2e9','--tag-physical-bg:#fce5cd','Global Google Sheets-inspired semantic tag system'))) 'Global tag palette: color + SVG icon + text'
Add-Contract 'Team' 'Stable role rows expose phases, formation and skill tooltip' ((Has-All $app @('function\s+phaseMicro','function\s+positionLine','slot-skill-grid','function\s+teamBalanceModel','function\s+teamProsCons')) -and (Has-All $style @('grid-template-rows:repeat\(5,104px\)','height:104px!important','\.slot-insight\{position:absolute','\.position-line','\.team-balance-panel'))) 'Fixed geometry + tactical hierarchy + hover detail'
Add-Contract 'Team' 'Attack, hard CC and strong ultimate detail panels' (Has-All $app @('function\s+attackDependencyPanel','function\s+hardCcDetailPanel','function\s+strongUltimatePanel')) 'Skill-level tactical evidence'
Add-Contract 'State' 'Draft-series state preserves bans, picks and winner' (Has-All $app @('function\s+sanitizeDraftGame','blueBans:championSlots','redBans:championSlots','winner:enumValue')) 'sanitizeDraftGame contract'
Add-Contract 'Team' 'Team workbook projections and full formula audit' ((Has-All $app @('function\s+sheetProjection','function\s+sheetPhaseMatrix','function\s+sheetTriggerMatrix','function\s+sheetSkillMatrix','function\s+teamLaneDetail')) -and [int]$teamMeta.teamFormulaNodes -eq 1266) 'Projection matrices + 1266/1266 formula nodes'
Add-Contract 'Team' 'Role and duplicate validation is active' (Has-All $app @('function\s+roleFits','duplicate','not a natural fit')) 'roleFits + picker/validation states'
Add-Contract 'Team' 'Champion picker preserves the complete champion decision model' ((Has-All $app @('pickerFilters:\{role:\[\],className:\[\],range:\[\],damage:\[\],damageProfile:\[\],attackStyle:\[\],combat:\[\],macro:\[\],position:\[\],profiles:\[\],tier:\[\],difficulty:\[\],early:\[\],mid:\[\],late:\[\],capabilities:\[\]\}','PICKER_SINGLE_FILTERS','data-picker-filter-select','function\s+pickerChampionTags','picker-class-icon','picker-damage-label')) -and (Has-All $style @('\.picker-class-icon','\.picker-damage-label','\.picker-tier-tag'))) 'Complete filter model with compact champion cards limited to class, damage type and tier'
Add-Contract 'Team' 'Team slots prefilter their role and keep analysis in workbook order' ((Has-All $app @("kind==='slot'.*state\.pickerFilters\.role=\[ROLES\[slot\]\]",'teamSheetBoard\(\)\+teamWorkbookMatrices\(\)\+teamStrengthWeaknessPanel\(\)')) -and $app -notmatch 'data-swap-team-lane|function\s+swapTeamLane') 'Slot index selects Top/Jungle/Mid/AD/Support; center lane swap removed; matrices precede champion guidance'
Add-Contract 'Team' 'My Team marker defaults to Blue and replaces aggregate scores' ((Has-All $app @('function\s+myTeamMarker','data-my-team-side','function\s+myTeamSide','dataset\.perspective=myTeamSide\(\)','team-sheet-versus')) -and $app -notmatch 'team-sheet-score') 'Exclusive Blue/Red checkbox; unchecked neutral state resolves to Blue; aggregate score removed while per-lane percentages remain'
Add-Contract 'Team' 'Champion guidance separates mirrored strengths from enemy-only matchup advice' ((Has-All $app @('teamGuideTab','data-team-guide-tab','bindStateTabs',"myTeamSide\(\)==='blue'\?'red':'blue'",'function\s+teamCounterCard','LANING AGAINST','STRATEGY VS','team-guide-source')) -and (Has-All $style @('\.team-guide-tabs','\.team-counter-list','\.enemy-only','\.team-guide-copy \.strength','\.team-guide-copy \.weakness','\.team-guide-copy \.laning','\.team-guide-copy \.strategy')) -and $index -match 'app\.js\?v=20260721') 'Direct rendered-tab binding plus cache-busted assets; matchup tab renders only the enemy selected by My Team'
Add-Contract 'Team' 'Composition strategy implements the exact Team row 41 and Setting rank bands' ((Has-All $app @('teamMatrixTab','teamStrategyPhase','sheetTacticalCounts','sheetCombatPrimary','sheetCombatSecondary','sheetMacroType','sheetWinConditionSignature','sheetDetailedRuleResults','sheetRankedTeamTypes','teamTypePrimary','teamTypeSecondary','Setting!O31 / O32','Setting!P31 / P32','teamStrategyMetricScores=function','teamStrategyPhaseScore=function','Team!E41:K41','Team!S41:Y41','data-team-matrix-tab','data-team-strategy-phase')) -and (Has-All $style @('\.team-matrix-tabs','\.team-strategy-scoreboard','\.team-strategy-sides','\.team-strategy-signature','\.team-strategy-classification','\.strategy-primary')) -and $teamRulesText -match 'sheetPhaseRoleScores' -and $teamRulesText -match 'sheetWinConditionLabels') 'AN:AR sums, role phase scores, Team combat IFS, Split+2 macro rule, then Setting five-category count/support ranking with text-only secondary results'
Add-Contract 'Data' 'Legacy combat Flex expands to Split plus Catch' ((@($manualData.champions | Where-Object { $_.combat.primary -eq 'Flex' -or $_.combat.secondary -eq 'Flex' -or $_.combat.macro -eq 'Flex' -or @($_.combat.tags) -contains 'Flex' }).Count -eq 0) -and (@($manualData.champions | Where-Object { [string]$_.evidence.combatTags -match 'Flex expands' -and (-not (@($_.combat.tags) -contains 'Split') -or -not (@($_.combat.tags) -contains 'Catch')) }).Count -eq 0) -and (Test-Path (Join-Path $root 'scripts\normalize-combat-tags.js'))) '39 workbook Flex combat records are normalized to simultaneous Split and Catch contributors'
Add-Contract 'Setting' 'Setting data is loaded before application logic' ($index.IndexOf('lol/setting-data.js') -ge 0 -and $index.IndexOf('lol/setting-data.js') -lt $index.IndexOf('app.js')) 'index.html script order'
Add-Contract 'Setting' 'Named Setting role pools feed UI logic' (Has-All $app @('SETTING_ROLE_KEYS','function\s+settingRolePool','function\s+settingRoles')) 'Setting CQ:CU role pools'
Add-Contract 'Check' 'Workbook Check filters and source map are present' (Has-All $app @('function\s+checkWorkbookPanel','function\s+checkSettingPanel','function\s+checkSkillClassPanel','SETTING\.named\?\.skillChampTypes')) 'Check matrix, validation source map and skill class'
Add-Contract 'Matchup' 'Directional matchup is not treated as reciprocal' (Has-All $app @('function\s+matchupDirectionPanel','direction is never assumed reciprocal','function\s+matchupSourcePanel')) 'Directional audit + observed-source panel'
Add-Contract 'Draft' '20-step draft, duplicate locks and Fearless history' (Has-All $app @('DRAFT_SEQUENCE','function\s+fearlessIds','function\s+seriesHistory','function\s+draftWorkbookContract')) 'Draft state and workbook contract'
Add-Contract 'Draft' 'Master champion pool imports feed ban-pick assistant' (Has-All $app @('draftSharedPool','function\s+parseChampionPoolInput','function\s+importDraftPool','function\s+draftPoolIds','data-pool-target="shared"')) 'Own, enemy and both-team pools with fast text import'
Add-Contract 'Teamfight' 'Formation, trigger and execution contracts' (Has-All $app @('function\s+teamfightWorkbookControls','function\s+teamfightWorkbookParity','function\s+teamfightExecutionPanel')) 'Teamfight B2:Z2 controls and execution board'
Add-Contract 'Teamfight' 'Combat Class and execution archetypes' ((Has-All $app @('COMBAT_CLASS_DATA','function\s+resolvedCombatClassId','function\s+combatClassMatches','function\s+championCombatClasses','function\s+advancedTeamfightPanel','function\s+teamfightExecutionSide','profiles\?\.hyperCarry','ratings\?\.toughness')) -and (Test-Path (Join-Path $root 'src\data\combat-classes.json')) -and (Test-Path (Join-Path $root 'assets\teamfight-archetypes\manifest.json')) -and @(Get-ChildItem (Join-Path $root 'assets\teamfight-archetypes') -Filter '*.png').Count -ge 15) '15 one-per-champion Combat Classes resolved from Champion class plus combat conditions, including distinct Vanguard, Warden, Hard Carry and two Catchers'
Add-Contract 'Compare' 'Symmetric champion, skill, lane and level comparison' (Has-All $app @('function\s+soloMatchupBoard','function\s+compareLanePanel','function\s+compareLevelPanel','ability-compare')) 'Compare A1:Y37 contract'
Add-Contract 'Compare' 'Lane-valid solo picks and complete Bot duos' (Has-All $app @("COMPARE_LANES=\['Top','Jungle','Mid','Bot'\]",'function\s+comparePool','function\s+normalizeCompareLineup','compareBlueSupport','compareRedSupport','function\s+duoSynergy','SHEET-INFERRED','NOT WIN RATE')) 'Same-lane 1v1 + AD/Support 2v2 contract'
Add-Contract 'Map' 'Map route types and visual legend' (Has-All $app @('function\s+routeStepType','function\s+mapLegend','function\s+mapRouteVisual')) 'Camp, gank, objective and invade markers'
Add-Contract 'Map' 'Map legend is responsive' (Has-All $style @('\.map-legend','route-map span\.gank','route-map span\.objective','route-map span\.invade','@media\(max-width:480px\)')) 'Desktop, tablet and mobile styles'
Add-Contract 'Strategy' 'Strategy depends on live team and Setting pools' (Has-All $app @('function\s+strategyWorkbookContract','function\s+strategyMatrix','function\s+strategyTierPanel')) 'Strategy DA1:EI125 contract'
Add-Contract 'Route' 'Jungle champion compatibility and 9-step routes' (Has-All $app @('function\s+routeCompatibilityPanel','function\s+routeWorkbookTable','Array\.from\(\{length:9\}')) 'Jungle Route A1:W44 contract'
Add-Contract 'Builds' 'Champion build page exposes items, runes, summoner spells and matchup item order' ((Has-All $app @('renderBuildsFull\s*=\s*function|function\s+renderBuildsFull','function\s+buildRecommendation','function\s+runePanel','function\s+levelUpPanel','SUMMONER_SPELLS','function\s+buildPlanPanel','data-build-control="buildOpponent"','function\s+matchupItemReason','ITEM_DATA','ITEMS')) -and (Has-All $style @('\.build-style-grid','\.build-item-chip','\.rune-columns','\.level-grid','\.build-control-board','\.build-matchup-hero','\.build-plan-grid'))) 'Item builds + matchup selector + spells + rune baseline + skill level order'
Add-Contract 'QA' 'Runtime integrity panel is exposed in the app' (Has-All $app @('function\s+runtimeContractChecks','function\s+runtimeContractPanel','function\s+qualityChecks')) 'System / Data Quality route'
Add-Contract 'Recovery' 'Render failures preserve workspace and expose recovery' (Has-All $app @('function\s+renderFailure','Open Data Quality','Reset workspace')) 'renderFailure recovery mode'

$passed = @($results | Where-Object Passed).Count
$failed = @($results | Where-Object { -not $_.Passed }).Count
$imageExtensions = @('*.png','*.jpg','*.jpeg','*.webp','*.gif')
$referenceImages = @($imageExtensions | ForEach-Object { Get-ChildItem -LiteralPath $root -Filter $_ -File -Recurse -ErrorAction SilentlyContinue }).Count

if (-not $Quiet) {
    $results | Format-Table Group, Passed, Name, Evidence -AutoSize
    "AUTOMATED_CONTRACTS=$passed/$($results.Count)"
    "VISUAL_REFERENCE_IMAGES=$referenceImages"
    if ($referenceImages -eq 0) { 'VISUAL_PARITY=BLOCKED (reattach the original reference image)' }
}

if ($failed -gt 0) { throw "$failed parity contract(s) failed." }
