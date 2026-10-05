# Links the addon into the WoW client so every change is live after /reload.
# Usage: powershell -File tools/deploy.ps1 [-AddOnsDir <path>] [-Copy]
param(
    [string]$AddOnsDir = "G:\Battle.net\World of Warcraft\_classic_beta_\Interface\AddOns",
    [switch]$Copy
)
$ErrorActionPreference = "Stop"
$source = Join-Path $PSScriptRoot "..\DarkmoonArcade" | Resolve-Path
$target = Join-Path $AddOnsDir "DarkmoonArcade"

if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType -eq "Junction" -and -not $Copy) {
        Write-Host "Already linked: $target -> $($item.Target)"
        exit 0
    }
    if ($item.LinkType) { $item.Delete() } else { Remove-Item $target -Recurse -Force }
}

if ($Copy) {
    Copy-Item $source $target -Recurse
    Write-Host "Copied to $target"
} else {
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Write-Host "Linked $target -> $source"
}
