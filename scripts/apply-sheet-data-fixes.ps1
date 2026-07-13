[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'src\data\riot-data.json'
$utf8 = New-Object Text.UTF8Encoding($false)
$data = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json

# Values verified against the live Google Sheet `Skill` tab.
$cooldownFixes = @{
    'azir:w'       = '1.5'
    'cassiopeia:q' = '3.5'
    'gangplank:q'  = '4.5'
    'sejuani:e'    = '1.5'
    'trundle:q'    = '3.5'
    'yunara:e'     = '7.5'
    'yuumi:q'      = '6.5'
}

$nameFixes = @{
    'kledskaarl:w' = 'Violent Tendencies'
    'mel:passive' = 'Searing Brilliance'
    'yunara:w'    = 'Arc of Judgment'
    'yunara:r'    = "Transcend One's Self"
}

$changes = 0
foreach ($champion in $data.champions) {
    foreach ($ability in $champion.abilities) {
        $key = "$($champion.id):$($ability.id)"
        if ($cooldownFixes.ContainsKey($key) -and $ability.cooldown -ne $cooldownFixes[$key]) {
            $ability.cooldown = $cooldownFixes[$key]
            $changes++
        }
        if ($nameFixes.ContainsKey($key) -and $ability.name -ne $nameFixes[$key]) {
            $ability.name = $nameFixes[$key]
            $changes++
        }
    }
}

[IO.File]::WriteAllText($path, ($data | ConvertTo-Json -Depth 100 -Compress) + "`n", $utf8)
Write-Host "Applied $changes Google Sheet data corrections."
