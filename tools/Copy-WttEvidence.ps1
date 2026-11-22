# Copy-WttEvidence.ps1
# Copies only the files the WTT collector needs from every WoW install, keeping per-character files
# (the shared copy script skips those for Classic Era): TestThat, KeepThat, DontDoThat and
# ClosestVendor saved variables, plus Screenshots. Read-only on the game folders.
# Then run:  .venv/bin/python tools/wtt.py collect --src <Destination>
param(
    [string[]]$Roots = @(
        'D:\Program Files\World of Warcraft\_forever_',
        'D:\Program Files\World of Warcraft\_classic_era_'
    ),
    [string]$Destination = (Join-Path $PSScriptRoot '..\evidence-src')
)
$ErrorActionPreference = 'Stop'
$Destination = [System.IO.Path]::GetFullPath($Destination)
Write-Host "Copying to $Destination"
try {
$names = 'TestThat', 'KeepThat', 'DontDoThat', 'ClosestVendor'
foreach ($root in $Roots) {
    $flavor = Split-Path $root -Leaf
    $wtf = Join-Path $root 'WTF'
    if (-not (Test-Path -LiteralPath $wtf)) { Write-Host "Skipping ${flavor}: no WTF folder."; continue }
    foreach ($n in $names) {
        Get-ChildItem -LiteralPath $wtf -Recurse -File -Filter "$n.lua" -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq 'SavedVariables' } | ForEach-Object {
                $rel = $_.FullName.Substring($wtf.Length + 1)
                $target = Join-Path (Join-Path $Destination $flavor) (Join-Path 'WTF' $rel)
                [void][System.IO.Directory]::CreateDirectory((Split-Path $target))
                Copy-Item -LiteralPath $_.FullName -Destination $target -Force
                Write-Host "Copied $flavor\$rel"
            }
    }
    $shots = Join-Path $root 'Screenshots'
    if (Test-Path -LiteralPath $shots) {
        $t = Join-Path (Join-Path $Destination $flavor) 'Screenshots'
        [void][System.IO.Directory]::CreateDirectory($t)
        Copy-Item -Path (Join-Path $shots '*') -Destination $t -Force
    }
}
Write-Host "Done. Next: collect --src '$Destination' (add --shots <flavor>\Screenshots for screenshots)."
} catch {
    Write-Host ""
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
    exit 1
}
