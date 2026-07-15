[CmdletBinding()]
param([switch]$Quiet, [switch]$CheckGenerated)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$riot = [IO.File]::ReadAllText((Join-Path $root 'src\data\riot-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$manual = [IO.File]::ReadAllText((Join-Path $root 'src\data\manual-data.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$errors = New-Object Collections.Generic.List[string]
$settingPath = Join-Path $root 'lol\setting-data.js'
$setting = $null
if (Test-Path -LiteralPath $settingPath) {
    $settingText = [IO.File]::ReadAllText($settingPath, [Text.Encoding]::UTF8)
    $settingJson = $settingText -replace '^\s*const\s+LOL_SETTING\s*=\s*', '' -replace ';\s*$', ''
    try { $setting = $settingJson | ConvertFrom-Json } catch { $errors.Add("setting-data.js: invalid LOL_SETTING payload: $($_.Exception.Message)") }
} else { $errors.Add('setting-data.js: required Setting contract is missing.') }

if ([string]::IsNullOrWhiteSpace($riot.patch)) { $errors.Add('riot-data.json: patch is required.') }
$riotIds = @($riot.champions | ForEach-Object { $_.id })
$manualIds = @($manual.champions | ForEach-Object { $_.id })
$manualById = @{}; foreach ($champion in $manual.champions) { $manualById[$champion.id] = $champion }
foreach ($id in $riotIds | Group-Object | Where-Object Count -gt 1) { $errors.Add("riot-data.json: duplicate champion id '$($id.Name)'.") }
foreach ($id in $manualIds | Group-Object | Where-Object Count -gt 1) { $errors.Add("manual-data.json: duplicate champion id '$($id.Name)'.") }
foreach ($id in $riotIds | Where-Object { $_ -notin $manualIds }) { $errors.Add("manual-data.json: missing champion '$id'.") }
foreach ($id in $manualIds | Where-Object { $_ -notin $riotIds }) { $errors.Add("riot-data.json: missing champion '$id'.") }
foreach ($champion in $riot.champions) {
    if ([string]::IsNullOrWhiteSpace($champion.name) -or $null -eq $champion.baseStats -or @($champion.abilities).Count -eq 0) { $errors.Add("riot-data.json: '$($champion.id)' requires name, baseStats and abilities.") }
    foreach ($slot in @('Passive','Q','W','E','R')) {
        $core = @($champion.abilities | Where-Object { [string]$_.slot -ceq $slot })
        if ($core.Count -ne 1) { $errors.Add("riot-data.json: '$($champion.id)' requires exactly one core '$slot' ability; found $($core.Count).") }
        elseif (@($core[0].images).Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$core[0].images[0]) -or [string]$core[0].images[0] -notmatch '^https://') { $errors.Add("riot-data.json: '$($champion.id).$slot' requires an HTTPS skill image.") }
    }
    foreach ($ability in @($champion.abilities)) {
        $abilityKey = "$($champion.id).$($ability.id)"
        if ([string]::IsNullOrWhiteSpace([string]$ability.id) -or [string]::IsNullOrWhiteSpace([string]$ability.slot) -or [string]::IsNullOrWhiteSpace([string]$ability.name)) { $errors.Add("riot-data.json: '$abilityKey' requires id, slot and name.") }
        if ($null -eq $ability.tags -or $null -eq $ability.images) { $errors.Add("riot-data.json: '$abilityKey' requires tags and images arrays (empty is allowed).") }
        if ([string]$ability.name -match '[\r\n]' -or [string]$ability.name -match '(?i)^\s*edit\s+') { $errors.Add("riot-data.json: '$abilityKey' contains unnormalized sheet text in its name.") }
        $cooldown = [string]$ability.cooldown
        if ($cooldown -match '^\d+(\.\d+)?$' -and [double]$cooldown -gt 1000) { $errors.Add("riot-data.json: '$abilityKey' cooldown '$cooldown' looks like an Excel date serial.") }
    }
}
$specialNames = [ordered]@{
    velkoz = "Vel'Koz"; ksante = "K'Sante"; kaisa = "Kai'Sa"; chogath = "Cho'Gath"
    reksai = "Rek'Sai"; belveth = "Bel'Veth"; nunu = 'Nunu'
}
$riotById = @{}; foreach ($champion in $riot.champions) { $riotById[[string]$champion.id] = $champion }
foreach ($pair in $specialNames.GetEnumerator()) {
    if (-not $riotById.ContainsKey($pair.Key)) { $errors.Add("riot-data.json: required special-name champion '$($pair.Key)' is missing."); continue }
    if ([string]$riotById[$pair.Key].name -cne [string]$pair.Value) { $errors.Add("riot-data.json: '$($pair.Key).name' must preserve workbook spelling '$($pair.Value)'.") }
}
$knownNames = @{}; foreach ($champion in $riot.champions) { $knownNames[($champion.name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()] = $true; $knownNames[$champion.id.ToLowerInvariant()] = $true }
foreach ($champion in $manual.champions) {
    if ([string]$champion.damage.type -notin @('Physical','Magic','Hybrid','True')) { $errors.Add("manual-data.json: '$($champion.id).damage.type' is invalid.") }
    $attackShare = 0.0
    if (-not [double]::TryParse([string]$champion.damage.basicAttackShare, [ref]$attackShare) -or $attackShare -lt 0 -or $attackShare -gt 1) { $errors.Add("manual-data.json: '$($champion.id).damage.basicAttackShare' must be between 0 and 1.") }
    foreach ($role in @($champion.roles)) {
        if ($role -notin @('Top','Jungle','Mid','AD','Support')) { $errors.Add("manual-data.json: '$($champion.id).roles' contains invalid role '$role'.") }
    }
    foreach ($phase in @('early','mid','late')) {
        $value = [string]$champion.power.$phase
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value -notin @('Weak','Average','Strong')) { $errors.Add("manual-data.json: '$($champion.id).power.$phase' contains invalid value '$value'.") }
    }
    foreach ($rating in @($champion.ratings.PSObject.Properties)) {
        $number = 0.0
        if ($null -ne $rating.Value -and -not [double]::TryParse([string]$rating.Value, [ref]$number)) { $errors.Add("manual-data.json: '$($champion.id).ratings.$($rating.Name)' must be numeric.") }
        elseif ($rating.Name -in @('clearwave','tower') -and ($number -lt 0 -or $number -gt 100)) { $errors.Add("manual-data.json: '$($champion.id).ratings.$($rating.Name)' must be between 0 and 100.") }
        elseif ($rating.Name -notin @('clearwave','tower') -and ($number -lt 0 -or $number -gt 5)) { $errors.Add("manual-data.json: '$($champion.id).ratings.$($rating.Name)' must be between 0 and 5.") }
    }
    if ($champion.id -notin @('kledskaarl','megagnar')) {
        foreach ($phase in @('early','mid','late')) {
            if ([string]::IsNullOrWhiteSpace([string]$champion.guide.gamePlan.$phase)) { $errors.Add("manual-data.json: '$($champion.id).guide.gamePlan.$phase' is required.") }
            if ([string]::IsNullOrWhiteSpace([string]$champion.guide.powerSpikes.$phase)) { $errors.Add("manual-data.json: '$($champion.id).guide.powerSpikes.$phase' is required.") }
        }
    }
    foreach ($group in @('counters','bestLane','synergies','bans')) {
        foreach ($name in @($champion.matchups.$group)) {
            $key = ([string]$name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
            if ($key -and -not $knownNames.ContainsKey($key)) { $errors.Add("manual-data.json: '$($champion.id).matchups.$group' references unknown champion '$name'.") }
        }
    }
}
$laneSource = [IO.File]::ReadAllText((Join-Path $root 'src\data\matchup-lanes.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
foreach ($championProperty in $laneSource.champions.PSObject.Properties) {
    foreach ($laneProperty in $championProperty.Value.lanes.PSObject.Properties) {
        if ($laneProperty.Name -notin @('Top','Jungle','Mid','AD','ADC','Support')) { $errors.Add("matchup-lanes.json: '$($championProperty.Name)' contains invalid lane '$($laneProperty.Name)'.") }
        foreach ($group in @('counters','bestLane','synergies','bans')) {
            foreach ($name in @($laneProperty.Value.$group)) {
                $key = ([string]$name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
                if ($key -and -not $knownNames.ContainsKey($key)) { $errors.Add("matchup-lanes.json: '$($championProperty.Name).$($laneProperty.Name).$group' references unknown champion '$name'.") }
            }
        }
    }
}
if ($CheckGenerated) {
    function Read-GeneratedPayload([string]$fileName, [string]$constantName) {
        $path = Join-Path $root $fileName
        if (-not (Test-Path -LiteralPath $path)) { $errors.Add("$fileName`: generated runtime file is missing."); return $null }
        $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        $pattern = '(?s)^\s*/\*.*?\*/\s*const\s+' + [regex]::Escape($constantName) + '\s*=\s*(\{.*\})\s*;\s*$'
        $match = [regex]::Match($text, $pattern)
        if (-not $match.Success) { $errors.Add("$fileName`: expected a single '$constantName' JSON payload."); return $null }
        try { return $match.Groups[1].Value | ConvertFrom-Json } catch { $errors.Add("$fileName`: invalid generated JSON: $($_.Exception.Message)"); return $null }
    }
    $runtime = Read-GeneratedPayload 'data.js' 'LOL_APP_DATA'
    if ($null -ne $runtime) {
        if ([string]$runtime.patch -ne [string]$riot.patch) { $errors.Add("data.js: patch '$($runtime.patch)' does not match source '$($riot.patch)'.") }
        if ([string]$runtime.locale -ne [string]$riot.locale) { $errors.Add("data.js: locale '$($runtime.locale)' does not match source '$($riot.locale)'.") }
        $runtimeById = @{}; foreach ($champion in @($runtime.champions)) { $runtimeById[$champion.id] = $champion }
        foreach ($official in $riot.champions) {
            if (-not $runtimeById.ContainsKey($official.id)) { $errors.Add("data.js: missing generated champion '$($official.id)'."); continue }
            $generated = $runtimeById[$official.id]
            if ([string]$generated.name -ne [string]$official.name) { $errors.Add("data.js: '$($official.id).name' is stale.") }
            if (@($generated.abilities).Count -ne @($official.abilities).Count) { $errors.Add("data.js: '$($official.id).abilities' count is stale.") }
            $expectedSkillTags = @($official.abilities | ForEach-Object { @($_.tags) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique) -join '|'
            if ((@($generated.skillTags) -join '|') -cne $expectedSkillTags) { $errors.Add("data.js: '$($official.id).skillTags' is stale.") }
            $generatedRoles = @($generated.roles) -join '|'
            $sourceRoles = @($manualById[$official.id].roles) -join '|'
            if ($generatedRoles -cne $sourceRoles) { $errors.Add("data.js: '$($official.id).roles' is stale.") }
        }
        foreach ($id in @($runtimeById.Keys)) { if ($id -notin $riotIds) { $errors.Add("data.js: contains unknown generated champion '$id'.") } }
        if (@($runtime.jungleRoutes).Count -ne @($manual.jungleRoutes).Count) { $errors.Add('data.js: jungle route count is stale.') }
        if (@($runtime.crowdControl).Count -ne @($manual.crowdControl).Count) { $errors.Add('data.js: crowd-control count is stale.') }
    }
    foreach ($dataset in @(@('matchup-lanes.json','matchup-lanes.js','LOL_MATCHUP_LANES'),@('sheet-details.json','sheet-details.js','LOL_SHEET_DETAILS'),@('jungle-details.json','jungle-details.js','LOL_JUNGLE_DETAILS'))) {
        $source = [IO.File]::ReadAllText((Join-Path $root "src\data\$($dataset[0])"), [Text.Encoding]::UTF8) | ConvertFrom-Json
        $generated = Read-GeneratedPayload $dataset[1] $dataset[2]
        if ($null -ne $generated) {
            $sourceJson = $source | ConvertTo-Json -Depth 100 -Compress
            $generatedJson = $generated | ConvertTo-Json -Depth 100 -Compress
            if ($sourceJson -cne $generatedJson) { $errors.Add("$($dataset[1]): generated payload is stale.") }
        }
    }
    $teamRulesSource = [IO.File]::ReadAllText((Join-Path $root 'src\data\team-rules.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
    $teamRulesGenerated = Read-GeneratedPayload 'team-rules.js' 'LOL_TEAM_RULES'
    if ($null -ne $teamRulesGenerated) {
        if (($teamRulesSource | ConvertTo-Json -Depth 20 -Compress) -cne ($teamRulesGenerated | ConvertTo-Json -Depth 20 -Compress)) { $errors.Add('team-rules.js: generated payload is stale.') }
    }
}
if ($null -ne $setting) {
    $requiredSettingRanges = @('teamBlueTopOptions','teamBlueJungleOptions','teamBlueMidOptions','teamBlueAdOptions','teamBlueSupportOptions','checkFeature1','checkFeature2','checkFeature3','checkFeature4','checkFeature5','checkCounter1','checkCounter2','checkCounter3','checkCounter4','checkCounter5','banPickChampionPool')
    foreach ($key in $requiredSettingRanges) {
        if ([string]::IsNullOrWhiteSpace([string]$setting.ranges.$key)) { $errors.Add("setting-data.js: missing Setting range '$key'.") }
    }
    $settingNames = @($setting.named.allChampions | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    foreach ($name in $settingNames) {
        $key = ([string]$name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
        if (-not $knownNames.ContainsKey($key)) { $errors.Add("setting-data.js: allChampions references unknown champion '$name'.") }
    }
    foreach ($key in @('teamBlueTopOptions','teamBlueJungleOptions','teamBlueMidOptions','teamBlueAdOptions','teamBlueSupportOptions')) {
        foreach ($name in @($setting.named.$key | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
            $normalized = ([string]$name -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
            if (-not $knownNames.ContainsKey($normalized)) { $errors.Add("setting-data.js: '$key' references unknown champion '$name'.") }
        }
    }
}
if ($errors.Count) { throw ($errors -join "`n") }
if (-not $Quiet) { Write-Host "Validated $($riot.champions.Count) champions for patch $($riot.patch), including the Setting range contract$(if($CheckGenerated){' and generated runtime parity'})." }
