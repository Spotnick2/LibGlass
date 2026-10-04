<#
    deploy.ps1 - Copy this LibGlass checkout into a consumer addon's
    Libs\LibGlass-1.0 in the Forever AddOns folder (what the packager's
    externals would put there, for in-game testing of a dev copy).

    Copies only what runs in game: LibGlass-1.0.xml, every file it loads,
    LICENSE and the textures. Refuses to copy a checkout missing any of them
    (a missing texture draws nothing, with no error), and prints the commit so
    an in-game check can be tied to it.

    Consumers call it from their own deploy:
        pwsh ..\LibGlass\Tools\deploy.ps1 -Addon GlassUnitFrames
        pwsh ..\LibGlass\Tools\deploy.ps1 -Addon GlassChat -AddOnsPath "D:\...\_classic_beta_\Interface\AddOns"
#>

param(
    [Parameter(Mandatory)][string]$Addon,
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$LibRoot = Split-Path -Parent $PSScriptRoot

# The textures LibGlass.lua names (tests/test_media.lua keeps this list honest).
$Textures = @("bar_edge", "bar_fill", "bar_mask", "body_mask", "body_mask_small", "gloss", "grain",
              "rim5", "rim5_small", "rim_dark5", "rim_dark5_small", "shadow", "shadow_small",
              "sheen2", "track_fade")

# --- Preflight: everything the XML loads, LICENSE, every texture.
$xmlPath = Join-Path $LibRoot "LibGlass-1.0.xml"
if (-not (Test-Path -LiteralPath $xmlPath)) { Write-Error "LibGlass-1.0.xml not found in $LibRoot"; exit 1 }
$xml = (Get-Content -LiteralPath $xmlPath -Raw) -replace '(?s)<!--.*?-->', ''
$scripts = @([regex]::Matches($xml, '<Script\s+file="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($scripts.Count -eq 0) { Write-Error "LibGlass-1.0.xml lists no Script files"; exit 1 }
$files = @("LibGlass-1.0.xml", "LICENSE") + $scripts + ($Textures | ForEach-Object { "Media\$_.tga" })
$missing = @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $LibRoot $_)) })
if ($missing.Count -gt 0) { Write-Error ("LibGlass checkout is incomplete, missing: " + ($missing -join ", ")); exit 1 }
$extra = @(Get-ChildItem -LiteralPath (Join-Path $LibRoot "Media") -Filter "*.tga" |
    Where-Object { $Textures -notcontains $_.BaseName } | ForEach-Object { $_.Name })
if ($extra.Count -gt 0) { Write-Error ("Media\ holds textures the code doesn't name: " + ($extra -join ", ")); exit 1 }

$luac = "C:\Program Files (x86)\Lua\5.1\luac.exe"
if (Test-Path -LiteralPath $luac) {
    Push-Location $LibRoot
    try {
        & $luac -p @scripts
        if ($LASTEXITCODE -ne 0) { Write-Error "luac -p failed on the LibGlass checkout"; exit 1 }
        Remove-Item -LiteralPath "luac.out" -ErrorAction SilentlyContinue
    } finally { Pop-Location }
} else {
    Write-Host "  luac -p SKIPPED (no $luac)" -ForegroundColor Yellow
}

$commit = "unknown"
try {
    $commit = (git -C $LibRoot rev-parse --short HEAD).Trim()
    if (git -C $LibRoot status --porcelain) { $commit += " (with uncommitted changes)" }
} catch { }

# --- Copy.
if (-not (Test-Path -LiteralPath $AddOnsPath)) { Write-Error "AddOns path not found: $AddOnsPath"; exit 1 }
$dest = Join-Path $AddOnsPath "$Addon\Libs\LibGlass-1.0"
Write-Host "Deploying LibGlass $commit -> $dest" -ForegroundColor Cyan
foreach ($f in $files) {
    $target = Join-Path $dest $f
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $LibRoot $f) -Destination $target -Force
}
# A file the library no longer ships must not linger where the client finds it.
$keep = $files | ForEach-Object { (Join-Path $dest $_).ToLowerInvariant() }
Get-ChildItem -LiteralPath $dest -File -Recurse | Where-Object { $keep -notcontains $_.FullName.ToLowerInvariant() } |
    ForEach-Object {
        Write-Host "  removing stale $($_.FullName.Substring($dest.Length + 1))" -ForegroundColor DarkYellow
        Remove-Item -LiteralPath $_.FullName -Force
    }
Write-Host "  $($scripts.Count + 2) files + $($Textures.Count) textures"
