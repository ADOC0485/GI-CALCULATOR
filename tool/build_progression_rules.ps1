$ErrorActionPreference = 'Stop'
# Factual numeric tables only. MIT license retained beside the output.
$revision = '4b873a6decad0384665084c69e9927a9fa266555'
$sourceRoot = "https://raw.githubusercontent.com/MadeBaruna/paimon-moe/$revision"
$characterText = (Invoke-WebRequest "$sourceRoot/src/data/characterExp.js").Content
$weaponText = (Invoke-WebRequest "$sourceRoot/src/data/weaponExp.js").Content
$characters = ($characterText.Substring($characterText.IndexOf('[')).Trim().TrimEnd(';') -replace ',\s*\]', ']') | ConvertFrom-Json
$weapons = $weaponText.Substring($weaponText.IndexOf('[')).Trim().TrimEnd(';') | ConvertFrom-Json
foreach ($table in @($characters, $weapons[0], $weapons[1], $weapons[2])) {
    if ($table.Count -ne 90 -or $table[0] -ne 0) { throw 'Invalid experience table' }
    for ($i = 1; $i -lt 90; $i++) {
        if ($table[$i] -le $table[$i - 1]) { throw 'Non-increasing experience table' }
    }
}
New-Item -ItemType Directory -Force assets/rules | Out-Null
[ordered]@{
    version = '2026.11.23.1'
    gameVersion = '7.2'
    verifiedAt = '2026-11-23'
    source = "$sourceRoot/src/data/characterExp.js"
    weaponSource = "$sourceRoot/src/data/weaponExp.js"
    character = $characters
    weapon3 = $weapons[0]
    weapon4 = $weapons[1]
    weapon5 = $weapons[2]
} | ConvertTo-Json -Depth 8 | Set-Content assets/rules/progression-v1.json
(Invoke-WebRequest "$sourceRoot/LICENSE").Content | Set-Content assets/rules/LICENSE-paimon-moe.txt
Write-Output 'Generated progression-v1.json: 4 cumulative tables, levels 1–90.'
