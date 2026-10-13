<# Deploy only the standalone probe and an embedded copy of this checkout. #>
param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns"
)
$ErrorActionPreference = "Stop"
$probeFiles = @("GlassComparison.toc", "GlassComparison.lua")
foreach ($file in $probeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) {
        throw "Missing probe file: $file."
    }
}
$luac = "C:\Program Files (x86)\Lua\5.1\luac.exe"
if (-not (Test-Path -LiteralPath $luac)) { throw "Lua 5.1 compiler missing: $luac" }
& $luac -p (Join-Path $PSScriptRoot "GlassComparison.lua")
if ($LASTEXITCODE -ne 0) { throw "Probe syntax check failed." }
# A child process contains deploy.ps1's exit statements and exposes its exit code.
& pwsh -NoProfile -File (Join-Path $PSScriptRoot "..\deploy.ps1") -Addon GlassComparison -AddOnsPath $AddOnsPath
if ($LASTEXITCODE -ne 0) { throw "Embedded library deployment failed." }
$destination = Join-Path (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath "GlassComparison"
foreach ($file in $probeFiles) {
    $target = Join-Path $destination $file
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $target -Force
}
Write-Host "Probe deployed to $destination. New addon folder: restart the client, enable LibGlass Comparison, then /lgprobe."
