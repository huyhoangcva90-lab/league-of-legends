[CmdletBinding()]
param([string]$Patch, [string]$Locale='en_US')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root 'src\data\items.json'
$utf8 = New-Object Text.UTF8Encoding($false)

if (-not $Patch) { $Patch = (Invoke-RestMethod 'https://ddragon.leagueoflegends.com/api/versions.json')[0] }
$sourceUrl = "https://ddragon.leagueoflegends.com/cdn/$Patch/data/$Locale/item.json"
$catalog = Invoke-RestMethod $sourceUrl
$imageBaseUrl = "https://ddragon.leagueoflegends.com/cdn/$Patch/img/item/"

$items = @(
    $catalog.data.PSObject.Properties |
        Where-Object { $_.Value.maps.'11' -eq $true } |
        Sort-Object { [int64]$_.Name } |
        ForEach-Object {
            $id = [string]$_.Name
            $item = $_.Value
            [pscustomobject][ordered]@{
                id = $id
                name = [string]$item.name
                description = [string]$item.description
                plaintext = [string]$item.plaintext
                image = "$imageBaseUrl$($item.image.full)"
                gold = [ordered]@{
                    base = [int]$item.gold.base
                    total = [int]$item.gold.total
                    sell = [int]$item.gold.sell
                    purchasable = [bool]$item.gold.purchasable
                }
                tags = @($item.tags | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                stats = $item.stats
                from = @($item.from | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
                into = @($item.into | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
                depth = if ($null -eq $item.depth) { $null } else { [int]$item.depth }
                inStore = if ($null -eq $item.inStore) { $null } else { [bool]$item.inStore }
                hideFromAll = if ($null -eq $item.hideFromAll) { $null } else { [bool]$item.hideFromAll }
                consumed = if ($null -eq $item.consumed) { $null } else { [bool]$item.consumed }
                consumeOnFull = if ($null -eq $item.consumeOnFull) { $null } else { [bool]$item.consumeOnFull }
                requiredChampion = [string]$item.requiredChampion
                requiredAlly = [string]$item.requiredAlly
                specialRecipe = if ($null -eq $item.specialRecipe) { $null } else { [int]$item.specialRecipe }
                effect = if ($null -eq $item.effect) { [pscustomobject]@{} } else { $item.effect }
            }
        }
)

$output = [ordered]@{
    patch = $Patch
    locale = $Locale
    updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    source = $sourceUrl
    map = [ordered]@{ id = 11; name = "Summoner's Rift" }
    filter = 'maps.11 == true'
    count = $items.Count
    items = $items
}

[IO.File]::WriteAllText($target, (($output | ConvertTo-Json -Depth 30 -Compress) + "`n"), $utf8)
Write-Host "Updated $($items.Count) Summoner's Rift items for patch $Patch ($Locale)."
