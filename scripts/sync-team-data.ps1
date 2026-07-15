[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dataRoot = Join-Path $root 'src\data'
$utf8 = New-Object Text.UTF8Encoding($false)

& (Join-Path $PSScriptRoot 'validate-data.ps1') -Quiet
& (Join-Path $PSScriptRoot 'build-data.ps1')

$riot = [IO.File]::ReadAllText((Join-Path $dataRoot 'riot-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$manual = [IO.File]::ReadAllText((Join-Path $dataRoot 'manual-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$manualById = @{}
foreach ($champion in $manual.champions) { $manualById[[string]$champion.id] = $champion }

$champions = foreach ($official in $riot.champions) {
    $merged = [ordered]@{ id = $official.id; name = $official.name }
    foreach ($property in $manualById[[string]$official.id].PSObject.Properties) {
        if ($property.Name -ne 'id') { $merged[$property.Name] = $property.Value }
    }
    $merged.baseStats = $official.baseStats
    $merged.abilities = $official.abilities
    $merged.skillTags = @($official.abilities | ForEach-Object { @($_.tags) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $merged.capabilities = @(@($merged.capabilities) + @($merged.skillTags) | Select-Object -Unique)
    [pscustomobject]$merged
}

$matchupSource = [IO.File]::ReadAllText((Join-Path $dataRoot 'matchup-lanes.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$rules = [IO.File]::ReadAllText((Join-Path $dataRoot 'team-rules.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$nameToId = @{}
foreach ($champion in $riot.champions) {
    $nameToId[([string]$champion.name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()] = [string]$champion.id
    $nameToId[[string]$champion.id] = [string]$champion.id
}
$matchupRows = New-Object Collections.Generic.List[object]
foreach ($championProperty in $matchupSource.champions.PSObject.Properties) {
    $championId = $nameToId[([string]$championProperty.Value.name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()]
    foreach ($laneProperty in $championProperty.Value.lanes.PSObject.Properties) {
        $normalizedLane = if ($laneProperty.Name -eq 'ADC') { 'AD' } else { $laneProperty.Name }
        foreach ($relation in @('counters','bestLane','synergies','bans')) {
            foreach ($opponent in @($laneProperty.Value.$relation)) {
                $opponentId = $nameToId[([string]$opponent -replace '[^a-zA-Z0-9]','').ToLowerInvariant()]
                $matchupRows.Add([pscustomobject]@{ championId=$championId; opponentId=$opponentId; lane=$normalizedLane; relation=$relation; source=$matchupSource.source })
            }
        }
    }
}
$generatedAt = [DateTime]::UtcNow.ToString('o')
$matchups = [ordered]@{ patch=$riot.patch; updatedAt=$generatedAt; matchups=$matchupRows }
$meta = [ordered]@{
    dataVersion = 1
    patch = $riot.patch
    locale = $riot.locale
    championCount = @($champions).Count
    teamFormulaNodes = 1266
    updatedAt = $generatedAt
    sources = @('riot-data.json','manual-data.json','matchup-lanes.json','team-rules.json')
}

$outputs = [ordered]@{
    'champions.json' = $champions
    'matchups.json' = $matchups
    'meta.json' = $meta
}
foreach ($entry in $outputs.GetEnumerator()) {
    $target = Join-Path $dataRoot $entry.Key
    $temporary = "$target.tmp"
    $json = $entry.Value | ConvertTo-Json -Depth 100
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText($temporary, "$json`n", $utf8)
    Move-Item -LiteralPath $temporary -Destination $target -Force
}

$skillCount = @($champions | ForEach-Object { @($_.abilities).Count } | Measure-Object -Sum).Sum
$warningItems = New-Object Collections.Generic.List[string]
foreach ($champion in $manual.champions) {
    if ($champion.id -in @('kledskaarl','megagnar')) { continue }
    if ([string]::IsNullOrWhiteSpace([string]$champion.guide.gamePlan.early)) { $warningItems.Add("$($champion.id): missing game plan") }
    if ([string]::IsNullOrWhiteSpace([string]$champion.guide.powerSpikes.early)) { $warningItems.Add("$($champion.id): missing power spike") }
}
$report = @(
    "Patch: $($riot.patch)"
    "Champions updated: $(@($champions).Count)"
    "Skills updated: $skillCount"
    "Matchups updated: $($matchupRows.Count)"
    "Warnings: $($warningItems.Count)"
    'Errors: 0'
)
if ($warningItems.Count) { $report += $warningItems | ForEach-Object { "- $_" } }
[IO.File]::WriteAllText((Join-Path $dataRoot 'sync-report.txt'), (($report -join "`n") + "`n"), $utf8)

$rulesJson = $rules | ConvertTo-Json -Depth 20 -Compress
[IO.File]::WriteAllText((Join-Path $root 'team-rules.js'), "/* Generated from src/data/team-rules.json. Do not edit directly. */`nconst LOL_TEAM_RULES=$rulesJson;`n", $utf8)

& (Join-Path $PSScriptRoot 'validate-data.ps1') -Quiet -CheckGenerated
Write-Host "Synchronized $(@($champions).Count) champions for patch $($riot.patch)."
