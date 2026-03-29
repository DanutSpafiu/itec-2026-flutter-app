param(
  [string]$Device,
  [switch]$NoRun
)

$ErrorActionPreference = 'Stop'

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$destRoot = 'C:\temp'
$dest = Join-Path $destRoot 'poster_ar'

Write-Host "[1/4] Syncing source to temp workspace..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

# Mirror source into temp while excluding generated and VCS folders.
robocopy $source $dest /MIR /XD build .dart_tool .git .gradle > $null
$rc = $LASTEXITCODE
if ($rc -ge 8) {
  throw "robocopy failed with exit code $rc"
}

Write-Host "[2/4] Entering temp workspace: $dest" -ForegroundColor Cyan
Set-Location $dest

Write-Host "[3/4] Running flutter clean + pub get..." -ForegroundColor Cyan
flutter clean
flutter pub get

if ($NoRun) {
  Write-Host "[4/4] NoRun was set. Stopping before flutter run." -ForegroundColor Yellow
  exit 0
}

Write-Host "[4/4] Starting flutter run..." -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($Device)) {
  flutter run
} else {
  flutter run -d $Device
}
