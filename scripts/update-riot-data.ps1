[CmdletBinding()]
param([string]$Patch, [string]$Locale='en_US')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$riotPath = Join-Path $root 'src\data\riot-data.json'
$manualPath = Join-Path $root 'src\data\manual-data.json'
$utf8 = New-Object Text.UTF8Encoding($false)
$current = [IO.File]::ReadAllText($riotPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$manual = [IO.File]::ReadAllText($manualPath, [Text.Encoding]::UTF8) | ConvertFrom-Json

if (-not $Patch) { $Patch = (Invoke-RestMethod 'https://ddragon.leagueoflegends.com/api/versions.json')[0] }
$catalog = Invoke-RestMethod "https://ddragon.leagueoflegends.com/cdn/$Patch/data/$Locale/champion.json"

function Get-NormalizedChampionId([string]$riotId) {
    $key = $riotId.ToLowerInvariant()
    $aliases = @{ monkeyking='wukong'; renata='renataglasc' }
    if ($aliases.ContainsKey($key)) { return $aliases[$key] }
    return $key
}

function Get-InferredAbilityTags([string]$text) {
    $rules = [ordered]@{
        'Dash'='\bdash|leap|lunge|rushes|charges? forward|blink|teleport'
        'Heal'='\bheal|restores? health|healing'
        'Shield'='\bshield'
        'Slow'='\bslow'
        'Stun'='\bstun'
        'Root'='\broot|snare|immobili[sz]'
        'Airborne'='knock(?:s|ed)? (?:up|back)|airborne'
        'Fear'='\bfear|flee'
        'Taunt'='\btaunt'
        'Silence'='\bsilence'
        'Execute'='\bexecute|missing health'
        'On-Hit'='on[ -]hit'
        'Bonus AS'='attack speed'
        'Speed'='move(?:ment)? speed'
        'Sight'='reveal|vision|true sight'
        'Stealth'='stealth|camouflage|invisible'
        'Invulnerability'='invulnerab|immune to damage'
        'Cleanse'='cleanse|removes? (?:all )?crowd control'
        'Disengage'='knock(?:s|ed)? back|pushes? away'
        'Poke'='long range|from range'
        'Aoe'='nearby enemies|all enemies|area|around (?:him|her|them)|in a cone'
    }
    $tags = @()
    foreach ($rule in $rules.GetEnumerator()) { if ($text -match $rule.Value) { $tags += $rule.Key } }
    return $tags
}

function New-ManualChampion($entry, $detail, [string]$id, $abilities) {
    $officialTags = @($entry.tags)
    $roles = switch ($id) {
        'locke' { @('Mid') }
        'zaahen' { @('Top') }
        default {
            if ('Marksman' -in $officialTags) { @('AD') }
            elseif ('Support' -in $officialTags) { @('Support') }
            elseif ('Mage' -in $officialTags -or 'Assassin' -in $officialTags) { @('Mid') }
            elseif ('Tank' -in $officialTags -or 'Fighter' -in $officialTags) { @('Top') }
            else { @('Mid') }
        }
    }
    $primaryClass = if ('Marksman' -in $officialTags) { 'Marksman' } elseif ('Tank' -in $officialTags) { 'Tank' } elseif ('Fighter' -in $officialTags) { 'Fighter' } elseif ('Assassin' -in $officialTags) { 'Slayer' } elseif ('Mage' -in $officialTags) { 'Mage' } else { 'Specialist' }
    $secondaryClass = if ('Assassin' -in $officialTags) { 'Assassin' } elseif ('Fighter' -in $officialTags) { 'Fighter' } elseif ('Mage' -in $officialTags) { 'Mage' } elseif ('Support' -in $officialTags) { 'Enchanter' } else { '' }
    $damageType = if ('Mage' -in $officialTags) { 'Magic' } else { 'Physical' }
    $range = if ([double]$detail.stats.attackrange -ge 350) { 'Ranged' } else { 'Melee' }
    $combatPrimary = if ($primaryClass -eq 'Tank' -or $primaryClass -eq 'Fighter') { 'Engage' } elseif ($primaryClass -eq 'Slayer') { 'Catch' } elseif ($primaryClass -eq 'Mage' -or $primaryClass -eq 'Marksman') { 'Poke' } else { 'Catch' }
    $positioning = if ($range -eq 'Ranged') { @('Midline','Backline') } else { @('Frontline','Midline','Flank') }
    $difficulty = [math]::Max(1, [math]::Min(3, [math]::Ceiling(([double]$detail.info.difficulty) / 3.34)))
    $capabilities = @($abilities | ForEach-Object { @($_.tags) } | Where-Object { $_ } | Select-Object -Unique)
    $firstSpell = [string](@($abilities | Where-Object slot -eq 'Q' | Select-Object -First 1).name)
    $ultimate = [string](@($abilities | Where-Object slot -eq 'R' | Select-Object -First 1).name)
    $roleText = $roles -join ' / '
    $year = [DateTime]::UtcNow.Year
    $profile = if ($damageType -eq 'Magic') { 'Burst AP' } elseif ($primaryClass -eq 'Marksman') { 'Dps AD' } else { 'Burst Dps AD' }
    $basicShare = if ($primaryClass -eq 'Marksman') { 0.75 } elseif ($primaryClass -eq 'Fighter') { 0.55 } elseif ($primaryClass -eq 'Slayer') { 0.35 } else { 0.15 }
    $safeName = [uri]::EscapeDataString(([string]$entry.name).ToLowerInvariant().Replace(' ', '-'))
    return [pscustomobject][ordered]@{
        id=$id; links=[ordered]@{guide="https://www.leagueoflegends.com/en-us/champions/$safeName/"}; roles=$roles; primaryRole=$roles[0]; range=$range
        classification=[ordered]@{primary=$primaryClass;secondary=$secondaryClass;tertiary=(@($officialTags | Where-Object { $_ -notin @($primaryClass,$secondaryClass) }) -join ', ')}
        power=[ordered]@{early='Average';mid='Average';late=if($primaryClass -eq 'Marksman'){'Strong'}else{'Average'}}
        combat=[ordered]@{primary=$combatPrimary;secondary='';macro=if($range -eq 'Melee'){'Split'}else{''};positioning=$positioning}
        damage=[ordered]@{profile=$profile;type=$damageType;basicAttackShare=$basicShare}
        capabilities=$capabilities
        profiles=[ordered]@{mastery=$false;carry=($primaryClass -in @('Marksman','Slayer','Fighter'));hyperCarry=($primaryClass -eq 'Marksman');flex=$false}
        difficulty=$difficulty;tier=$null
        ratings=[ordered]@{damage=[math]::Max(1,[math]::Min(5,[math]::Ceiling(([double]$detail.info.attack)/2)));toughness=[math]::Max(1,[math]::Min(5,[math]::Ceiling(([double]$detail.info.defense)/2)));control=if($capabilities -match 'Stun|Root|Airborne|Fear|Taunt'){2}else{1};mobility=if($capabilities -match 'Dash|Speed'){2}else{1};utility=if($capabilities -match 'Heal|Shield|Sight|Cleanse'){2}else{1};clearwave=50;tower=if($primaryClass -eq 'Marksman'){75}else{50}}
        guide=[ordered]@{
            strengths="$($entry.name) is a newly synchronized $roleText champion. Build trades around $firstSpell and preserve $ultimate for the highest-value fight or objective window."
            weaknesses="This profile was generated from Riot's live champion data and should be reviewed as the competitive meta develops. Avoid forcing plays while key cooldowns are unavailable."
            gamePlan=[ordered]@{early="Learn the lane pattern, protect health and trade around $firstSpell.";mid="Move with priority toward objectives and coordinate $ultimate with allied setup.";late="Respect enemy engage ranges, hold a stable formation and use $ultimate in the decisive fight."}
            powerSpikes=[ordered]@{early="Level 3 unlocks the full basic kit; level 6 adds $ultimate.";mid="The first completed items and rank two $ultimate improve objective fights.";late="Full items and rank three $ultimate define the final teamfight ceiling."}
        }
        matchups=[ordered]@{counters=@();bestLane=@();synergies=@();bans=@()}
        metadata=[ordered]@{releaseYear=$year;patch=$Patch;autoGenerated=$true}
        evidence=[ordered]@{roles='riot-auto-baseline';range='riot-stats';capabilities='derived-from-riot-ability-text';tier='pending-meta-review'}
        guideVi=[ordered]@{
            strengths="$($entry.name) la tuong moi duoc dong bo cho vi tri $roleText. Hay trao doi quanh $firstSpell va giu $ultimate cho giao tranh hoac muc tieu quan trong nhat."
            weaknesses="Ho so nay duoc tao tu du lieu Riot dang hoat dong va can tiep tuc ra theo meta thi dau. Tranh ep giao tranh khi ky nang chu chot dang hoi."
            gamePlan=[ordered]@{early="Lam quen nhip di duong, giu mau va trao doi quanh $firstSpell.";mid="Di chuyen theo quyen uu tien toi muc tieu va phoi hop $ultimate voi dong doi.";late="Ton trong tam mo giao tranh cua doi thu, giu doi hinh on dinh va dung $ultimate trong giao tranh quyet dinh."}
            powerSpikes=[ordered]@{early="Cap 3 mo du bo ky nang co ban; cap 6 co them $ultimate.";mid="Trang bi hoan chinh dau tien va cap hai cua $ultimate tang suc manh tranh muc tieu.";late="Du trang bi va cap ba cua $ultimate quyet dinh tran suc manh giao tranh cuoi tran."}
        }
    }
}

$oldById=@{}; foreach($champion in $current.champions){$oldById[[string]$champion.id]=$champion}
$manualById=@{}; foreach($champion in $manual.champions){$manualById[[string]$champion.id]=$champion}
$champions = @()
$newManual = @()

foreach($entry in $catalog.data.PSObject.Properties.Value | Sort-Object name) {
    $detail = Invoke-RestMethod "https://ddragon.leagueoflegends.com/cdn/$Patch/data/$Locale/champion/$($entry.id).json"
    $d = $detail.data.$($entry.id)
    $id = Get-NormalizedChampionId $entry.id
    $old = $oldById[$id]
    $passiveTags = @(@($old.abilities | Where-Object slot -eq 'Passive' | Select-Object -First 1).tags + @(Get-InferredAbilityTags "$($d.passive.description) $($d.passive.name)") | Where-Object { $_ } | Select-Object -Unique)
    $abilities = @()
    $abilities += [pscustomobject][ordered]@{id='passive';slot='Passive';name=$d.passive.name;cooldown='';tags=$passiveTags;images=@("https://ddragon.leagueoflegends.com/cdn/$Patch/img/passive/$($d.passive.image.full)");form='base';source='riot'}
    $slots=@('Q','W','E','R')
    for($i=0;$i -lt $d.spells.Count;$i++) {
        $spell=$d.spells[$i]
        $previous=@($old.abilities | Where-Object slot -eq $slots[$i] | Select-Object -First 1)
        $tags=@(@($previous.tags)+@(Get-InferredAbilityTags "$($spell.description) $($spell.name)")|Where-Object {$_}|Select-Object -Unique)
        $abilities += [pscustomobject][ordered]@{id=$slots[$i].ToLowerInvariant();slot=$slots[$i];name=$spell.name;cooldown=($spell.cooldownBurn -join ' / ');tags=$tags;images=@("https://ddragon.leagueoflegends.com/cdn/$Patch/img/spell/$($spell.image.full)");form='base';source='riot'}
    }
    if($old){foreach($alternate in @($old.abilities|Where-Object form -eq 'alternate')){$abilities += $alternate}}
    $s=$d.stats
    $displayName = if($id -eq 'nunu'){'Nunu'}else{$d.name}
    $champions += [pscustomobject][ordered]@{id=$id;name=$displayName;baseStats=[ordered]@{hp=$s.hp;hp18=($s.hp+17*$s.hpperlevel);ad=$s.attackdamage;ad18=($s.attackdamage+17*$s.attackdamageperlevel);as=$s.attackspeed;ar=$s.armor;ar18=($s.armor+17*$s.armorperlevel);mr=$s.spellblock;mr18=($s.spellblock+17*$s.spellblockperlevel);ms=$s.movespeed;range=$s.attackrange;hpGrowth=$s.hpperlevel;adGrowth=$s.attackdamageperlevel;arGrowth=$s.armorperlevel;mrGrowth=$s.spellblockperlevel;mp=$s.mp;mp18=($s.mp+17*$s.mpperlevel);mpGrowth=$s.mpperlevel;hpRegen=$s.hpregen;hpRegenGrowth=$s.hpregenperlevel;mpRegen=$s.mpregen;mpRegenGrowth=$s.mpregenperlevel;asGrowth=$s.attackspeedperlevel};abilities=@($abilities)}
    if(-not $manualById.ContainsKey($id)){$newManual += New-ManualChampion $entry $d $id @($abilities)}
}

# Preserve workbook-only form records while updating their image URLs to the live patch.
foreach($customId in @('kledskaarl','megagnar')) {
    if(-not $oldById.ContainsKey($customId)){continue}
    $custom=$oldById[$customId]
    foreach($ability in @($custom.abilities)){for($i=0;$i -lt @($ability.images).Count;$i++){$ability.images[$i]=[regex]::Replace([string]$ability.images[$i],'/cdn/[^/]+/','/cdn/'+$Patch+'/')}}
    $champions += $custom
}

if($newManual.Count){$manual.champions=@(@($manual.champions)+@($newManual)|Sort-Object id)}
$output=[ordered]@{patch=$Patch;locale=$Locale;updatedAt=(Get-Date).ToUniversalTime().ToString('o');champions=@($champions|Sort-Object name)}
[IO.File]::WriteAllText($riotPath,(($output|ConvertTo-Json -Depth 100 -Compress)+"`n"),$utf8)
[IO.File]::WriteAllText($manualPath,(($manual|ConvertTo-Json -Depth 100 -Compress)+"`n"),$utf8)
Write-Host "Updated Riot data to $Patch ($Locale): $($champions.Count) records, $($newManual.Count) new manual baselines."
Write-Host 'Run validate-data.ps1, build-data.ps1, then sync-team-data.ps1.'
