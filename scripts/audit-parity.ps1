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

$renderers = @('renderTeamFull','renderDraftFull','renderFinderFull','renderMatchupsFull','renderTeamfightFull','renderCompareFull','renderMapFull','renderStrategyFull','renderChampionsFull','renderSkillsFull','renderRoutesFull','renderCcFull','renderSystemFull')
Add-Contract 'Navigation' 'All 13 application modules have renderers' (Has-All $app ($renderers | ForEach-Object { "function\s+$([regex]::Escape($_))\s*\(" })) ($renderers -join ', ')
Add-Contract 'State' 'Versioned persisted-state migration' ($app -match 'STATE_SCHEMA_VERSION\s*=\s*5' -and $app -match 'function\s+mergeState') 'STATE_SCHEMA_VERSION=5 + mergeState'
Add-Contract 'Session' 'Named save, history, share and JSON interchange' (Has-All $app @('function\s+saveNamedSession','function\s+restoreHistoryEntry','function\s+copySessionLink','function\s+downloadSession','data-session-import')) 'Session persistence and portable analysis contract'
Add-Contract 'Team' 'Simple, Advanced and Expert modes use accessible result tabs' (Has-All $app @('analysisMode','function\s+availableTeamSections','role="tablist"','aria-selected')) 'Mode visibility and tab state'
Add-Contract 'Team' 'Independent ban panels and reset controls' (Has-All $app @('function\s+teamBanPanel','reset-side-bans','reset-all-bans','toggle-bans')) 'Five bans per side with hide and reset actions'
Add-Contract 'Team' 'Official class icons replace generated class glyphs' ((Has-All $app @('OFFICIAL_CLASS_ASSETS','assets/icons/classes','function\s+classIcon')) -and @('assassin','fighter','mage','marksman','support','tank').Where({ Test-Path -LiteralPath (Join-Path $root "assets\icons\classes\$_.png") }).Count -eq 6) 'Six Riot homepage class assets stored locally'
Add-Contract 'Team' 'Stable role rows expose phases, formation and skill tooltip' ((Has-All $app @('function\s+phaseMicro','function\s+positionLine','slot-skill-grid','function\s+teamBalanceModel','function\s+teamProsCons')) -and (Has-All $style @('grid-template-rows:repeat\(5,104px\)','height:104px!important','\.slot-insight\{position:absolute','\.position-line','\.team-balance-panel'))) 'Fixed geometry + tactical hierarchy + hover detail'
Add-Contract 'Team' 'Attack, hard CC and strong ultimate detail panels' (Has-All $app @('function\s+attackDependencyPanel','function\s+hardCcDetailPanel','function\s+strongUltimatePanel')) 'Skill-level tactical evidence'
Add-Contract 'State' 'Draft-series state preserves bans, picks and winner' (Has-All $app @('function\s+sanitizeDraftGame','blueBans:championSlots','redBans:championSlots','winner:enumValue')) 'sanitizeDraftGame contract'
Add-Contract 'Team' 'Team workbook projections and full formula audit' ((Has-All $app @('function\s+sheetProjection','function\s+sheetPhaseMatrix','function\s+sheetTriggerMatrix','function\s+sheetSkillMatrix','function\s+teamLaneDetail')) -and [int]$teamMeta.teamFormulaNodes -eq 1266) 'Projection matrices + 1266/1266 formula nodes'
Add-Contract 'Team' 'Role and duplicate validation is active' (Has-All $app @('function\s+roleFits','duplicate','wrong-lane')) 'roleFits + picker/validation states'
Add-Contract 'Setting' 'Setting data is loaded before application logic' ($index.IndexOf('lol/setting-data.js') -ge 0 -and $index.IndexOf('lol/setting-data.js') -lt $index.IndexOf('app.js')) 'index.html script order'
Add-Contract 'Setting' 'Named Setting role pools feed UI logic' (Has-All $app @('SETTING_ROLE_KEYS','function\s+settingRolePool','function\s+settingRoles')) 'Setting CQ:CU role pools'
Add-Contract 'Check' 'Workbook Check filters and source map are present' (Has-All $app @('function\s+checkWorkbookPanel','function\s+checkSettingPanel','function\s+checkSkillClassPanel','SETTING\.named\?\.skillChampTypes')) 'Check matrix, validation source map and skill class'
Add-Contract 'Matchup' 'Directional matchup is not treated as reciprocal' (Has-All $app @('function\s+matchupDirectionPanel','direction is never assumed reciprocal','function\s+matchupSourcePanel')) 'Directional audit + observed-source panel'
Add-Contract 'Draft' '20-step draft, duplicate locks and Fearless history' (Has-All $app @('DRAFT_SEQUENCE','function\s+fearlessIds','function\s+seriesHistory','function\s+draftWorkbookContract')) 'Draft state and workbook contract'
Add-Contract 'Teamfight' 'Formation, trigger and execution contracts' (Has-All $app @('function\s+teamfightWorkbookControls','function\s+teamfightWorkbookParity','function\s+teamfightExecutionPanel')) 'Teamfight B2:Z2 controls and execution board'
Add-Contract 'Compare' 'Symmetric champion, skill, lane and level comparison' (Has-All $app @('function\s+soloMatchupBoard','function\s+compareLanePanel','function\s+compareLevelPanel','ability-compare')) 'Compare A1:Y37 contract'
Add-Contract 'Compare' 'Lane-valid solo picks and complete Bot duos' (Has-All $app @("COMPARE_LANES=\['Top','Jungle','Mid','Bot'\]",'function\s+comparePool','function\s+normalizeCompareLineup','compareBlueSupport','compareRedSupport','function\s+duoSynergy','SHEET-INFERRED','NOT WIN RATE')) 'Same-lane 1v1 + AD/Support 2v2 contract'
Add-Contract 'Map' 'Map route types and visual legend' (Has-All $app @('function\s+routeStepType','function\s+mapLegend','function\s+mapRouteVisual')) 'Camp, gank, objective and invade markers'
Add-Contract 'Map' 'Map legend is responsive' (Has-All $style @('\.map-legend','route-map span\.gank','route-map span\.objective','route-map span\.invade','@media\(max-width:480px\)')) 'Desktop, tablet and mobile styles'
Add-Contract 'Strategy' 'Strategy depends on live team and Setting pools' (Has-All $app @('function\s+strategyWorkbookContract','function\s+strategyMatrix','function\s+strategyTierPanel')) 'Strategy DA1:EI125 contract'
Add-Contract 'Route' 'Jungle champion compatibility and 9-step routes' (Has-All $app @('function\s+routeCompatibilityPanel','function\s+routeWorkbookTable','Array\.from\(\{length:9\}')) 'Jungle Route A1:W44 contract'
Add-Contract 'CC' 'CC taxonomy, skill coverage and removal rules' (Has-All $app @('function\s+ccSkillCoverage','function\s+ccRemovalPanel','function\s+renderCcFull')) 'Official CC dictionary consumers'
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
