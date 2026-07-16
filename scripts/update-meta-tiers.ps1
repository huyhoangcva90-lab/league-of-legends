[CmdletBinding()]
param(
    [string]$Patch,
    [string]$Tier = 'emerald_plus',
    [string]$Region = 'global'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manualPath = Join-Path $root 'src\data\manual-data.json'
$utf8 = New-Object Text.UTF8Encoding($false)
if (-not $Patch) {
    $riotPatch = [string](Invoke-RestMethod 'https://ddragon.leagueoflegends.com/api/versions.json')[0]
    $parts = @($riotPatch -split '\.')
    if ($parts.Count -lt 2) { throw "Unexpected Data Dragon patch '$riotPatch'." }
    $Patch = "$($parts[0]).$($parts[1])"
}
$regionQuery = if ($Region -and $Region -ne 'global') { "&region=$Region" } else { '' }
$url = "https://lolalytics.com/lol/tierlist/?tier=${Tier}&patch=${Patch}${regionQuery}&view=tier"
$html = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content

$headingPattern = '<div class="_tier[^>]+><div class="p-2 text-center text-\[32px\]">(?<tier>[^<]+)</div>'
$headings = [regex]::Matches($html, $headingPattern)
if ($headings.Count -lt 4) { throw "LoLalytics tier groups could not be parsed from $url" }

$sourceRank = @{
    'S+'=14; 'S'=13; 'S-'=12; 'A+'=11; 'A'=10; 'A-'=9
    'B+'=8; 'B'=7; 'B-'=6; 'C+'=5; 'C'=4; 'C-'=3
    'D+'=2; 'D'=1; 'D-'=0
}
$sourceBySlug = @{}
for ($index = 0; $index -lt $headings.Count; $index++) {
    $sourceTier = $headings[$index].Groups['tier'].Value
    if (-not $sourceRank.ContainsKey($sourceTier)) { continue }
    $start = $headings[$index].Index
    $end = if ($index + 1 -lt $headings.Count) { $headings[$index + 1].Index } else { $html.Length }
    $segment = $html.Substring($start, $end - $start)
    $slugs = @([regex]::Matches($segment, 'href="/lol/(?<slug>[^/]+)/build/(?:\?lane=[^"]*)?"') | ForEach-Object { $_.Groups['slug'].Value } | Select-Object -Unique)
    foreach ($slug in $slugs) {
        if (-not $sourceBySlug.ContainsKey($slug) -or $sourceRank[$sourceTier] -gt $sourceRank[$sourceBySlug[$slug]]) {
            $sourceBySlug[$slug] = $sourceTier
        }
    }
}
if ($sourceBySlug.Count -lt 170) { throw "Only $($sourceBySlug.Count) unique champions were parsed from $url" }

function Get-ProjectTier([string]$sourceTier) {
    switch ($sourceTier) {
        'S+' { return 'S+' }
        'S'  { return 'S' }
        'S-' { return 'S' }
        'A+' { return 'A+' }
        default { return 'A' }
    }
}

$manual = [IO.File]::ReadAllText($manualPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$slugAliases = @{ renataglasc='renata'; kledskaarl='kled'; megagnar='gnar' }
$updatedAt = [DateTime]::UtcNow.ToString('o')
$missing = @()
foreach ($champion in $manual.champions) {
    $slug = if ($slugAliases.ContainsKey([string]$champion.id)) { $slugAliases[[string]$champion.id] } else { [string]$champion.id }
    if (-not $sourceBySlug.ContainsKey($slug)) { $missing += [string]$champion.id; continue }
    $sourceTier = [string]$sourceBySlug[$slug]
    $champion.tier = Get-ProjectTier $sourceTier
    $champion.evidence.tier = "lolalytics:${Patch}:${Tier}:${Region}:${sourceTier}"
    if ($null -eq $champion.metadata.PSObject.Properties['tierSource']) { $champion.metadata | Add-Member -NotePropertyName tierSource -NotePropertyValue 'LoLalytics' }
    else { $champion.metadata.tierSource = 'LoLalytics' }
    if ($null -eq $champion.metadata.PSObject.Properties['tierPatch']) { $champion.metadata | Add-Member -NotePropertyName tierPatch -NotePropertyValue $Patch }
    else { $champion.metadata.tierPatch = $Patch }
    if ($null -eq $champion.metadata.PSObject.Properties['tierBracket']) { $champion.metadata | Add-Member -NotePropertyName tierBracket -NotePropertyValue $Tier }
    else { $champion.metadata.tierBracket = $Tier }
    if ($null -eq $champion.metadata.PSObject.Properties['tierRegion']) { $champion.metadata | Add-Member -NotePropertyName tierRegion -NotePropertyValue $Region }
    else { $champion.metadata.tierRegion = $Region }
    if ($null -eq $champion.metadata.PSObject.Properties['sourceTier']) { $champion.metadata | Add-Member -NotePropertyName sourceTier -NotePropertyValue $sourceTier }
    else { $champion.metadata.sourceTier = $sourceTier }
    if ($null -eq $champion.metadata.PSObject.Properties['tierUpdatedAt']) { $champion.metadata | Add-Member -NotePropertyName tierUpdatedAt -NotePropertyValue $updatedAt }
    else { $champion.metadata.tierUpdatedAt = $updatedAt }
}
if ($missing.Count) { throw "Missing LoLalytics tier data for: $($missing -join ', ')" }

[IO.File]::WriteAllText($manualPath, (($manual | ConvertTo-Json -Depth 100 -Compress) + "`n"), $utf8)
$distribution = @($manual.champions | Group-Object tier | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
Write-Host "Updated $($manual.champions.Count) champion tier records from LoLalytics patch $Patch ($Tier, $Region): $distribution"
Write-Host 'Run build-data.ps1, then sync-team-data.ps1.'
