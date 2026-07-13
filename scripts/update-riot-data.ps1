[CmdletBinding()]
param([string]$Patch, [string]$Locale='en_US')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'src\data\riot-data.json'
$current = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
if (-not $Patch) { $Patch = (Invoke-RestMethod 'https://ddragon.leagueoflegends.com/api/versions.json')[0] }
$catalog = Invoke-RestMethod "https://ddragon.leagueoflegends.com/cdn/$Patch/data/$Locale/champion.json"
$oldById=@{}; foreach($c in $current.champions){$oldById[$c.id]=$c}
$champions = foreach($entry in $catalog.data.PSObject.Properties.Value | Sort-Object name) {
    $detail = Invoke-RestMethod "https://ddragon.leagueoflegends.com/cdn/$Patch/data/$Locale/champion/$($entry.id).json"
    $d = $detail.data.$($entry.id); $old=$oldById[$entry.id.ToLowerInvariant()]
    $abilities=@([ordered]@{id='passive';slot='Passive';name=$d.passive.name;cooldown='';tags=@($old.abilities|Where-Object slot -eq 'Passive'|Select-Object -ExpandProperty tags);images=@("https://ddragon.leagueoflegends.com/cdn/$Patch/img/passive/$($d.passive.image.full)");form='base';source='riot'})
    $slots=@('Q','W','E','R'); for($i=0;$i -lt $d.spells.Count;$i++){ $spell=$d.spells[$i]; $previous=@($old.abilities|Where-Object slot -eq $slots[$i]|Select-Object -First 1); $abilities += [ordered]@{id=$slots[$i].ToLowerInvariant();slot=$slots[$i];name=$spell.name;cooldown=($spell.cooldownBurn -join ' / ');tags=@($previous.tags);images=@("https://ddragon.leagueoflegends.com/cdn/$Patch/img/spell/$($spell.image.full)");form='base';source='riot'} }
    if($old){$abilities += @($old.abilities|Where-Object form -eq 'alternate')}
    $s=$d.stats; [ordered]@{id=$entry.id.ToLowerInvariant();name=$d.name;baseStats=[ordered]@{hp=$s.hp;hp18=($s.hp+17*$s.hpperlevel);ad=$s.attackdamage;ad18=($s.attackdamage+17*$s.attackdamageperlevel);as=$s.attackspeed;ar=$s.armor;ar18=($s.armor+17*$s.armorperlevel);mr=$s.spellblock;mr18=($s.spellblock+17*$s.spellblockperlevel);ms=$s.movespeed;range=$s.attackrange;hpGrowth=$s.hpperlevel;adGrowth=$s.attackdamageperlevel;arGrowth=$s.armorperlevel;mrGrowth=$s.spellblockperlevel;mp=$s.mp;mp18=($s.mp+17*$s.mpperlevel);mpGrowth=$s.mpperlevel;hpRegen=$s.hpregen;hpRegenGrowth=$s.hpregenperlevel;mpRegen=$s.mpregen;mpRegenGrowth=$s.mpregenperlevel;asGrowth=$s.attackspeedperlevel};abilities=$abilities}
}
$output=[ordered]@{patch=$Patch;locale=$Locale;updatedAt=(Get-Date).ToUniversalTime().ToString('o');champions=$champions}
$utf8=New-Object Text.UTF8Encoding($false); [IO.File]::WriteAllText($path,($output|ConvertTo-Json -Depth 100 -Compress)+"`n",$utf8)
Write-Host "Updated Riot data to $Patch ($Locale). Run validate-data.ps1, then build-data.ps1."
