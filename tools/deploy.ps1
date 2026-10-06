# Links the addon into the WoW client as "DarkmoonArcade_Dev", so every change is live after /reload
# and addon managers never mistake the test copy for the released addon.
# Usage: powershell -File tools/deploy.ps1 [-AddOnsDir <path>] [-Copy]
param(
    [string]$AddOnsDir = "G:\Battle.net\World of Warcraft\_classic_beta_\Interface\AddOns",
    [switch]$Copy
)
$ErrorActionPreference = "Stop"
$name = "DarkmoonArcade_Dev"
$source = Join-Path $PSScriptRoot "..\DarkmoonArcade" | Resolve-Path
$target = Join-Path $AddOnsDir $name

# WoW loads the TOC named like the folder. The dev TOC is generated and never committed.
$toc = Get-Content (Join-Path $source "DarkmoonArcade.toc") -Encoding UTF8
$toc = $toc -replace '^## Title: .*$', '## Title: Darkmoon Arcade |cffff8000(Dev)|r' -replace 'AddOns\\DarkmoonArcade\\', "AddOns\$name\"
[System.IO.File]::WriteAllLines((Join-Path $source "$name.toc"), $toc, (New-Object System.Text.UTF8Encoding($false)))

# Older setups linked the repo under the release name; drop that link so the release can install there.
$legacy = Join-Path $AddOnsDir "DarkmoonArcade"
if (Test-Path $legacy) {
    $item = Get-Item $legacy -Force
    if ($item.LinkType -eq "Junction" -and $item.Target -contains $source.Path) {
        cmd /c rmdir "$legacy"
        Write-Host "Removed old link $legacy"
    }
}

if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType -eq "Junction" -and -not $Copy) {
        Write-Host "Already linked: $target -> $($item.Target)"
        exit 0
    }
    if ($item.LinkType) { cmd /c rmdir "$target" } else { Remove-Item $target -Recurse -Force }
}

if ($Copy) {
    Copy-Item $source $target -Recurse
    Write-Host "Copied to $target"
} else {
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Write-Host "Linked $target -> $source"
}
