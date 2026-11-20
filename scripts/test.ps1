<#
.SYNOPSIS
    Runs luacheck and busted in the Lua 5.1 test container (the same image CI uses).

.EXAMPLE
    ./scripts/test.ps1              # lint + tests
    ./scripts/test.ps1 -Only busted # tests only
    ./scripts/test.ps1 -Rebuild     # rebuild the image first
#>
[CmdletBinding()]
param(
    [ValidateSet("all", "luacheck", "busted")]
    [string]$Only = "all",
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$image = "girthbind-test"

if ($Rebuild -or -not (docker images -q $image)) {
    docker build -f (Join-Path $repo "tools/test.Dockerfile") -t $image (Join-Path $repo "tools")
    if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
}

$mount = "${repo}:/src"
$failed = $false
if ($Only -in "all", "luacheck") {
    docker run --rm -v $mount $image luacheck .
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}
if ($Only -in "all", "busted") {
    docker run --rm -v $mount $image busted
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}
if ($failed) { exit 1 }
