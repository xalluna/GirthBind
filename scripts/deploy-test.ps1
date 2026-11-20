<#
.SYNOPSIS
    Copies the addon into Interface\AddOns\GirthBind.Test so /reload picks up local changes.

.DESCRIPTION
    The copy is a "dev copy": its TOC is renamed to GirthBind.Test.toc, titled "GirthBind (Test)",
    and given its own SavedVariables (GirthBindTestDB), so it never touches the release build's
    settings. If the CurseForge release (GirthBind) is also enabled, the dev copy turns itself off
    at load and says so in chat.

    The AddOns folder comes from -AddOnsPath, else $env:GIRTHBIND_ADDONS, else the first
    "World of Warcraft\_forever_\Interface\AddOns" found on a local drive.

.EXAMPLE
    ./scripts/deploy-test.ps1
    ./scripts/deploy-test.ps1 -AddOnsPath "E:\World of Warcraft\_forever_\Interface\AddOns"
#>
[CmdletBinding()]
param(
    [string]$AddOnsPath = $env:GIRTHBIND_ADDONS,
    [string]$Name = "GirthBind.Test"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

if (-not $AddOnsPath) {
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        foreach ($base in @("", "Program Files (x86)\", "Program Files\", "Games\")) {
            $candidate = Join-Path $drive.Root "${base}World of Warcraft\_forever_\Interface\AddOns"
            if (Test-Path $candidate) { $AddOnsPath = $candidate; break }
        }
        if ($AddOnsPath) { break }
    }
}
if (-not $AddOnsPath -or -not (Test-Path $AddOnsPath)) {
    throw "Couldn't find the WoW Forever AddOns folder. Pass -AddOnsPath or set GIRTHBIND_ADDONS."
}

$target = Join-Path $AddOnsPath $Name
$svName = ($Name -replace "[^A-Za-z0-9]", "") + "DB" # must match ns.SV_NAME in src/Init.lua

# Fresh copy of exactly what the game loads.
if (Test-Path $target) {
    Get-ChildItem -Path $target -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $target | Out-Null
}
foreach ($item in @("embeds.xml", "libs", "locales", "src", "LICENSE")) {
    Copy-Item -Path (Join-Path $repo $item) -Destination $target -Recurse -Force
}

$version = (git -C $repo describe --tags --always --dirty 2>$null)
if (-not $version) { $version = "dev" }

$toc = Get-Content -Path (Join-Path $repo "GirthBind.toc") -Raw
$toc = $toc -replace "(?m)^## Title: .*$", "## Title: GirthBind |cffff8000(Test)|r"
$toc = $toc -replace "(?m)^## SavedVariables: .*$", "## SavedVariables: $svName"
$toc = $toc -replace "(?m)^## X-Curse-Project-ID: .*\r?\n", ""
$toc = $toc -replace "@project-version@", "$version-test"
$tocPath = Join-Path $target "$Name.toc"
[System.IO.File]::WriteAllText($tocPath, $toc, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Deployed $Name ($version) to $target"
Write-Host "SavedVariables: $svName. /reload in game to load the changes."
