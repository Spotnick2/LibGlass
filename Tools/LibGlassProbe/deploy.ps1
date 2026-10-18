<#
    deploy.ps1 - Deploy LibGlassProbe, a ForeverProbe module, for an in-game check.

    In order, each step stopping the rest if it refuses:
      1. ForeverProbe, the host (..\ForeverProbe, or $env:FOREVERPROBE), with its own deploy;
      2. this LibGlass checkout into AddOns\LibGlassProbe\Libs\LibGlass-1.0 (Tools\deploy.ps1);
      3. the module's TOC and Lua (not the README).

    Usage, from the repo root:
        pwsh Tools\LibGlassProbe\deploy.ps1
        pwsh Tools\LibGlassProbe\deploy.ps1 -AddOnsPath "D:\...\_classic_beta_\Interface\AddOns"
    Then /reload in game (a brand-new addon folder included) and /fp steps lg repaint, /fp steps lg pearl.
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe"
)

$ErrorActionPreference = "Stop"
$ProbeDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ProbeDir)
$ForeverProbe = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else { Join-Path (Split-Path -Parent $RepoRoot) "ForeverProbe" }
$Files = @("LibGlassProbe.toc", "LibGlassProbe.lua", "Pearl.lua")

foreach ($f in $Files) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProbeDir $f))) { Write-Error "Missing probe file: $f"; exit 1 }
}
$luac = Join-Path (Split-Path -Parent $Lua) "luac.exe"
if (Test-Path -LiteralPath $luac) {
    & $luac -p (Join-Path $ProbeDir "LibGlassProbe.lua") (Join-Path $ProbeDir "Pearl.lua")
    if ($LASTEXITCODE -ne 0) { Write-Error "luac -p failed on the probe's Lua"; exit 1 }
    Remove-Item -LiteralPath "luac.out" -ErrorAction SilentlyContinue
} else {
    Write-Host "  luac -p SKIPPED (no $luac)" -ForegroundColor Yellow
}

# 1. The host.
$hostDeploy = Join-Path $ForeverProbe "Tools\deploy.ps1"
if (-not (Test-Path -LiteralPath $hostDeploy)) {
    Write-Error "ForeverProbe checkout not found at $ForeverProbe (or set `$env:FOREVERPROBE)"; exit 1
}
& pwsh -NoProfile -File $hostDeploy -AddOnsPath $AddOnsPath
if ($LASTEXITCODE -ne 0) { Write-Error "ForeverProbe deploy refused; LibGlassProbe was not touched"; exit 1 }

# 2. The library, from this checkout (a child process: its exit codes stay its own).
& pwsh -NoProfile -File (Join-Path $RepoRoot "Tools\deploy.ps1") -Addon LibGlassProbe -AddOnsPath $AddOnsPath -Lua $Lua
if ($LASTEXITCODE -ne 0) { Write-Error "LibGlass deploy refused; LibGlassProbe was not copied"; exit 1 }

# 3. The module.
$dest = Join-Path (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath "LibGlassProbe"
foreach ($f in $Files) { Copy-Item -LiteralPath (Join-Path $ProbeDir $f) -Destination (Join-Path $dest $f) -Force }
Write-Host "LibGlassProbe deployed to $dest. /reload, then /fp steps to list the procedures (or /fp lg for the commands)." -ForegroundColor Cyan

# The probe this replaced: its /lgprobe and its embedded LibGlass would still load.
$old = Join-Path (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath "GlassComparison"
if (Test-Path -LiteralPath $old) {
    Write-Host "  $old is the old /lgprobe, replaced by this module: delete that folder or disable it." -ForegroundColor Yellow
}
