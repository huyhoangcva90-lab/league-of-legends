[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
& (Join-Path $PSScriptRoot 'validate-data.ps1') -Quiet

$riot = [IO.File]::ReadAllText((Join-Path $root 'src\data\riot-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$manual = [IO.File]::ReadAllText((Join-Path $root 'src\data\manual-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$combatClasses = [IO.File]::ReadAllText((Join-Path $root 'src\data\combat-classes.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$manualById = @{}; foreach ($champion in $manual.champions) { $manualById[$champion.id] = $champion }
$champions = foreach ($official in $riot.champions) {
    $merged = [ordered]@{ id=$official.id; name=$official.name }
    foreach ($property in $manualById[$official.id].PSObject.Properties) { if ($property.Name -ne 'id') { $merged[$property.Name]=$property.Value } }
    $merged.baseStats = $official.baseStats
    $merged.abilities = $official.abilities
    $merged.skillTags = @($official.abilities | ForEach-Object { @($_.tags) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $merged.capabilities = @(@($merged.capabilities) + @($merged.skillTags) | Select-Object -Unique)
    [pscustomobject]$merged
}
$runtime = [ordered]@{ version=$manual.version; patch=$riot.patch; locale=$riot.locale; champions=$champions; combatClasses=$combatClasses; jungleRoutes=$manual.jungleRoutes; crowdControl=$manual.crowdControl; byId=[ordered]@{}; logic=$manual.logic; dictionary=$manual.dictionary }
$json = $runtime | ConvertTo-Json -Depth 100 -Compress
[IO.File]::WriteAllText((Join-Path $root 'data.js'), "/* Generated from src/data. Do not edit directly. */`nconst LOL_APP_DATA=$json;`n", $utf8)

$datasets = @(
    @('items.json','items.js','LOL_ITEMS'),
    @('matchup-lanes.json','matchup-lanes.js','LOL_MATCHUP_LANES'),
    @('sheet-details.json','sheet-details.js','LOL_SHEET_DETAILS'),
    @('jungle-details.json','jungle-details.js','LOL_JUNGLE_DETAILS')
)
foreach ($item in $datasets) {
    $json = [IO.File]::ReadAllText((Join-Path $root "src\data\$($item[0])"), [Text.Encoding]::UTF8).Trim()
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $root $item[1]), "/* Generated from src/data/$($item[0]). Do not edit directly. */`nconst $($item[2])=$json;`n", $utf8)
}
$teamRulesJson = [IO.File]::ReadAllText((Join-Path $root 'src\data\team-rules.json'), [Text.Encoding]::UTF8).Trim()
$null = $teamRulesJson | ConvertFrom-Json
[IO.File]::WriteAllText((Join-Path $root 'team-rules.js'), "/* Generated from src/data/team-rules.json. Do not edit directly. */`nconst LOL_TEAM_RULES=$teamRulesJson;`n", $utf8)
& (Join-Path $PSScriptRoot 'validate-data.ps1') -Quiet -CheckGenerated
Write-Host "Built runtime data for patch $($riot.patch) with $($champions.Count) champions."
